import Foundation

struct Settings: Decodable {
    let work_ssids: [String]
    let ip_address: String
    let subnet_mask: String
    let router: String

    static func ipv4(_ text: String) -> UInt32? {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return nil }
        var value: UInt32 = 0
        for part in parts {
            guard !part.isEmpty, part.count <= 3,
                  part.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }),
                  part.count == 1 || part.first != "0",
                  let octet = UInt32(part), octet <= 255 else { return nil }
            value = (value << 8) | octet
        }
        return value
    }

    static func load(from url: URL) throws -> Settings {
        let settings = try JSONDecoder().decode(Settings.self, from: Data(contentsOf: url))
        guard !settings.work_ssids.isEmpty,
              settings.work_ssids.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 32 }),
              let ip = ipv4(settings.ip_address),
              let mask = ipv4(settings.subnet_mask),
              let router = ipv4(settings.router),
              mask != 0, mask != UInt32.max,
              (~mask & ((~mask) &+ 1)) == 0,
              ip & mask == router & mask,
              ip & ~mask != 0, ip & ~mask != ~mask,
              router & ~mask != 0, router & ~mask != ~mask,
              ip != router else {
            throw NSError(domain: "PujaseraIP", code: 1, userInfo: [NSLocalizedDescriptionKey:
                "Check work_ssids and IPv4 settings: use a contiguous subnet mask and distinct host/router addresses in the same subnet."])
        }
        return settings
    }
}
