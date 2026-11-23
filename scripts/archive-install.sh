#!/bin/sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this command as root. On DietPi, log in as root and run: sphinx archive-install"
    exit 1
fi

if [ ! -r /etc/os-release ]; then
    echo "Cannot identify the operating system. Nothing changed."
    exit 1
fi
. /etc/os-release
if [ "${ID:-}" != "debian" ] || [ "${VERSION_CODENAME:-}" != "trixie" ]; then
    echo "The Archive Manager installer currently targets Debian Trixie."
    echo "Detected: ${PRETTY_NAME:-unknown}"
    exit 1
fi

ARCH=$(dpkg --print-architecture)
if [ "$ARCH" != "armel" ] || [ "$(uname -m)" != "armv6l" ]; then
    echo "The Archive Manager installer targets the original Pi Zero (ARMv6 / armel)."
    echo "Detected: $(uname -m) / $ARCH"
    exit 1
fi

echo "SphinxPi Archive Manager installer"
echo "This installs whiptail, ZIP tools, 7-Zip and XZ utilities for Debian Trixie ($ARCH)."
echo "The Debian 7zip package provides the '7z' command."
echo "It does not change boot, kernel, firmware, partitions or network settings."
printf "Continue? [y/N] "
read answer
case "$answer" in
    y|Y|yes|YES) ;;
    *) echo "Cancelled. Nothing installed."; exit 0 ;;
esac

export DEBIAN_FRONTEND=noninteractive
apt-get update
/usr/lib/sphinxpi/track-install.sh whiptail zip unzip 7zip xz-utils
apt-get install --no-install-recommends whiptail zip unzip 7zip xz-utils

echo
for cmd in whiptail zip unzip 7z xz; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Installation finished, but '$cmd' was not found."
        echo "Check the apt output above before using the Archive Manager."
        exit 1
    fi
done

echo "Archive tools installed and command checks passed."
echo "Run 'sphinx archive' as your normal user."
