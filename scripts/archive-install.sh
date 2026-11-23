#!/bin/sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this command as root, or use: sudo sphinx archive-install"
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
echo "This installs Archive Manager dependencies: whiptail, ZIP tools, 7-Zip, TAR, gzip, bzip2, zstd and lz4 for Debian 13+ ($ARCH)."
echo "The Debian 7zip package provides the '7z' command."
echo "RAR extraction is enabled when the optional 7zip-rar package is available from your configured repositories; RAR creation is not supported."
echo "It does not change boot, kernel, firmware, partitions or network settings."
printf "Continue? [y/N] "
read answer
case "$answer" in
    y|Y|yes|YES) ;;
    *) echo "Cancelled. Nothing installed."; exit 0 ;;
esac

export DEBIAN_FRONTEND=noninteractive
apt-get update
ARCHIVE_PACKAGES="whiptail zip unzip 7zip tar gzip bzip2 zstd lz4"
RAR_CANDIDATE=$(apt-cache policy 7zip-rar 2>/dev/null | awk '$1 == "Candidate:" {print $2}')
if [ -n "$RAR_CANDIDATE" ] && [ "$RAR_CANDIDATE" != "(none)" ]; then
    ARCHIVE_PACKAGES="$ARCHIVE_PACKAGES 7zip-rar"
    echo "RAR extraction plugin is available and will be installed."
else
    echo "RAR extraction plugin is unavailable in the configured APT repositories."
fi
sh sh /usr/lib/sphinxpi/track-install.sh $ARCHIVE_PACKAGES
apt-get install -y --no-install-recommends $ARCHIVE_PACKAGES

echo
for cmd in whiptail zip unzip 7z tar gzip bzip2 zstd lz4; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Installation finished, but '$cmd' was not found."
        echo "Check the apt output above before using the Archive Manager."
        exit 1
    fi
done

echo "Archive tools installed and command checks passed."
echo "RAR extraction is available only if the 7zip-rar plugin was installed."
echo "Run 'sphinx archive' as your normal user."
