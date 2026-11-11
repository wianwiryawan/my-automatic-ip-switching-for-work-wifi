import Foundation

let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: folder) }
let file = folder.appendingPathComponent("config.json")
let work: [String: Any] = ["ssids": ["Office", "Office5G"], "ip": "172.16.3.100", "subnet": "255.255.255.0", "gateway": "172.16.3.1"]
let home: [String: Any] = ["ssids": ["Home", "Home5G"], "ip": "172.16.1.2", "subnet": "255.255.255.0", "gateway": "172.16.1.1"]
func load(_ object: [String: Any]) throws -> Settings {
    try JSONSerialization.data(withJSONObject: object).write(to: file)
    return try Settings.load(from: file)
}
func reject(_ object: [String: Any]) {
    do { _ = try load(object); fatalError("Accepted invalid settings: \(object)") } catch {}
}
let settings = try load(["network_list": [work, home]])
for ssid in ["Office", "Office5G"] {
    precondition(settings.request(for: ssid, timestamp: 123) == "manual 123 172.16.3.100 255.255.255.0 172.16.3.1\n")
}
for ssid in ["Home", "Home5G"] {
    precondition(settings.request(for: ssid, timestamp: 123) == "manual 123 172.16.1.2 255.255.255.0 172.16.1.1\n")
}
for ssid in ["Unknown", "home"] {
    precondition(settings.request(for: ssid, timestamp: 123) == "dhcp 123\n")
}
let empty = try load(["network_list": []])
precondition(empty.request(for: "Office", timestamp: 123) == "dhcp 123\n")
let changed = try load(["network_list": [work.merging(["ip": "172.16.3.101"]) { _, new in new }]])
precondition(changed.network(for: "Office")?.ip == "172.16.3.101")
precondition(changed.network(for: "Home") == nil)
for changes: [String: Any] in [
    ["ssids": []], ["ssids": [""]], ["ssids": [String(repeating: "x", count: 33)]],
    ["ssids": ["Home"]], ["ssids": ["Office", "Office"]],
    ["ip": "256.1.2.3"], ["ip": "172.16.3.010"], ["ip": "-setdhcp"],
    ["subnet": "255.0.255.0"], ["subnet": "0.0.0.0"],
    ["gateway": "192.168.1.1"], ["gateway": "172.16.3.100"],
    ["ip": "172.16.3.0"], ["ip": "172.16.3.255"]
] {
    reject(["network_list": [work.merging(changes) { _, new in new }, home]])
}
reject(["network_list": [["ssids": ["Missing fields"]]]])
reject(["network_list": NSNull()])
reject(["network_list": "wrong type"])
let legacy: [String: Any] = ["work_ssids": ["Old Office"], "ip_address": "172.16.3.100", "subnet_mask": "255.255.255.0", "router": "172.16.3.1"]
let old = try load(legacy)
precondition(old.network(for: "Old Office")?.ip == "172.16.3.100")
reject(legacy.merging(["network_list": NSNull()]) { _, new in new })
try Data("{broken json".utf8).write(to: file)
do { _ = try Settings.load(from: file); fatalError("Accepted broken JSON") } catch {}
try FileManager.default.removeItem(at: file)
do { _ = try Settings.load(from: file); fatalError("Accepted missing file") } catch {}
print("Settings checks passed: separate network profiles, SSID aliases, DHCP fallback, reloads, duplicate rejection, IPv4 validation and legacy configs.")
