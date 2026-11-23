#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
SOURCE="$ROOT_DIR/src/sphinx"
VERSION="0.1.0"

if [ "$(id -u)" -ne 0 ]; then
    echo "This installer needs root privileges."
    echo "On DietPi, if you are logged in as root, run:"
    echo "  sh scripts/install.sh"
    echo "From a normal user account, run:"
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
ARCH=$(dpkg --print-architecture 2>/dev/null || true)
if [ "$MACHINE" != "armv6l" ] || [ "$ARCH" != "armel" ]; then
    echo "SphinxPi targets the original Raspberry Pi Zero family (ARMv6 / armel)."
    echo "Detected CPU: $MACHINE"
    echo "Detected Debian architecture: ${ARCH:-unknown}"
    exit 1
fi

[ -f "$SOURCE" ] || { echo "Missing CLI source: $SOURCE"; exit 1; }
[ -f "$SCRIPT_DIR/desktop-install.sh" ] || { echo "Missing desktop installer."; exit 1; }
[ -f "$SCRIPT_DIR/desktop-layout.sh" ] || { echo "Missing desktop layout helper."; exit 1; }
[ -f "$SCRIPT_DIR/archive-install.sh" ] || { echo "Missing archive installer."; exit 1; }
[ -f "$SCRIPT_DIR/archive-manager.sh" ] || { echo "Missing archive manager."; exit 1; }
[ -f "$SCRIPT_DIR/uninstall.sh" ] || { echo "Missing uninstaller."; exit 1; }

DEST="/usr/local/bin/sphinx"
LIB_DIR="/usr/lib/sphinxpi"
CONFIG_DIR="/etc/sphinxpi"

install -d -m 0755 "$LIB_DIR"
install -m 0755 "$SCRIPT_DIR/desktop-install.sh" "$LIB_DIR/desktop-install.sh"
install -m 0755 "$SCRIPT_DIR/desktop-layout.sh" "$LIB_DIR/desktop-layout.sh"
install -m 0755 "$SCRIPT_DIR/archive-install.sh" "$LIB_DIR/archive-install.sh"
install -m 0755 "$SCRIPT_DIR/archive-manager.sh" "$LIB_DIR/archive-manager.sh"
install -m 0755 "$SCRIPT_DIR/uninstall.sh" "$LIB_DIR/uninstall.sh"

mkdir -p "$CONFIG_DIR"
printf '%s\n' "$VERSION" > "$CONFIG_DIR/version"

if [ -e "$DEST" ]; then
    BACKUP="$DEST.backup.$(date +%Y%m%d%H%M%S)"
    cp -p "$DEST" "$BACKUP"
    echo "Existing command backed up to: $BACKUP"
fi

install -D -m 0755 "$SOURCE" "$DEST"

echo "SphinxPi CLI and helper scripts installed."
echo "Try: sphinx help"
echo "No packages, boot files, kernel, firmware, network settings or partitions were changed."
