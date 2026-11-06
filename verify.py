"""Verify config parsing and service behavior without changing network settings."""
import os
from pathlib import Path
import subprocess
import tempfile
import time

root = Path(__file__).resolve().parent
with tempfile.TemporaryDirectory() as temporary:
    directory = Path(temporary)
    main = directory / "main.swift"
    main.write_text((root / "test-settings.swift").read_text())
    executable = directory / "test-settings"
    subprocess.run(["xcrun", "swiftc", str(root / "Settings.swift"), str(main), "-o", str(executable)], check=True)
    subprocess.run([str(executable)], check=True)

    mock = directory / "networksetup"
    mock.write_text('''#!/bin/bash
case "$1" in
-getinfo) cat "$STATE" ;;
-setdhcp) echo dhcp >> "$LOG"; echo 'DHCP Configuration' > "$STATE" ;;
-setmanual)
  echo "$3 $4 $5" >> "$LOG"
  printf 'Manual Configuration\\nIP address: %s\\nSubnet mask: %s\\nRouter: %s\\nIPv6: Automatic\\n' "$3" "$4" "$5" > "$STATE"
  ;;
esac
''')
    mock.chmod(0o755)
    worker = directory / "service.sh"
    worker.write_text((root / "service.sh").read_text().replace("/usr/sbin/networksetup", str(mock)).replace("/bin/sleep 5", "/bin/sleep 0.05"))
    addresses = "192.168.8.20 255.255.255.0 192.168.8.1"
    for request, state, expected in [
        (f"manual {{time}} {addresses}", "DHCP Configuration\n", [addresses]),
        ("dhcp {time}", "Manual Configuration\n", ["dhcp"]),
        ("dhcp {time}", "DHCP Configuration\n", []),
        (f"manual 1 {addresses}", "DHCP Configuration\n", []),
        ("unknown {time}", "DHCP Configuration\n", []),
        ("manual {time} 999.1.1.1 255.255.255.0 192.168.8.1", "DHCP Configuration\n", []),
        ("manual {time} -setdhcp 255.255.255.0 192.168.8.1", "DHCP Configuration\n", []),
        ("dhcp {time} extra", "Manual Configuration\n", []),
        (f"manual {{time}} {addresses} extra", "DHCP Configuration\n", []),
    ]:
        (directory / "request").write_text(request.format(time=int(time.time())) + "\n")
        (directory / "state").write_text(state)
        (directory / "log").write_text("")
        process = subprocess.Popen(["/bin/bash", str(worker), str(directory / "request"), "Wi-Fi"], env={**os.environ, "STATE": str(directory / "state"), "LOG": str(directory / "log")}, stderr=subprocess.PIPE)
        try:
            time.sleep(1)
        finally:
            process.terminate()
            _, errors = process.communicate(timeout=5)
        actual = (directory / "log").read_text().splitlines()
        assert not errors, errors.decode()
        assert actual == expected, (request, actual, expected)
    print("Service checks passed: configurable addresses, DHCP, idempotence, stale requests and invalid arguments.")
