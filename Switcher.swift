import AppKit
import CoreLocation
import CoreWLAN

final class Switcher: NSObject, NSApplicationDelegate, CLLocationManagerDelegate {
    let location = CLLocationManager()
    let wifi = CWWiFiClient.shared()
    var status: NSStatusItem!
    var timer: Timer?
    var candidate = ""
    var count = 0
    let request = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/NetworkIPSwitching/request")
    let configuration = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/NetworkIPSwitching/config.json")

    func applicationDidFinishLaunching(_ notification: Notification) {
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        status.button?.title = "IP: …"
        let menu = NSMenu()
        menu.addItem(withTitle: "Check now", action: #selector(check), keyEquivalent: "")
        menu.addItem(withTitle: "Edit configuration…", action: #selector(editConfiguration), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit automatic switching", action: #selector(quit), keyEquivalent: "q")
        for item in menu.items { item.target = self }
        status.menu = menu
        location.delegate = self
        if location.authorizationStatus == .notDetermined {
            NSApp.activate(ignoringOtherApps: true)
            location.requestAlwaysAuthorization()
        }
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in self?.check() }
        check()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) { check() }

    @objc func check() {
        let settings: Settings
        do {
            settings = try Settings.load(from: configuration)
        } catch {
            status.button?.title = "IP: config error"
            status.button?.toolTip = error.localizedDescription
            invalidate()
            return
        }
        let auth = location.authorizationStatus
        guard auth == .authorizedAlways || auth == .authorized else {
            status.button?.title = "IP: permission"
            status.button?.toolTip = "Allow Automatic Network IP Switching in System Settings → Privacy & Security → Location Services."
            invalidate()
            return
        }
        guard let ssid = wifi.interface()?.ssid(), !ssid.isEmpty, ssid != "<redacted>" else {
            status.button?.title = "IP: waiting"
            status.button?.toolTip = "No readable Wi-Fi name; settings are left unchanged."
            invalidate()
            return
        }
        // Require two consecutive observations to avoid acting during a handover.
        if candidate == ssid { count += 1 } else { candidate = ssid; count = 1 }
        guard count >= 2 else { invalidate(reset: false); return }
        let mode = settings.network(for: ssid) == nil ? "dhcp" : "manual"
        do {
            try settings.request(for: ssid, timestamp: Int(Date().timeIntervalSince1970)).write(to: request, atomically: true, encoding: .utf8)
            status.button?.title = mode == "manual" ? "IP: manual" : "IP: DHCP"
            status.button?.toolTip = "Network: \(ssid). Requested \(mode); service checks every 5 seconds."
        } catch {
            status.button?.title = "IP: error"
            status.button?.toolTip = error.localizedDescription
        }
    }

    func invalidate(reset: Bool = true) {
        if reset { candidate = ""; count = 0 }
        try? FileManager.default.removeItem(at: request)
    }

    @objc func quit() { invalidate(); NSApp.terminate(nil) }

    @objc func editConfiguration() {
        NSWorkspace.shared.open([configuration], withApplicationAt: URL(fileURLWithPath: "/System/Applications/TextEdit.app"), configuration: NSWorkspace.OpenConfiguration())
    }
}

let app = NSApplication.shared
let delegate = Switcher()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
