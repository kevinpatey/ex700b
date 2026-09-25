import Foundation

/// The TV the app talks to. Saved in UserDefaults by `TVStore`.
struct PanasonicTV: Codable, Sendable, Equatable {

    /// The TV's own name, e.g. "50EX700_Series".
    var name: String

    /// Model number, e.g. "TX-50EX700B".
    var model: String

    /// IP address (or local host name) of the TV on the home network.
    var host: String

    /// Panasonic's remote-control port. Always 55000 on VIERA TVs.
    var port: Int

    /// UPnP unique device name ("uuid:…"). Used to recognise the same
    /// TV again if the router gives it a new IP address.
    var udn: String?

    static let defaultPort = 55000

    /// Kevin's TX-50EX700B, used until something else is saved.
    static let knownEX700B = PanasonicTV(
        name: "50EX700_Series",
        model: "TX-50EX700B",
        host: "192.168.1.158",
        port: defaultPort,
        udn: "uuid:4D454930-0200-1000-8001-D8AFF1CA7496"
    )

    /// "192.168.1.158" or "192.168.1.158:1234" for a non-standard port.
    var address: String {
        port == Self.defaultPort ? host : "\(host):\(port)"
    }

    /// Builds `http://host:port/path`. Returns nil for an unusable host.
    func url(path: String) -> URL? {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHost.isEmpty, (1...65535).contains(port) else {
            return nil
        }
        var components = URLComponents()
        components.scheme = "http"
        components.host = trimmedHost
        components.port = port
        components.path = path.hasPrefix("/") ? path : "/" + path
        return components.url
    }
}

/// An app installed on the TV (from the TV's own app list).
struct TVApp: Codable, Sendable, Hashable, Identifiable {

    /// Name as the TV reports it, e.g. "YouTube".
    let name: String

    /// What X_LaunchApp needs, e.g. "product_id=0070000200170001".
    let launchKeyword: String

    var id: String { launchKeyword }

    static func product(_ name: String, id productID: String) -> TVApp {
        TVApp(name: name, launchKeyword: "product_id=\(productID)")
    }
}
