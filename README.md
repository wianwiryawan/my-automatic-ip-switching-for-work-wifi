# Automatic IP switching for Pujasera

Run from Terminal:

```bash
bash "/Users/rikin/Documents/ChatGPT/Work Wi-Fi IP Auto Switching/install.command"
```

Enter your administrator password and allow **Pujasera IP** to access Location Services. macOS requires that permission to reveal the connected Wi-Fi name. The app does not request or store geographic coordinates.

After two matching Wi-Fi observations (about 5–10 seconds), the helper requests:

- Any SSID in `work_ssids`: the manual IPv4 settings from `config.json` (initially Pujasera with `172.16.3.100`, `255.255.255.0`, router `172.16.3.1`).
- Any other readable Wi-Fi name: DHCP.
- No readable name, denied permission, or disconnection: leave the settings alone.

The service checks requests every five seconds and ignores requests older than 15 seconds. The menu-bar label shows the requested mode, not confirmation that the network has Internet access. The service reads the existing configuration before applying changes. DNS and IPv6 are left unchanged.

The app starts at login; the root-owned service starts at boot. The service accepts only manual/DHCP modes and strictly validated IPv4 arguments, and never executes commands from the user app. Source files remain here for review; the installed service and app are copied to system locations.

If the Location prompt does not appear, open System Settings → Privacy & Security → Location Services, enable Location Services and Pujasera IP, then reopen `/Applications/Pujasera IP.app`. This locally built app uses an ad-hoc signature; permission behavior must be checked on your Mac after installation.

To pause: choose **Quit automatic switching** from the IP menu. Existing IP settings remain; you can use the manual Bash scripts to change them. Reopen the app to resume. It starts again at next login.

To disable permanently:

```bash
launchctl bootout "gui/$(id -u)" "$HOME/Library/LaunchAgents/local.pujasera.ip-app.plist"
sudo launchctl bootout system /Library/LaunchDaemons/local.pujasera.ip-service.plist
```

Also move `~/Library/LaunchAgents/local.pujasera.ip-app.plist` and `/Library/LaunchDaemons/local.pujasera.ip-service.plist` out of those folders to prevent loading at the next login/boot. Quit the app. Return to DHCP with `bash wifi-dhcp.sh` if needed.

If your network service has a different name, pass it as the installer argument. Find service names with `networksetup -listallnetworkservices`.

Validation: Bash syntax and local Swift compilation can be checked without changing network settings. End-to-end switching requires installation, Location Services permission, and connecting to the two networks.

## Changing work networks and IP settings

Run the installer once again to upgrade an existing installation. Thereafter, use **IP menu → Edit configuration…**. The active file is:

`~/Library/Application Support/PujaseraIP/config.json`

```json
{
  "work_ssids": ["Pujasera", "New Office WiFi"],
  "ip_address": "172.16.3.100",
  "subnet_mask": "255.255.255.0",
  "router": "172.16.3.1"
}
```

SSID matches are exact and case-sensitive. All listed work networks share these IP settings. Other networks use DHCP. Add a new name before connecting to a renamed work network.

Save the file as plain-text JSON. Changes are read every five seconds; no rebuild, reinstall, or app restart is required. If JSON or settings are invalid or missing, the menu shows **IP: config error**, requests stop, and the app leaves network settings alone. Fix and save the file to resume. Requests already being processed can still finish.

The installer copies `config.json` only on first installation and preserves the active configuration on subsequent installs. Editing the workspace copy after installation does not change the active settings. Use the menu to edit the active file.
