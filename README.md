# Automatic Network IP Switching

A macOS menu-bar helper that automatically applies a manual IPv4 configuration on selected Wi-Fi networks and uses DHCP on other networks. Each group of Wi-Fi names (SSIDs) can have its own IP address, subnet mask, and gateway.

## Requirements

- A Mac with Wi-Fi. Built and tested on macOS 26.5.1; other versions have not been verified.
- Python 3 and Apple's Swift compiler, available through Xcode or the Xcode Command Line Tools.
- An administrator account for installation and permission to access Location Services so the helper can read the connected Wi-Fi name.

## Installation

Download or clone this repository, then open Terminal in the project folder. Before the first installation, edit `config.json` to match your networks and the IP settings assigned to your Mac. The example addresses below must be replaced with addresses appropriate for your networks; each Mac needs its own available IP address.

Run:

```bash
bash install.command
```

The installer builds the helper, installs the app and background service, and starts them. Enter your administrator password when prompted.

Allow the **Automatic Network IP Switching** Location Services request so the helper can read the connected Wi-Fi name.

If the Location prompt does not appear, open **System Settings → Privacy & Security → Location Services**, enable Location Services and the helper's access, then reopen `/Applications/Automatic Network IP Switching.app`. The locally built app uses an ad-hoc signature; permission behavior must be checked on your Mac after installation. The app does not request or store geographic coordinates.

The default macOS network service name is `Wi-Fi`. If yours differs, list the services and pass the appropriate name to the installer:

```bash
networksetup -listallnetworkservices
bash install.command "Your network service name"
```

The service name identifies the Mac's network connection; SSIDs identify the wireless networks listed in your configuration.

## Configuring networks

After installation, choose **IP menu → Edit configuration…**. The active file is:

```text
~/Library/Application Support/NetworkIPSwitching/config.json
```

Example configuration:

```json
{
  "network_list": [
    {
      "ssids": ["Office", "Office5G"],
      "ip": "192.168.10.100",
      "subnet": "255.255.255.0",
      "gateway": "192.168.10.1"
    },
    {
      "ssids": ["Home", "Home5G"],
      "ip": "192.168.20.100",
      "subnet": "255.255.255.0",
      "gateway": "192.168.20.1"
    }
  ]
}
```

Each entry groups SSIDs that share its `ip`, `subnet`, and `gateway`. SSID matches are exact and case-sensitive. Duplicate SSIDs, including duplicates across entries, are rejected to avoid ambiguous settings.

- Listed networks use their matching manual IPv4 configuration.
- Unlisted networks use DHCP.
- An empty `network_list` uses DHCP on all identifiable networks.
- No readable Wi-Fi name, denied permission, or disconnection leaves the network settings unchanged.

Save the file as plain-text JSON. Changes are read every five seconds; no rebuild, reinstall, or app restart is required. If the configuration is invalid or missing, the menu shows **IP: config error** and stops submitting changes. Fix and save the file to resume. Requests already being processed can still finish.

The installer copies the repository's `config.json` only on first installation and preserves the active configuration on subsequent installs. Editing the repository copy after installation does not change the active settings. Use the menu to edit the active file.

## How switching works

After two matching Wi-Fi observations, the helper requests the matching settings. The background service checks requests every five seconds and ignores requests older than 15 seconds. Allow roughly 5–15 seconds for a switch.

The menu-bar label shows the requested mode, not confirmation that the network has Internet access. The service reads the existing configuration before applying changes. DNS and IPv6 settings are left unchanged.

The app starts at login; the root-owned service starts at boot. The service accepts only manual/DHCP modes and strictly validated IPv4 arguments, and never executes commands from the user app. Source files remain in the project folder; the installed service and app are copied to system locations.

## Upgrading

Run `bash install.command` again from the updated project folder. The installer rebuilds the helper and preserves your active configuration. When upgrading from the original app, it stops the previous helper and service, disables their login/boot entries, and copies your configuration into the new location if no new configuration exists. Allow Location Services for the renamed app when prompted. The previous app and configuration remain on disk for reference.

The old `work_ssids` format remains readable for existing installations. To use multiple IP configurations, replace the active file with the `network_list` format above after upgrading.

## Pausing or disabling

To pause, choose **Quit automatic switching** from the IP menu. Existing IP settings remain. Reopen the app to resume; it also starts again at the next login.

To stop loading the app and service permanently, run:

```bash
launchctl bootout "gui/$(id -u)" "$HOME/Library/LaunchAgents/local.network-ip-switching.app.plist"
sudo launchctl bootout system /Library/LaunchDaemons/local.network-ip-switching.service.plist
```

Then move these files out of their launch folders to prevent loading at the next login or boot:

- `~/Library/LaunchAgents/local.network-ip-switching.app.plist`
- `/Library/LaunchDaemons/local.network-ip-switching.service.plist`

Quit the app. If you want to return to DHCP, run the following, replacing `Wi-Fi` if your network service has a different name:

```bash
sudo networksetup -setdhcp "Wi-Fi"
```

## Validation

Run `python3 verify.py` from the project folder to check configuration parsing and simulated switching without changing network settings. End-to-end verification requires installation, Location Services permission, and connecting to the configured and unlisted networks.
