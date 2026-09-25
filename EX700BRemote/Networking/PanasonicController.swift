import Foundation

/// What the TV is doing right now.
enum PowerState: Sendable, Equatable {
    /// Fully on (it answered a volume query).
    case on(volume: Int?, muted: Bool?)
    /// It answered, but its media renderer is off – i.e. network standby.
    case standby
    /// Nothing answered.
    case unreachable(PanasonicError)
}

/// Result of a "turn on"/"turn off" request.
enum PowerChange: Sendable, Equatable {
    case turnedOn
    case turnedOff
    case alreadyOn
    case alreadyOff
    /// Couldn't reach the TV while trying to turn it off (probably off already).
    case noResponse
}

/// Everything the app (and Siri) can ask the TV to do.
actor PanasonicController {

    static let shared = PanasonicController()

    /// YouTube's product ID differs by model year. Used only if the TV's
    /// own app list can't be read. 2017 (EX series) first.
    static let youTubeFallbackIDs = [
        "0070000200170001",
        "0070000200180001",
        "0070000200190001",
        "0070000200000001"
    ]

    private let client: SOAPClient
    private let store: TVStore

    init(store: TVStore = .shared, client: SOAPClient = SOAPClient()) {
        self.store = store
        self.client = client
    }

    /// Always read fresh, so a new IP saved in Setup is used straight away.
    var tv: PanasonicTV { store.tv }

    // MARK: - Remote keys

    func send(_ command: TVCommand) async throws {
        try await sendKey(command.panasonicKey)
    }

    /// Sends any NRC key code, e.g. "NRC_HDMI1-ONOFF".
    func sendKey(_ key: String) async throws {
        let code = key.trimmingCharacters(in: .whitespacesAndNewlines)
        _ = try await client.call(
            .networkControl,
            action: "X_SendKey",
            arguments: "<X_KeyEvent>\(XMLText.escape(code))</X_KeyEvent>",
            on: tv
        )
    }

    /// Presses a key several times with a short gap.
    func press(_ command: TVCommand, times: Int) async throws {
        let count = max(1, min(times, 50))
        for index in 0..<count {
            try await send(command)
            if index + 1 < count {
                try await Task.sleep(for: .milliseconds(150))
            }
        }
    }

    /// Types text into a text box on the TV (e.g. YouTube search).
    func sendText(_ text: String) async throws {
        _ = try await client.call(
            .networkControl,
            action: "X_SendString",
            arguments: "<X_String>\(XMLText.escape(text))</X_String>",
            on: tv
        )
    }

    // MARK: - Apps

    /// Reads the list of installed apps from the TV (and remembers it).
    func fetchApps() async throws -> [TVApp] {
        let reply = try await client.call(.networkControl, action: "X_GetAppList", on: tv)
        let apps = PanasonicResponses.apps(from: reply)
        if !apps.isEmpty {
            store.apps = apps
        }
        return apps
    }

    func launch(_ app: TVApp) async throws {
        try await launch(keyword: app.launchKeyword)
    }

    /// Launches an app by its keyword, e.g. "product_id=0070000200170001".
    func launch(keyword: String) async throws {
        let arguments = "<X_AppType>vc_app</X_AppType>"
            + "<X_LaunchKeyword>\(XMLText.escape(keyword))</X_LaunchKeyword>"
        _ = try await client.call(
            .networkControl,
            action: "X_LaunchApp",
            arguments: arguments,
            on: tv
        )
    }

    /// Finds an app by name in the saved list, asking the TV if needed.
    func findApp(named name: String) async throws -> TVApp? {
        if let app = Self.match(name, in: store.apps) {
            return app
        }
        return Self.match(name, in: try await fetchApps())
    }

    /// Opens an app by (roughly) its name, e.g. "netflix" or "iplayer".
    @discardableResult
    func launchApp(named name: String) async throws -> TVApp {
        guard let app = try await findApp(named: name) else {
            throw PanasonicError.appNotFound(name)
        }
        try await launch(app)
        return app
    }

    /// Opens YouTube, using the TV's own app list to get the right ID.
    func launchYouTube() async throws {
        var lastError: Error?

        do {
            if let app = try await findApp(named: "YouTube") {
                try await launch(app)
                return
            }
        } catch let error as PanasonicError where error.isConnectionProblem {
            throw error
        } catch {
            // App list not available on this model: try the known IDs.
            lastError = error
        }

        for productID in Self.youTubeFallbackIDs {
            do {
                try await launch(keyword: "product_id=\(productID)")
                return
            } catch let error as PanasonicError where error.isConnectionProblem {
                throw error
            } catch {
                lastError = error
            }
        }
        throw lastError ?? PanasonicError.appNotFound("YouTube")
    }

    /// Loose name matching: "iplayer" finds "BBC iPlayer".
    static func match(_ name: String, in apps: [TVApp]) -> TVApp? {
        let wanted = normalised(name)
        guard !wanted.isEmpty else { return nil }
        return apps.first { normalised($0.name) == wanted }
            ?? apps.first { normalised($0.name).hasPrefix(wanted) }
            ?? apps.first { normalised($0.name).contains(wanted) }
    }

    private static func normalised(_ text: String) -> String {
        String(text.lowercased().filter { $0.isLetter || $0.isNumber })
    }

    // MARK: - Volume and mute

    private static let masterChannel = "<InstanceID>0</InstanceID><Channel>Master</Channel>"

    func volume(timeout: TimeInterval? = nil) async throws -> Int {
        let reply = try await client.call(
            .renderingControl,
            action: "GetVolume",
            arguments: Self.masterChannel,
            on: tv,
            timeout: timeout
        )
        guard let level = PanasonicResponses.volume(from: reply) else {
            throw PanasonicError.invalidResponse
        }
        return level
    }

    func setVolume(_ level: Int) async throws {
        let clamped = min(100, max(0, level))
        _ = try await client.call(
            .renderingControl,
            action: "SetVolume",
            arguments: Self.masterChannel + "<DesiredVolume>\(clamped)</DesiredVolume>",
            on: tv
        )
    }

    func isMuted(timeout: TimeInterval? = nil) async throws -> Bool {
        let reply = try await client.call(
            .renderingControl,
            action: "GetMute",
            arguments: Self.masterChannel,
            on: tv,
            timeout: timeout
        )
        guard let muted = PanasonicResponses.mute(from: reply) else {
            throw PanasonicError.invalidResponse
        }
        return muted
    }

    func setMuted(_ muted: Bool) async throws {
        _ = try await client.call(
            .renderingControl,
            action: "SetMute",
            arguments: Self.masterChannel + "<DesiredMute>\(muted ? 1 : 0)</DesiredMute>",
            on: tv
        )
    }

    /// Changes the volume by a number of steps. Returns the new level
    /// when the TV reports it.
    @discardableResult
    func changeVolume(by steps: Int) async throws -> Int? {
        guard steps != 0 else { return nil }
        do {
            let current = try await volume()
            let target = min(100, max(0, current + steps))
            try await setVolume(target)
            return target
        } catch let error as PanasonicError where error.isConnectionProblem {
            throw error
        } catch {
            // Volume control not available: fall back to pressing the key.
            try await press(steps > 0 ? .volumeUp : .volumeDown, times: abs(steps))
            return nil
        }
    }

    // MARK: - Power

    /// On = the TV answers a volume query (same test Home Assistant uses).
    func powerState(timeout: TimeInterval = 2.5) async -> PowerState {
        do {
            let level = try await volume(timeout: timeout)
            let muted = try? await isMuted(timeout: timeout)
            return .on(volume: level, muted: muted)
        } catch let error as PanasonicError where error.isConnectionProblem {
            return .unreachable(error)
        } catch {
            return .standby
        }
    }

    /// Turns the TV on only if it's off (the power key is a toggle).
    func turnOn() async throws -> PowerChange {
        switch await powerState() {
        case .on:
            return .alreadyOn
        case .standby:
            try await send(.power)
            return .turnedOn
        case .unreachable:
            // One more go with the normal timeout in case it was just slow.
            // If this fails too, the error explains what to check.
            try await send(.power)
            return .turnedOn
        }
    }

    /// Makes sure the TV is on before doing something else (used by Siri,
    /// so "Aliens on the telly" works even from standby).
    /// Returns true if it had to switch the TV on.
    @discardableResult
    func ensureOn(waitUpTo timeout: TimeInterval = 12) async throws -> Bool {
        if case .on = await powerState() {
            return false
        }
        try await send(.power)

        // Wait until the TV answers volume queries again, i.e. it has booted.
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            try await Task.sleep(for: .milliseconds(1500))
            if case .on = await powerState(timeout: 2) {
                // Give the smart-TV side a moment to be ready for app launches.
                try await Task.sleep(for: .milliseconds(1500))
                return true
            }
        }
        return true
    }

    /// Opens YouTube, switching the TV on first if needed. If the TV has
    /// only just woken up, one retry covers it still getting ready.
    @discardableResult
    func wakeAndLaunchYouTube() async throws -> Bool {
        let wokeUp = try await ensureOn()
        do {
            try await launchYouTube()
        } catch let error as PanasonicError where wokeUp && !error.isConnectionProblem {
            try await Task.sleep(for: .seconds(2))
            try await launchYouTube()
        }
        return wokeUp
    }

    /// Turns the TV off only if it's on.
    func turnOff() async throws -> PowerChange {
        switch await powerState() {
        case .on:
            try await send(.power)
            return .turnedOff
        case .standby:
            return .alreadyOff
        case .unreachable:
            return .noResponse
        }
    }

    // MARK: - Information

    /// Reads the TV's name and model from /nrc/ddd.xml.
    func deviceInfo(timeout: TimeInterval? = nil) async throws -> TVDeviceInfo {
        let xml = try await client.get(path: "/nrc/ddd.xml", on: tv, timeout: timeout)
        guard let info = PanasonicResponses.deviceInfo(from: xml) else {
            throw PanasonicError.invalidResponse
        }
        return info
    }

    /// Lists the SOAP actions the TV supports (from /nrc/sdd_0.xml).
    func supportedActions() async throws -> [String] {
        let xml = try await client.get(path: "/nrc/sdd_0.xml", on: tv)
        return PanasonicResponses.actionNames(from: xml)
    }

    // MARK: - Lab

    /// Sends any SOAP action. `arguments` is the XML that goes inside it.
    func rawSOAP(service: TVService, action: String, arguments: String) async throws -> String {
        try await client.call(
            service,
            action: action.trimmingCharacters(in: .whitespacesAndNewlines),
            arguments: arguments.trimmingCharacters(in: .whitespacesAndNewlines),
            on: tv
        )
    }
}
