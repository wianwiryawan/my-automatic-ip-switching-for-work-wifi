import Foundation

let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: folder) }
let file = folder.appendingPathComponent("config.json")
let base: [String: Any] = ["work_ssids": ["Pujasera", "New Office"], "ip_address": "172.16.3.100", "subnet_mask": "255.255.255.0", "router": "172.16.3.1"]
func check(_ changes: [String: Any], valid: Bool) throws {
    let object = base.merging(changes) { _, new in new }
    try JSONSerialization.data(withJSONObject: object).write(to: file)
    do {
        let settings = try Settings.load(from: file)
        precondition(valid, "Accepted invalid settings: \(changes)")
        precondition(settings.work_ssids.contains("New Office"))
        precondition(!settings.work_ssids.contains("new office"))
    } catch { precondition(!valid, "Rejected valid settings: \(error)") }
}
try check([:], valid: true)
try check(["ip_address": "192.168.5.20", "router": "192.168.5.1"], valid: true)
for changes: [String: Any] in [
    ["work_ssids": []], ["work_ssids": [""]], ["ip_address": "256.1.2.3"],
    ["ip_address": "172.16.3.010"], ["ip_address": "-setdhcp"],
    ["subnet_mask": "255.0.255.0"], ["subnet_mask": "0.0.0.0"],
    ["router": "192.168.1.1"], ["router": "172.16.3.100"],
    ["ip_address": "172.16.3.0"], ["ip_address": "172.16.3.255"]
] { try check(changes, valid: false) }
try Data("{broken json".utf8).write(to: file)
do { _ = try Settings.load(from: file); fatalError("Accepted broken JSON") } catch {}
try FileManager.default.removeItem(at: file)
do { _ = try Settings.load(from: file); fatalError("Accepted missing file") } catch {}
print("Settings checks passed: multiple SSIDs, reload, invalid IPv4, mask/subnet checks, malformed/missing JSON.")
