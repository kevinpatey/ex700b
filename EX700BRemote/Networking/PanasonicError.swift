import Foundation

/// Everything that can go wrong when talking to the TV, with messages
/// written for a person (they're also what Siri says out loud).
enum PanasonicError: LocalizedError, Sendable, Equatable {

    /// No usable IP address saved yet.
    case notConfigured

    /// Nothing answered at the TV's address (off, asleep, wrong IP, or
    /// the phone isn't on the home Wi-Fi).
    case unreachable(host: String)

    /// iOS blocked the connection because Local Network access is off
    /// (or the permission pop-up hasn't been answered yet).
    case localNetworkDenied

    /// The phone isn't on Wi-Fi at all.
    case noWiFi

    /// iOS App Transport Security blocked plain HTTP (shouldn't happen
    /// with the Info.plist settings, but worth a clear message).
    case blockedByTransportSecurity

    /// The TV answered "403 Forbidden" – usually "TV Remote" is switched
    /// off in the TV's network settings.
    case forbidden

    /// The TV rejected the command (UPnP error).
    case soapFault(code: String, description: String)

    /// Unexpected HTTP status.
    case httpError(Int)

    /// The TV answered with something we couldn't understand.
    case invalidResponse

    /// Newer Panasonic TVs need PIN pairing + encryption.
    case encryptionRequired

    /// An app name that isn't in the TV's app list.
    case appNotFound(String)

    /// Anything else, with the system's message.
    case other(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "No TV set up yet. Open the Setup tab and search for your TV."

        case .unreachable(let host):
            return "Can't reach the TV at \(host). Make sure it's plugged in, "
                + "your phone is on the home Wi-Fi, and 'Powered On by Apps' "
                + "is switched on in the TV's network settings."

        case .localNetworkDenied:
            return "iPhone needs your permission to talk to the TV. Tap Allow on the pop-up, "
                + "or go to Settings › Privacy & Security › Local Network and switch on EX700B Remote."

        case .noWiFi:
            return "Your phone isn't connected to Wi-Fi. Join the same Wi-Fi network as the TV."

        case .blockedByTransportSecurity:
            return "iOS blocked the plain-HTTP connection to the TV "
                + "(App Transport Security)."

        case .forbidden:
            return "The TV refused the command. On the TV, go to Menu › Network › "
                + "TV Remote App Settings and switch 'TV Remote' on."

        case .soapFault(let code, let description):
            return "The TV rejected that (UPnP error \(code): \(description))."

        case .httpError(let status):
            return "The TV answered with HTTP error \(status)."

        case .invalidResponse:
            return "The TV sent back something unexpected."

        case .encryptionRequired:
            return "This TV wants encrypted PIN pairing, which this app doesn't support."

        case .appNotFound(let name):
            return "Couldn't find an app called \"\(name)\" on the TV."

        case .other(let message):
            return message
        }
    }

    /// True for "couldn't get through at all" (as opposed to the TV
    /// answering with an error).
    var isConnectionProblem: Bool {
        switch self {
        case .unreachable, .localNetworkDenied, .noWiFi, .blockedByTransportSecurity, .notConfigured:
            return true
        default:
            return false
        }
    }

    /// Converts URLSession errors into something readable.
    static func from(
        _ error: Error,
        host: String,
        hasWiFi: @autoclosure () -> Bool = !LocalNetwork.ipv4Interfaces().isEmpty
    ) -> PanasonicError {
        if let panasonic = error as? PanasonicError {
            return panasonic
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                // What iOS reports when Local Network access is denied –
                // or when there's simply no Wi-Fi.
                return hasWiFi() ? .localNetworkDenied : .noWiFi
            case .appTransportSecurityRequiresSecureConnection:
                return .blockedByTransportSecurity
            case .cancelled:
                return .other("Cancelled.")
            default:
                // Timed out, connection refused, host not found, etc.
                return .unreachable(host: host)
            }
        }
        return .other(error.localizedDescription)
    }
}
