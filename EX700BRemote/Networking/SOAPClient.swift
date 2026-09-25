import Foundation

/// The two Panasonic services the app uses.
enum TVService: String, CaseIterable, Sendable, Identifiable {

    /// Remote-control keys, apps, text input.
    case networkControl

    /// Volume and mute (standard UPnP RenderingControl).
    case renderingControl

    var id: String { rawValue }

    var urn: String {
        switch self {
        case .networkControl:
            return "urn:panasonic-com:service:p00NetworkControl:1"
        case .renderingControl:
            return "urn:schemas-upnp-org:service:RenderingControl:1"
        }
    }

    var controlPath: String {
        switch self {
        case .networkControl: return "/nrc/control_0"
        case .renderingControl: return "/dmr/control_0"
        }
    }

    var title: String {
        switch self {
        case .networkControl: return "NetworkControl"
        case .renderingControl: return "RenderingControl"
        }
    }
}

/// Sends SOAP (UPnP) requests to the TV.
///
/// Panasonic's built-in web server is fussy, so requests are kept exactly
/// like the ones known-working tools send: one compact line of XML with no
/// whitespace around values, and the standard UPnP headers.
final class SOAPClient: Sendable {

    private let session: URLSession
    private let defaultTimeout: TimeInterval

    init(timeout: TimeInterval = 4) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout + 4
        // One request at a time, in order – the TV prefers it that way.
        configuration.httpMaximumConnectionsPerHost = 1
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        self.session = URLSession(configuration: configuration)
        self.defaultTimeout = timeout
    }

    /// The full SOAP envelope, on one line.
    static func envelope(urn: String, action: String, arguments: String) -> String {
        "<?xml version=\"1.0\" encoding=\"utf-8\"?>"
            + "<s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\""
            + " s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\">"
            + "<s:Body>"
            + "<u:\(action) xmlns:u=\"\(urn)\">\(arguments)</u:\(action)>"
            + "</s:Body>"
            + "</s:Envelope>"
    }

    /// Builds the HTTP request for a SOAP action (exposed for tests).
    static func request(
        for service: TVService,
        action: String,
        arguments: String,
        on tv: PanasonicTV,
        timeout: TimeInterval
    ) throws -> URLRequest {
        guard let url = tv.url(path: service.controlPath) else {
            throw PanasonicError.notConfigured
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("text/xml; charset=\"utf-8\"", forHTTPHeaderField: "Content-Type")
        request.setValue("\"\(service.urn)#\(action)\"", forHTTPHeaderField: "SOAPACTION")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        request.httpBody = Data(
            envelope(urn: service.urn, action: action, arguments: arguments).utf8
        )
        return request
    }

    /// Calls a SOAP action and returns the TV's reply.
    func call(
        _ service: TVService,
        action: String,
        arguments: String = "",
        on tv: PanasonicTV,
        timeout: TimeInterval? = nil
    ) async throws -> String {
        let request = try Self.request(
            for: service,
            action: action,
            arguments: arguments,
            on: tv,
            timeout: timeout ?? defaultTimeout
        )
        let (data, status) = try await perform(request, host: tv.host)
        let text = String(decoding: data, as: UTF8.self)

        guard (200..<300).contains(status) else {
            if let fault = PanasonicResponses.fault(from: text) {
                throw PanasonicError.soapFault(code: fault.code, description: fault.description)
            }
            if status == 403 {
                throw PanasonicError.forbidden
            }
            throw PanasonicError.httpError(status)
        }
        return text
    }

    /// Plain GET, e.g. for /nrc/ddd.xml.
    func get(
        path: String,
        on tv: PanasonicTV,
        timeout: TimeInterval? = nil
    ) async throws -> String {
        guard let url = tv.url(path: path) else {
            throw PanasonicError.notConfigured
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout ?? defaultTimeout
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, status) = try await perform(request, host: tv.host)
        guard (200..<300).contains(status) else {
            if status == 403 {
                throw PanasonicError.forbidden
            }
            throw PanasonicError.httpError(status)
        }
        return String(decoding: data, as: UTF8.self)
    }

    private func perform(_ request: URLRequest, host: String) async throws -> (Data, Int) {
        var retriedLostConnection = false
        while true {
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw PanasonicError.invalidResponse
                }
                return (data, http.statusCode)
            } catch let error as URLError
                        where error.code == .networkConnectionLost && !retriedLostConnection {
                // The TV closed an idle keep-alive connection. Try once more
                // on a fresh one.
                retriedLostConnection = true
            } catch {
                throw PanasonicError.from(error, host: host)
            }
        }
    }
}
