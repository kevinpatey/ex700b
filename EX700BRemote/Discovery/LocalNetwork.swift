import Foundation

/// An IPv4 address on one of the phone's network interfaces.
struct IPv4Interface: Sendable, Equatable {
    /// e.g. "en0" (Wi-Fi on iPhone).
    let name: String
    /// Address in host byte order.
    let address: UInt32
    /// Netmask in host byte order.
    let netmask: UInt32

    var addressString: String { LocalNetwork.format(address) }
}

/// Works out which addresses on the home network to look at.
enum LocalNetwork {

    /// Wi-Fi / Ethernet IPv4 interfaces that are up, Wi-Fi (en0) first.
    static func ipv4Interfaces() -> [IPv4Interface] {
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0, let first = list else {
            return []
        }
        defer { freeifaddrs(list) }

        var result: [IPv4Interface] = []
        var cursor: UnsafeMutablePointer<ifaddrs>? = first

        while let entry = cursor {
            defer { cursor = entry.pointee.ifa_next }

            let flags = Int32(truncatingIfNeeded: Int(entry.pointee.ifa_flags))
            guard flags & Int32(IFF_UP) != 0,
                  flags & Int32(IFF_LOOPBACK) == 0,
                  let address = entry.pointee.ifa_addr,
                  Int32(address.pointee.sa_family) == AF_INET,
                  let netmask = entry.pointee.ifa_netmask
            else {
                continue
            }

            let name = String(cString: entry.pointee.ifa_name)
            let ip = address.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
                UInt32(bigEndian: $0.pointee.sin_addr.s_addr)
            }
            let mask = netmask.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
                UInt32(bigEndian: $0.pointee.sin_addr.s_addr)
            }
            result.append(IPv4Interface(name: name, address: ip, netmask: mask))
        }

        return result
            .filter { $0.name.hasPrefix("en") }
            .sorted { rank($0.name) < rank($1.name) }
    }

    /// "en0" is Wi-Fi on iPhone; other "en" interfaces are adapters.
    private static func rank(_ name: String) -> Int {
        name == "en0" ? 0 : 1
    }

    /// Every other address on the same subnet. Big networks are cut down
    /// to the /24 around the phone so a scan stays quick.
    static func hostsToScan(for interface: IPv4Interface) -> [String] {
        var mask = interface.netmask
        let hostBits = 32 - mask.nonzeroBitCount
        if hostBits > 10 || hostBits < 2 {
            mask = 0xFFFF_FF00
        }

        let network = interface.address & mask
        let broadcast = network | ~mask
        guard broadcast > network &+ 1 else { return [] }

        var hosts: [String] = []
        var candidate = network + 1
        while candidate < broadcast {
            if candidate != interface.address {
                hosts.append(format(candidate))
            }
            candidate += 1
        }
        return hosts
    }

    /// 0xC0A801C6 → "192.168.1.198"
    static func format(_ address: UInt32) -> String {
        let a = (address >> 24) & 0xFF
        let b = (address >> 16) & 0xFF
        let c = (address >> 8) & 0xFF
        let d = address & 0xFF
        return "\(a).\(b).\(c).\(d)"
    }

    /// "192.168.1.198" → 0xC0A801C6 (nil if it isn't a plain IPv4 address).
    static func parse(_ text: String) -> UInt32? {
        let parts = text.trimmingCharacters(in: .whitespaces).split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return nil }
        var value: UInt32 = 0
        for part in parts {
            guard !part.isEmpty, part.count <= 3,
                  part.allSatisfy({ $0.isASCII && $0.isNumber }),
                  let octet = UInt32(part), octet <= 255
            else {
                return nil
            }
            value = (value << 8) | octet
        }
        return value
    }
}
