#!/bin/bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
PYTHON="$(command -v python3)"
# Rebuild so upgrades cannot accidentally reinstall an older cached executable.
"$PYTHON" build.py
sudo "$PYTHON" install.py "${1:-Wi-Fi}"
