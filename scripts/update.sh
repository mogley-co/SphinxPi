#!/bin/sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this command as root. Use: sudo sphinx update" >&2
    exit 1
fi

if command -v whiptail >/dev/null 2>&1; then
 whiptail --title "SphinxPi Updater" --yesno "Download, build and install the latest SphinxPi version from GitHub?" 9 65 || exit 0
fi
ARCHIVE_URL="https://codeload.github.com/mogley-co/SphinxPi/tar.gz/refs/heads/main"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/sphinxpi-update.XXXXXX")
trap 'rm -rf "$WORK"' EXIT HUP INT TERM

if command -v curl >/dev/null 2>&1; then
    curl --fail --location --silent --show-error --retry 2 "$ARCHIVE_URL" -o "$WORK/source.tar.gz"
elif command -v wget >/dev/null 2>&1; then
    wget -q "$ARCHIVE_URL" -O "$WORK/source.tar.gz"
else
    echo "Neither curl nor wget is installed. Install one with: apt-get install curl" >&2
    exit 1
fi

mkdir "$WORK/source"
tar -xzf "$WORK/source.tar.gz" -C "$WORK/source" --strip-components=1

if [ ! -f "$WORK/source/VERSION" ] || [ ! -f "$WORK/source/scripts/build-deb.sh" ]; then
    echo "Downloaded SphinxPi source is incomplete. Nothing was installed." >&2
    exit 1
fi

NEW_VERSION=$(cat "$WORK/source/VERSION")
case "$NEW_VERSION" in
    ""|*[!0-9.]*)
        echo "The downloaded version number is invalid. Nothing was installed." >&2
        exit 1
        ;;
esac

echo "Installing SphinxPi $NEW_VERSION..."
sh "$WORK/source/scripts/build-deb.sh"
PACKAGE="$WORK/source/dist/sphinxpi_${NEW_VERSION}_all.deb"

if [ ! -f "$PACKAGE" ]; then
    echo "Package build did not produce the expected file: $PACKAGE" >&2
    exit 1
fi

# Refresh package indexes before changing the installed package or its tools.
apt-get update
apt-get install -y "$PACKAGE"

echo
echo "Installing SphinxPi Archive Manager dependencies..."
ARCHIVE_PACKAGES="whiptail zip unzip 7zip tar gzip bzip2 zstd lz4"
RAR_CANDIDATE=$(apt-cache policy 7zip-rar 2>/dev/null | awk '$1 == "Candidate:" {print $2}')
if [ -n "$RAR_CANDIDATE" ] && [ "$RAR_CANDIDATE" != "(none)" ]; then
    ARCHIVE_PACKAGES="$ARCHIVE_PACKAGES 7zip-rar"
    echo "RAR extraction plugin is available and will be installed."
else
    echo "RAR extraction plugin is unavailable in the configured APT repositories; other formats will still work."
fi
# Record only packages that this install will add, so full removal does not
# purge tools that were already installed or needed by other software.
sh /usr/lib/sphinxpi/track-install.sh $ARCHIVE_PACKAGES
apt-get install -y --no-install-recommends $ARCHIVE_PACKAGES

echo
echo "SphinxPi update finished. Installed version:"
sphinx version
