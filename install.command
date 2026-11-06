#!/bin/bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
PYTHON="$(command -v python3)"
if [[ ! -x "build/Pujasera IP.app/Contents/MacOS/PujaseraIP" ]]; then
  "$PYTHON" build.py
fi
sudo "$PYTHON" install.py "${1:-Wi-Fi}"
