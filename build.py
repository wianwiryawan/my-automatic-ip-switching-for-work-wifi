#!/usr/bin/env python3
"""Build locally with Apple's installed Swift compiler; no downloads."""
import pathlib
import plistlib
import subprocess
import shutil

root = pathlib.Path(__file__).resolve().parent
app = root / "build/Automatic Network IP Switching.app"
contents = app / "Contents"
(contents / "MacOS").mkdir(parents=True, exist_ok=True)
with (contents / "Info.plist").open("wb") as f:
    plistlib.dump({
        "CFBundleIdentifier": "local.network-ip-switching",
        "CFBundleName": "Automatic Network IP Switching",
        "CFBundleExecutable": "NetworkIPSwitch",
        "CFBundlePackageType": "APPL",
        "CFBundleVersion": "4",
        "LSUIElement": True,
        "NSLocationUsageDescription": "Read the connected Wi-Fi name to use your configured work IP on work networks and DHCP elsewhere. No geographic coordinates are requested or stored.",
        "NSLocationAlwaysAndWhenInUseUsageDescription": "Read the Wi-Fi name for automatic IP switching.",
    }, f)
shutil.copyfile(root / "Switcher.swift", root / "build/main.swift")
subprocess.run(["xcrun", "swiftc", str(root / "Settings.swift"), str(root / "build/main.swift"), "-o", str(contents / "MacOS/NetworkIPSwitch"), "-framework", "AppKit", "-framework", "CoreLocation", "-framework", "CoreWLAN"], check=True)
subprocess.run(["codesign", "--force", "--sign", "-", str(app)], check=True)
print(app)
