#!/bin/sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this command as root, or use: sudo sphinx archive-install"
    exit 1
fi

sh /usr/lib/sphinxpi/platform-check.sh
ARCH=$(dpkg --print-architecture)

echo "SphinxPi Archive Manager installer"
echo "Detected Debian architecture: $ARCH"
echo "This installs archive tools from your configured Debian repositories."
echo "RAR extraction is enabled only when the optional 7zip-rar package is available."
echo "No boot, kernel, firmware, partition or network settings are changed."
printf "Continue? [y/N] "
read answer
case "$answer" in
    y|Y|yes|YES) ;;
    *) echo "Cancelled. Nothing installed."; exit 0 ;;
esac

export DEBIAN_FRONTEND=noninteractive
apt-get update

required="whiptail zip unzip 7zip tar gzip bzip2"
optional="zstd lz4"
available=""
missing=""

for package in $required $optional; do
    candidate=$(apt-cache policy "$package" 2>/dev/null | awk '$1 == "Candidate:" {print $2}')
    if [ -n "$candidate" ] && [ "$candidate" != "(none)" ]; then
        available="$available $package"
    else
        missing="$missing $package"
    fi
done

RAR_CANDIDATE=$(apt-cache policy 7zip-rar 2>/dev/null | awk '$1 == "Candidate:" {print $2}')
if [ -n "$RAR_CANDIDATE" ] && [ "$RAR_CANDIDATE" != "(none)" ]; then
    available="$available 7zip-rar"
    echo "RAR extraction plugin is available."
else
    echo "RAR extraction plugin is unavailable; other supported formats remain usable."
fi

for package in $required; do
    case " $available " in
        *" $package "*) ;;
        *) echo "Required archive dependency '$package' is unavailable for $ARCH. Nothing installed."; exit 1 ;;
    esac
done

if [ -n "$missing" ]; then
    echo "Optional packages unavailable for $ARCH and will be skipped:$missing"
fi

sh /usr/lib/sphinxpi/track-install.sh $available
apt-get install -y --no-install-recommends $available

echo
for cmd in whiptail zip unzip 7z tar gzip bzip2; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Installation finished, but required command '$cmd' was not found."
        exit 1
    fi
done

echo "Archive tools installed and required command checks passed."
echo "Optional Zstandard/LZ4 support depends on the packages available for this architecture."
echo "Run 'sphinx archive' as your normal user."
