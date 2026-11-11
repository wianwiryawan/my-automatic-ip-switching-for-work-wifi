"""Compatibility identifiers used only to upgrade the original installation."""
import pathlib
import shutil
import subprocess

LEGACY_SUPPORT = "PujaseraIP"
LEGACY_SERVICE = "local.pujasera.ip-service.plist"
LEGACY_AGENT = "local.pujasera.ip-app.plist"


def migrate(home: pathlib.Path, uid: int, destination: pathlib.Path, *, system_launch_dir=None):
    # These names identify existing installations, not the renamed app.
    legacy_config = home / "Library/Application Support" / LEGACY_SUPPORT / "config.json"
    if not destination.exists() and legacy_config.is_file():
        shutil.copyfile(legacy_config, destination)

    for domain, path in [
        ("system", (system_launch_dir or pathlib.Path("/Library/LaunchDaemons")) / LEGACY_SERVICE),
        (f"gui/{uid}", home / "Library/LaunchAgents" / LEGACY_AGENT),
    ]:
        if path.exists():
            subprocess.run(["/bin/launchctl", "bootout", domain, str(path)],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            # Keep a backup, but prevent the old service from loading again.
            path.rename(path.with_suffix(".plist.disabled"))
    subprocess.run(["/usr/bin/pkill", "-u", str(uid), "-x", LEGACY_SUPPORT],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
