import Foundation

/// Remembers the TV's details and its app list between launches.
/// Siri shortcuts read from here too, so they always use the latest IP.
final class TVStore: @unchecked Sendable {

    static let shared = TVStore()

    private let defaults: UserDefaults
    private let tvKey = "savedTV.v1"
    private let appsKey = "tvApps.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The TV to control (Kevin's EX700B until something else is saved).
    var tv: PanasonicTV {
        get {
            guard let data = defaults.data(forKey: tvKey),
                  let saved = try? JSONDecoder().decode(PanasonicTV.self, from: data)
            else {
                return .knownEX700B
            }
            return saved
        }
        set {
            let old = tv
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: tvKey)
            }
            // A different TV means the cached app list is no longer valid.
            if let oldUDN = old.udn, let newUDN = newValue.udn, oldUDN != newUDN {
                apps = []
            }
        }
    }

    /// Apps last read from the TV (used to find YouTube's ID).
    var apps: [TVApp] {
        get {
            guard let data = defaults.data(forKey: appsKey),
                  let saved = try? JSONDecoder().decode([TVApp].self, from: data)
            else {
                return []
            }
            return saved
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: appsKey)
            }
        }
    }
}
