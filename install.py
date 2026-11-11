#!/usr/bin/env python3
"""Run via install.command. Installs the already-built app and configuration-driven service."""
import os
import pathlib
import plistlib
import pwd
import shutil
import subprocess
import sys
from migrate_legacy import migrate

root = pathlib.Path(__file__).resolve().parent
if os.geteuid() != 0 or not os.environ.get("SUDO_UID"):
    sys.exit("Run install.command from Terminal as your normal user.")
uid = int(os.environ["SUDO_UID"])
user = pwd.getpwuid(uid)
home = pathlib.Path(user.pw_dir)
service = sys.argv[1] if len(sys.argv) > 1 else "Wi-Fi"
services = subprocess.check_output(["/usr/sbin/networksetup", "-listallnetworkservices"], text=True)
if service not in [line.lstrip("*") for line in services.splitlines()[1:]]:
    sys.exit(f"Network service {service!r} not found. Run networksetup -listallnetworkservices and pass its name to install.command.")

app = pathlib.Path("/Applications/Automatic Network IP Switching.app")
daemon_dir = pathlib.Path("/Library/Application Support/NetworkIPSwitching")
daemon_plist = pathlib.Path("/Library/LaunchDaemons/local.network-ip-switching.service.plist")
agent_plist = home / "Library/LaunchAgents/local.network-ip-switching.app.plist"
requests = home / "Library/Application Support/NetworkIPSwitching"
for domain, path in [("system", daemon_plist), (f"gui/{uid}", agent_plist)]:
    subprocess.run(["/bin/launchctl", "bootout", domain, str(path)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
subprocess.run(["/usr/bin/pkill", "-u", str(uid), "-x", "NetworkIPSwitch"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

shutil.copytree(root / "build/Automatic Network IP Switching.app", app, dirs_exist_ok=True)
for entry in [app, *app.rglob("*")]:
    os.chown(entry, 0, 0)
daemon_dir.mkdir(parents=True, exist_ok=True)
os.chmod(daemon_dir, 0o755)
os.chown(daemon_dir, 0, 0)
shutil.copyfile(root / "service.sh", daemon_dir / "service.sh")
os.chmod(daemon_dir / "service.sh", 0o755)
os.chown(daemon_dir / "service.sh", 0, 0)
requests.mkdir(parents=True, exist_ok=True)
os.chown(requests, uid, user.pw_gid)
os.chmod(requests, 0o700)
config = requests / "config.json"
migrate(home, uid, config)
if not config.exists():
    shutil.copyfile(root / "config.json", config)
os.chown(config, uid, user.pw_gid)
os.chmod(config, 0o600)
(requests / "request").unlink(missing_ok=True)
agent_plist.parent.mkdir(parents=True, exist_ok=True)
os.chown(agent_plist.parent, uid, user.pw_gid)

def write_plist(path, value, owner):
    with path.open("wb") as f:
        plistlib.dump(value, f)
    os.chmod(path, 0o644)
    os.chown(path, owner, user.pw_gid if owner else 0)

write_plist(daemon_plist, {
    "Label": "local.network-ip-switching.service",
    "ProgramArguments": ["/bin/bash", str(daemon_dir / "service.sh"), str(requests / "request"), service],
    "RunAtLoad": True, "KeepAlive": True,
    "StandardErrorPath": "/var/log/network-ip-switching.log",
    "StandardOutPath": "/var/log/network-ip-switching.log",
}, 0)
write_plist(agent_plist, {
    "Label": "local.network-ip-switching.app",
    "ProgramArguments": ["/usr/bin/open", "-a", str(app), "--args"],
    "RunAtLoad": True,
    "LimitLoadToSessionType": "Aqua",
}, uid)
subprocess.run(["/bin/launchctl", "bootstrap", "system", str(daemon_plist)], check=True)
subprocess.run(["/bin/launchctl", "bootstrap", f"gui/{uid}", str(agent_plist)], check=True)
print("Installed. Allow Location Services for Automatic Network IP Switching when prompted. Look for IP: manual or IP: DHCP in the menu bar.")
