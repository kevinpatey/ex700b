import Foundation
import Observation

/// Shared state for all the screens.
@MainActor
@Observable
final class AppModel {

    enum Status: Equatable {
        case unknown
        case checking
        case on(volume: Int?, muted: Bool?)
        case standby
        case unreachable(String)
    }

    struct Banner: Equatable, Identifiable {
        let id = UUID()
        let text: String
        let isError: Bool
    }

    struct ReportLine: Identifiable, Equatable {
        let id = UUID()
        let ok: Bool
        let text: String
    }

    // MARK: - State shown on screen

    private(set) var tv: PanasonicTV
    private(set) var status: Status = .unknown
    private(set) var banner: Banner?

    private(set) var apps: [TVApp]
    private(set) var isLoadingApps = false
    private(set) var appsError: String?

    private(set) var isScanning = false
    private(set) var scanProgress: Double = 0
    private(set) var scanResults: [DiscoveredTV] = []
    private(set) var scanMessage: String?

    private(set) var isTesting = false
    private(set) var report: [ReportLine] = []

    // MARK: - Plumbing

    private let controller: PanasonicController
    private let store: TVStore
    private let discovery: TVDiscovery
    private var triedAutoRecovery = false
    private var bannerTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?

    init(
        controller: PanasonicController = .shared,
        store: TVStore = .shared,
        discovery: TVDiscovery = .shared
    ) {
        self.controller = controller
        self.store = store
        self.discovery = discovery
        self.tv = store.tv
        self.apps = store.apps
    }

    var volume: Int? {
        if case .on(let volume, _) = status { return volume }
        return nil
    }

    var isMuted: Bool {
        if case .on(_, let muted) = status { return muted ?? false }
        return false
    }

    // MARK: - Remote buttons

    func press(_ command: TVCommand) {
        perform(failurePrefix: command.title) { [controller] in
            try await controller.send(command)
        }
        switch command {
        case .volumeUp, .volumeDown, .mute:
            scheduleRefresh(after: .milliseconds(700))
        case .power:
            // The TV takes a few seconds to wake (or sleep), so look twice.
            status = .checking
            scheduleRefresh(after: .seconds(5), andAgainAfter: .seconds(6))
        default:
            break
        }
    }

    func openYouTube() {
        perform(success: "Opening YouTube…", failurePrefix: "YouTube") { [controller] in
            try await controller.launchYouTube()
        }
    }

    func launch(_ app: TVApp) {
        perform(success: "Opening \(app.name)…", failurePrefix: app.name) { [controller] in
            try await controller.launch(app)
        }
    }

    func sendText(_ text: String) {
        guard !text.isEmpty else { return }
        perform(success: "Text sent to the TV.", failurePrefix: "Text") { [controller] in
            try await controller.sendText(text)
        }
    }

    func setVolume(_ level: Int) {
        let clamped = min(100, max(0, level))
        if case .on(_, let muted) = status {
            status = .on(volume: clamped, muted: muted)
        }
        perform(failurePrefix: "Volume") { [controller] in
            try await controller.setVolume(clamped)
        }
    }

    // MARK: - Status

    /// Asks the TV whether it's on, and its volume.
    func refreshStatus() async {
        if case .unknown = status {
            status = .checking
        }
        switch await controller.powerState() {
        case .on(let volume, let muted):
            status = .on(volume: volume, muted: muted)
        case .standby:
            status = .standby
        case .unreachable(let error):
            status = .unreachable(error.errorDescription ?? "Can't reach the TV.")
            if case .unreachable = error {
                await recoverMovedTVIfNeeded()
            }
        }
    }

    private func scheduleRefresh(after delay: Duration, andAgainAfter secondDelay: Duration? = nil) {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await self?.refreshStatus()

            guard let secondDelay else { return }
            try? await Task.sleep(for: secondDelay)
            guard !Task.isCancelled else { return }
            await self?.refreshStatus()
        }
    }

    /// If the router gave the TV a new IP address, find it again by its
    /// unique ID. Runs at most once per app launch.
    private func recoverMovedTVIfNeeded() async {
        guard !triedAutoRecovery, !isScanning, let udn = tv.udn else { return }
        triedAutoRecovery = true

        let result = await discovery.scan(preferredHost: tv.host)
        if result.localNetworkBlocked || result.noWiFi {
            // Nothing could be checked; allow another go later.
            triedAutoRecovery = false
            return
        }
        guard let match = result.found.first(where: { $0.info.udn == udn }),
              match.host != tv.host || match.port != tv.port
        else {
            return
        }

        var moved = tv
        moved.host = match.host
        moved.port = match.port
        save(moved)
        showBanner("Found your TV at its new address, \(match.host).", isError: false)
        await refreshStatus()
    }

    // MARK: - Apps

    func loadAppsIfNeeded() async {
        if apps.isEmpty {
            await loadApps()
        }
    }

    func loadApps() async {
        guard !isLoadingApps else { return }
        isLoadingApps = true
        appsError = nil
        defer { isLoadingApps = false }

        do {
            let fresh = try await controller.fetchApps()
            if fresh.isEmpty {
                appsError = "The TV didn't list any apps. Is it switched on?"
            } else {
                apps = fresh
            }
        } catch {
            appsError = Self.message(for: error)
        }
    }

    // MARK: - Setup

    /// Saves a typed-in IP address. Returns false if it doesn't look valid.
    @discardableResult
    func updateAddress(_ text: String) -> Bool {
        let host = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let looksLikeIP = LocalNetwork.parse(host) != nil
        let looksLikeName = !host.isEmpty
            && !host.contains(" ")
            && host.contains(".")
            && host.rangeOfCharacter(from: .letters) != nil
        guard looksLikeIP || looksLikeName else { return false }
        guard host != tv.host else { return true }

        var updated = tv
        updated.host = host
        updated.port = PanasonicTV.defaultPort
        save(updated)
        report = []
        status = .checking
        Task { await refreshStatus() }
        return true
    }

    func use(_ found: DiscoveredTV) {
        save(found.tv)
        report = []
        showBanner("Now controlling \(found.info.friendlyName) at \(found.host).", isError: false)
        status = .checking
        Task {
            await refreshStatus()
            await loadApps()
        }
    }

    func startScan() {
        guard !isScanning else { return }
        isScanning = true
        scanProgress = 0
        scanResults = []
        scanMessage = nil

        Task {
            let result = await discovery.scan(preferredHost: tv.host) { done, total in
                Task { @MainActor [weak self] in
                    self?.scanProgress = total > 0 ? Double(done) / Double(total) : 1
                }
            }
            isScanning = false
            scanProgress = 1
            scanResults = result.found

            if result.noWiFi {
                scanMessage = "Your phone isn't on Wi-Fi. Join the same network as the TV."
            } else if result.localNetworkBlocked {
                scanMessage = PanasonicError.localNetworkDenied.errorDescription
            } else if result.found.isEmpty {
                scanMessage = "No Panasonic TV answered. Check it's switched on (or in "
                    + "network standby) and that 'TV Remote' is on in its network settings."
            } else if result.found.count == 1, let only = result.found.first,
                      only.host == tv.host {
                scanMessage = "That's the TV you're already using."
            }
        }
    }

    /// Checks the connection step by step and explains what it finds.
    func runConnectionTest() async {
        guard !isTesting else { return }
        isTesting = true
        defer { isTesting = false }

        var lines: [ReportLine] = []

        do {
            let info = try await controller.deviceInfo()
            lines.append(ReportLine(ok: true, text: "Found \(info.friendlyName) (\(info.model)) at \(tv.address)."))

            // Keep the saved name/model/ID in step with the real TV.
            if info.friendlyName != tv.name || info.model != tv.model || info.udn != tv.udn {
                var updated = tv
                updated.name = info.friendlyName
                updated.model = info.model
                updated.udn = info.udn ?? tv.udn
                save(updated)
            }
        } catch {
            lines.append(ReportLine(ok: false, text: Self.message(for: error)))
            report = lines
            return
        }

        do {
            let actions = try await controller.supportedActions()
            if actions.contains("X_GetEncryptSessionId") {
                lines.append(ReportLine(ok: false, text: PanasonicError.encryptionRequired.errorDescription ?? ""))
            } else {
                lines.append(ReportLine(ok: true, text: "Remote control is available (no pairing needed)."))
            }
        } catch {
            lines.append(ReportLine(ok: false, text: "Couldn't read the TV's command list: \(Self.message(for: error))"))
        }

        await refreshStatus()
        switch status {
        case .on(let volume, _):
            let level = volume.map { ", volume \($0)" } ?? ""
            lines.append(ReportLine(ok: true, text: "The TV is on\(level)."))
        case .standby:
            lines.append(ReportLine(ok: true, text: "The TV is in network standby – the power button will wake it."))
        case .unreachable(let message):
            lines.append(ReportLine(ok: false, text: message))
        case .unknown, .checking:
            break
        }
        report = lines
    }

    // MARK: - Lab helpers

    func labRun(_ operation: @escaping () async throws -> String) async -> String {
        do {
            return try await operation()
        } catch {
            return "⚠️ " + Self.message(for: error)
        }
    }

    var labController: PanasonicController { controller }

    // MARK: - Helpers

    private func save(_ newTV: PanasonicTV) {
        store.tv = newTV
        tv = newTV
        apps = store.apps
        triedAutoRecovery = false
    }

    private func perform(
        success: String? = nil,
        failurePrefix: String,
        _ operation: @escaping @Sendable () async throws -> Void
    ) {
        Task {
            do {
                try await operation()
                if let success {
                    showBanner(success, isError: false)
                } else if banner?.isError == true {
                    banner = nil
                }
                // It worked, so the TV is clearly reachable again.
                if case .unreachable = status {
                    scheduleRefresh(after: .milliseconds(300))
                }
            } catch {
                Haptics.error()
                showBanner("\(failurePrefix): \(Self.message(for: error))", isError: true)
                if let panasonic = error as? PanasonicError, panasonic.isConnectionProblem {
                    status = .unreachable(Self.message(for: error))
                }
            }
        }
    }

    func showBanner(_ text: String, isError: Bool) {
        let newBanner = Banner(text: text, isError: isError)
        banner = newBanner
        bannerTask?.cancel()
        bannerTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(isError ? 6 : 2.5))
            guard !Task.isCancelled, self?.banner?.id == newBanner.id else { return }
            self?.banner = nil
        }
    }

    func dismissBanner() {
        bannerTask?.cancel()
        banner = nil
    }

    static func message(for error: Error) -> String {
        if let localized = error as? LocalizedError, let description = localized.errorDescription {
            return description
        }
        return error.localizedDescription
    }
}
