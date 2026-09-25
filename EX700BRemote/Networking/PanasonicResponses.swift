import Foundation

/// What the TV says about itself in /nrc/ddd.xml.
struct TVDeviceInfo: Sendable, Hashable {
    var friendlyName: String
    var manufacturer: String
    var modelName: String
    var modelNumber: String
    var udn: String?

    /// Best short model string, e.g. "TX-50EX700B".
    var model: String {
        if !modelNumber.isEmpty { return modelNumber }
        return modelName
    }

    var isPanasonic: Bool {
        manufacturer.localizedCaseInsensitiveContains("panasonic")
    }
}

/// Parsers for the TV's replies. Kept free of networking so they're easy to test.
enum PanasonicResponses {

    /// Parses /nrc/ddd.xml (UPnP device description).
    static func deviceInfo(from xml: String) -> TVDeviceInfo? {
        // The remote-control device description always mentions this
        // service; plain DLNA renderers from other brands don't.
        let mentionsNetworkControl = xml.contains("p00NetworkControl")
            || xml.contains("p00RemoteController")
        let manufacturer = XMLText.value(of: "manufacturer", in: xml) ?? ""

        guard mentionsNetworkControl
                || manufacturer.localizedCaseInsensitiveContains("panasonic")
        else {
            return nil
        }

        let udn = XMLText.value(of: "UDN", in: xml)
        return TVDeviceInfo(
            friendlyName: XMLText.value(of: "friendlyName", in: xml) ?? "Panasonic TV",
            manufacturer: manufacturer.isEmpty ? "Panasonic" : manufacturer,
            modelName: XMLText.value(of: "modelName", in: xml) ?? "",
            modelNumber: XMLText.value(of: "modelNumber", in: xml) ?? "",
            udn: (udn?.isEmpty ?? true) ? nil : udn
        )
    }

    /// Action names from a UPnP service description (/nrc/sdd_0.xml).
    static func actionNames(from xml: String) -> [String] {
        XMLText.rawValues(of: "action", in: xml).compactMap { block in
            // The first <name> inside <action> is the action's own name;
            // later ones belong to its arguments.
            XMLText.value(of: "name", in: block)
        }
    }

    /// Parses a UPnP SOAP fault: <errorCode>401</errorCode><errorDescription>…
    static func fault(from xml: String) -> (code: String, description: String)? {
        guard let code = XMLText.value(of: "errorCode", in: xml), !code.isEmpty else {
            return nil
        }
        let description = XMLText.value(of: "errorDescription", in: xml)
            ?? XMLText.value(of: "faultstring", in: xml)
            ?? "Unknown error"
        return (code, description)
    }

    /// Parses the reply to X_GetAppList.
    ///
    /// The list is one long string where fields are separated by
    /// apostrophes (sent as &apos;), e.g.
    /// `vc_app'Stop'product_id=0070000200170001'YouTube'…`
    static func apps(from xml: String) -> [TVApp] {
        var text = XMLText.rawValue(of: "X_AppList", in: xml) ?? xml

        // Some TVs escape twice (&amp;apos;), so decode until stable.
        for _ in 0..<3 {
            let decoded = XMLText.decodeEntities(text)
            if decoded == text { break }
            text = decoded
        }

        var apps: [TVApp] = []
        var seen = Set<String>()

        for chunk in text.components(separatedBy: "vc_app").dropFirst() {
            let fields = chunk
                .components(separatedBy: "'")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

            guard let keywordIndex = fields.firstIndex(where: {
                $0.hasPrefix("product_id=") || $0.hasPrefix("resource_id=")
            }) else {
                continue
            }

            let keyword = fields[keywordIndex]
            let identifier = keyword.drop(while: { $0 != "=" }).dropFirst()
            let nextField = keywordIndex + 1 < fields.count ? fields[keywordIndex + 1] : ""
            let name = nextField.isEmpty ? keyword : nextField

            guard keyword.contains("="),
                  !identifier.isEmpty,
                  !seen.contains(keyword)
            else {
                continue
            }
            seen.insert(keyword)
            apps.append(TVApp(name: name, launchKeyword: keyword))
        }
        return apps
    }

    /// Number inside <CurrentVolume>.
    static func volume(from xml: String) -> Int? {
        XMLText.value(of: "CurrentVolume", in: xml).flatMap { Int($0) }
    }

    /// Value of <CurrentMute> ("0" / "1").
    static func mute(from xml: String) -> Bool? {
        guard let text = XMLText.value(of: "CurrentMute", in: xml) else { return nil }
        switch text.lowercased() {
        case "1", "true", "yes": return true
        case "0", "false", "no": return false
        default: return nil
        }
    }
}
