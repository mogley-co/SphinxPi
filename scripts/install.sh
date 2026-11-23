#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
sh "$ROOT/scripts/platform-check.sh"
sh "$ROOT/scripts/build-deb.sh"
VERSION=$(cat "$ROOT/VERSION")
PACKAGE="$ROOT/dist/sphinxpi_${VERSION}_all.deb"
if [ "$(id -u)" -eq 0 ]; then
    apt-get install "$PACKAGE"
elif command -v sudo >/dev/null 2>&1; then
    sudo apt-get install "$PACKAGE"
else
    echo "Install as root with: apt-get install '$PACKAGE'"
    exit 1
fi
