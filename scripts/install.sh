#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
SOURCE="$ROOT_DIR/src/sphinx"

if [ "$(id -u)" -ne 0 ]; then
    echo "Please run this installer with sudo:"
    echo "  sudo sh scripts/install.sh"
    exit 1
fi

if [ ! -f /etc/os-release ]; then
    echo "Cannot identify the operating system. Nothing changed."
    exit 1
fi

. /etc/os-release
case "${ID:-}" in
    debian) ;;
    *) echo "SphinxPi currently supports Debian-based DietPi only."; echo "Detected: ${PRETTY_NAME:-unknown}"; exit 1 ;;
esac

MACHINE=$(uname -m)
case "$MACHINE" in
    armv6l|armv7l|aarch64|x86_64) ;;
    *) echo "Unsupported CPU architecture: $MACHINE"; exit 1 ;;
esac

[ -f "$SOURCE" ] || { echo "Missing CLI source: $SOURCE"; exit 1; }
[ -f "$SCRIPT_DIR/desktop-install.sh" ] || { echo "Missing desktop installer."; exit 1; }
[ -f "$SCRIPT_DIR/desktop-layout.sh" ] || { echo "Missing desktop layout helper."; exit 1; }
[ -f "$SCRIPT_DIR/archive-install.sh" ] || { echo "Missing archive installer."; exit 1; }
[ -f "$SCRIPT_DIR/archive-manager.sh" ] || { echo "Missing archive manager."; exit 1; }

DEST="/usr/local/bin/sphinx"
LIB_DIR="/usr/lib/sphinxpi"
CONFIG_DIR="/etc/sphinxpi"

# Install helper programs first so the new CLI never points to missing helpers.
install -d -m 0755 "$LIB_DIR"
install -m 0755 "$SCRIPT_DIR/desktop-install.sh" "$LIB_DIR/desktop-install.sh"
install -m 0755 "$SCRIPT_DIR/desktop-layout.sh" "$LIB_DIR/desktop-layout.sh"
install -m 0755 "$SCRIPT_DIR/archive-install.sh" "$LIB_DIR/archive-install.sh"
install -m 0755 "$SCRIPT_DIR/archive-manager.sh" "$LIB_DIR/archive-manager.sh"

mkdir -p "$CONFIG_DIR"
if [ ! -f "$CONFIG_DIR/version" ]; then
    printf '%s\n' "0.1.0" > "$CONFIG_DIR/version"
fi

if [ -e "$DEST" ]; then
    BACKUP="$DEST.backup.$(date +%Y%m%d%H%M%S)"
    cp -p "$DEST" "$BACKUP"
    echo "Existing command backed up to: $BACKUP"
fi

install -D -m 0755 "$SOURCE" "$DEST"

echo "SphinxPi CLI installed."
echo "No packages, boot files, kernel, firmware, or partitions were changed."
echo "Try: sphinx help"
