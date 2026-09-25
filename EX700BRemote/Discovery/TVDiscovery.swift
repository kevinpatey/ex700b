import Foundation

/// A Panasonic TV found on the network.
struct DiscoveredTV: Sendable, Hashable, Identifiable {
    let host: String
    let port: Int
    let info: TVDeviceInfo

    var id: String { "\(host):\(port)" }

    /// Ready to save as the TV to control.
    var tv: PanasonicTV {
        PanasonicTV(
            name: info.friendlyName,
            model: info.model,
            host: host,
            port: port,
            udn: info.udn
        )
    }
}

/// Finds Panasonic TVs on the home Wi-Fi.
///
/// Rather than SSDP multicast (which needs a special entitlement from
/// Apple on iOS 14+), this asks every address on the subnet for the TV's
/// description file on port 55000. It only takes a few seconds.
final class TVDiscovery: Sendable {

    static let shared = TVDiscovery()

    enum ProbeResult: Sendable {
        case found(DiscoveredTV)
        case nothing
        /// iOS refused (Local Network permission off).
        case blocked
    }

    struct ScanResult: Sendable {
        var found: [DiscoveredTV] = []
        var scannedHosts = 0
        var localNetworkBlocked = false
        var noWiFi = false
    }

    private let session: URLSession
    private let timeout: TimeInterval

    init(timeout: TimeInterval = 1.5) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout + 1
        configuration.httpMaximumConnectionsPerHost = 1
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        self.session = URLSession(configuration: configuration)
        self.timeout = timeout
    }

    /// Checks one address for a Panasonic TV.
    func probe(host: String, port: Int = PanasonicTV.defaultPort) async -> ProbeResult {
        let candidate = PanasonicTV(name: "", model: "", host: host, port: port, udn: nil)
        guard let url = candidate.url(path: "/nrc/ddd.xml") else {
            return .nothing
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let info = PanasonicResponses.deviceInfo(from: String(decoding: data, as: UTF8.self))
            else {
                return .nothing
            }
            return .found(DiscoveredTV(host: host, port: port, info: info))
        } catch let error as URLError where error.code == .notConnectedToInternet {
            return .blocked
        } catch {
            return .nothing
        }
    }

    /// Scans the phone's Wi-Fi subnet. `preferredHost` (the last known
    /// address) is checked first.
    func scan(
        preferredHost: String? = nil,
        port: Int = PanasonicTV.defaultPort,
        maxConcurrent: Int = 48,
        onProgress: @escaping @Sendable (_ done: Int, _ total: Int) -> Void = { _, _ in }
    ) async -> ScanResult {
        guard let interface = LocalNetwork.ipv4Interfaces().first else {
            return ScanResult(noWiFi: true)
        }

        var hosts = LocalNetwork.hostsToScan(for: interface)
        if let preferredHost, let index = hosts.firstIndex(of: preferredHost) {
            hosts.remove(at: index)
            hosts.insert(preferredHost, at: 0)
        }
        return await scan(hosts: hosts, port: port, maxConcurrent: maxConcurrent, onProgress: onProgress)
    }

    /// Scans a given list of addresses (used by `scan` and by tests).
    func scan(
        hosts: [String],
        port: Int = PanasonicTV.defaultPort,
        maxConcurrent: Int = 48,
        onProgress: @escaping @Sendable (_ done: Int, _ total: Int) -> Void = { _, _ in }
    ) async -> ScanResult {
        var result = ScanResult()
        guard !hosts.isEmpty else { return result }

        let width = max(1, min(maxConcurrent, hosts.count))
        var blockedCount = 0

        await withTaskGroup(of: ProbeResult.self) { group in
            var next = 0
            while next < width {
                let host = hosts[next]
                group.addTask { await self.probe(host: host, port: port) }
                next += 1
            }

            while let probe = await group.next() {
                result.scannedHosts += 1
                onProgress(result.scannedHosts, hosts.count)

                switch probe {
                case .found(let tv):
                    result.found.append(tv)
                case .blocked:
                    blockedCount += 1
                case .nothing:
                    break
                }

                if Task.isCancelled {
                    group.cancelAll()
                    break
                }
                if next < hosts.count {
                    let host = hosts[next]
                    group.addTask { await self.probe(host: host, port: port) }
                    next += 1
                }
            }
        }

        // If most addresses were refused outright, iOS is blocking us.
        result.localNetworkBlocked = result.found.isEmpty
            && blockedCount > 0
            && blockedCount * 2 >= result.scannedHosts
        result.found.sort {
            (LocalNetwork.parse($0.host) ?? .max) < (LocalNetwork.parse($1.host) ?? .max)
        }
        return result
    }
}
