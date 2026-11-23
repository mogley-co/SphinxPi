#!/bin/sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
    echo "Uninstall requires root privileges."
    echo "On DietPi, while logged in as root, run: sh scripts/uninstall.sh"
    echo "From a normal user account, run: sudo sh scripts/uninstall.sh"
    exit 1
fi

case "${1:-}" in
    "") ;;
    --yes) ;;
    *) echo "Usage: sh scripts/uninstall.sh [--yes]"; exit 2 ;;
esac

if [ "${1:-}" != "--yes" ]; then
    echo "This removes only SphinxPi-managed files:"
    echo "  /usr/local/bin/sphinx and its installer backups"
    echo "  /usr/lib/sphinxpi"
    echo "  /etc/sphinxpi"
    echo
    echo "It does NOT remove LXDE, Xorg, archive utilities, user files,"
    echo "your home directory, boot files, kernel, firmware or partitions."
    printf "Continue? [y/N] "
    IFS= read -r answer || answer=""
    case "$answer" in
        y|Y|yes|YES) ;;
        *) echo "Cancelled. Nothing removed."; exit 0 ;;
    esac
fi

rm -f -- /usr/local/bin/sphinx
rm -f -- /usr/local/bin/sphinx.backup.*
rm -rf -- /usr/lib/sphinxpi
rm -rf -- /etc/sphinxpi

echo "SphinxPi command, helpers and configuration removed."
echo "Optional desktop and archive packages were left installed."
