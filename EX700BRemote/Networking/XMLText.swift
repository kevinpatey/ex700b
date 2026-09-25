import Foundation

/// Tiny helpers for the small, simple XML the TV sends back.
/// (Good enough for UPnP replies; not a general XML parser.)
enum XMLText {

    /// Escapes text so it can go inside an XML element.
    static func escape(_ value: String) -> String {
        var result = ""
        result.reserveCapacity(value.count)
        for character in value {
            switch character {
            case "&": result += "&amp;"
            case "<": result += "&lt;"
            case ">": result += "&gt;"
            case "\"": result += "&quot;"
            case "'": result += "&apos;"
            default: result.append(character)
            }
        }
        return result
    }

    /// Turns &amp; &lt; &gt; &quot; &apos; &#39; &#x27; back into characters.
    static func decodeEntities(_ value: String) -> String {
        guard value.contains("&") else { return value }

        var result = ""
        result.reserveCapacity(value.count)
        var index = value.startIndex

        while index < value.endIndex {
            let character = value[index]
            guard character == "&",
                  let semicolon = value[index...].prefix(12).firstIndex(of: ";")
            else {
                result.append(character)
                index = value.index(after: index)
                continue
            }

            let entity = String(value[value.index(after: index)..<semicolon])
            if let decoded = decode(entity: entity) {
                result.append(decoded)
                index = value.index(after: semicolon)
            } else {
                result.append(character)
                index = value.index(after: index)
            }
        }
        return result
    }

    private static func decode(entity: String) -> Character? {
        switch entity {
        case "amp": return "&"
        case "lt": return "<"
        case "gt": return ">"
        case "quot": return "\""
        case "apos": return "'"
        default: break
        }
        var number: UInt32?
        if entity.hasPrefix("#x") || entity.hasPrefix("#X") {
            number = UInt32(entity.dropFirst(2), radix: 16)
        } else if entity.hasPrefix("#") {
            number = UInt32(entity.dropFirst(1), radix: 10)
        }
        if let number, let scalar = Unicode.Scalar(number) {
            return Character(scalar)
        }
        return nil
    }

    /// Raw inner XML of every element with this local name, ignoring any
    /// namespace prefix (`<u:Foo>`, `<Foo attr="x">`, `<Foo/>` all match).
    static func rawValues(of localName: String, in xml: String) -> [String] {
        guard let regex = regex(for: localName) else { return [] }
        let range = NSRange(xml.startIndex..<xml.endIndex, in: xml)
        return regex.matches(in: xml, options: [], range: range).map { match in
            let content = match.range(at: 1)
            guard content.location != NSNotFound,
                  let swiftRange = Range(content, in: xml)
            else {
                return "" // self-closing element
            }
            return String(xml[swiftRange])
        }
    }

    /// Raw inner XML of the first matching element.
    static func rawValue(of localName: String, in xml: String) -> String? {
        rawValues(of: localName, in: xml).first
    }

    /// Decoded, trimmed text of the first matching element.
    static func value(of localName: String, in xml: String) -> String? {
        rawValue(of: localName, in: xml).map {
            decodeEntities($0).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    /// Decoded, trimmed text of every matching element.
    static func values(of localName: String, in xml: String) -> [String] {
        rawValues(of: localName, in: xml).map {
            decodeEntities($0).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private static func regex(for localName: String) -> NSRegularExpression? {
        let name = NSRegularExpression.escapedPattern(for: localName)
        let prefix = "(?:[A-Za-z_][A-Za-z0-9_.\\-]*:)?"
        let pattern = "<\(prefix)\(name)(?:\\s[^>]*)?"
            + "(?:/>|(?<!/)>([\\s\\S]*?)</\(prefix)\(name)\\s*>)"
        return try? NSRegularExpression(pattern: pattern, options: [])
    }
}
