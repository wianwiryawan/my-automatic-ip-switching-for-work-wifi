import Foundation

struct Settings: Decodable {
    struct Network: Decodable {
        let ssids: [String]
        let ip: String
        let subnet: String
        let gateway: String
    }
    let network_list: [Network]

    // Keep existing installed configurations working during an upgrade.
    private enum CodingKeys: String, CodingKey {
        case network_list, work_ssids, ip_address, subnet_mask, router
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        if values.contains(.network_list) {
            network_list = try values.decode([Network].self, forKey: .network_list)
        } else {
            network_list = [Network(
                ssids: try values.decode([String].self, forKey: .work_ssids),
                ip: try values.decode(String.self, forKey: .ip_address),
                subnet: try values.decode(String.self, forKey: .subnet_mask),
                gateway: try values.decode(String.self, forKey: .router))]
        }
    }

    func network(for ssid: String) -> Network? {
        network_list.first { $0.ssids.contains(ssid) }
    }

    func request(for ssid: String, timestamp: Int) -> String {
        guard let network = network(for: ssid) else { return "dhcp \(timestamp)\n" }
        return "manual \(timestamp) \(network.ip) \(network.subnet) \(network.gateway)\n"
    }

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
        var seen = Set<String>()
        for network in settings.network_list {
            guard !network.ssids.isEmpty,
                  network.ssids.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 32 && seen.insert($0).inserted }),
                  let ip = ipv4(network.ip),
                  let mask = ipv4(network.subnet),
                  let router = ipv4(network.gateway),
                  mask != 0, mask != UInt32.max,
                  (~mask & ((~mask) &+ 1)) == 0,
                  ip & mask == router & mask,
                  ip & ~mask != 0, ip & ~mask != ~mask,
                  router & ~mask != 0, router & ~mask != ~mask,
                  ip != router else {
                throw NSError(domain: "NetworkIPSwitching", code: 1, userInfo: [NSLocalizedDescriptionKey:
                    "Check network_list: use nonempty, unique SSIDs and valid IPv4 settings with a contiguous subnet mask and distinct IP/gateway hosts in the same subnet."])
            }
        }
        return settings
    }
}
