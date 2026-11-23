#!/bin/sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
    echo "Run with sudo: sudo sphinx archive-install"
    exit 1
fi

echo "SphinxPi Archive Manager installer"
echo "This installs whiptail (terminal menus), ZIP tools and 7-Zip."
echo "It does not change boot, kernel, firmware, partitions or network settings."
printf "Continue? [y/N] "
read answer
case "$answer" in
    y|Y|yes|YES) ;;
    *) echo "Cancelled. Nothing installed."; exit 0 ;;
esac

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install --no-install-recommends whiptail zip unzip 7zip

echo
echo "Archive tools installed."
echo "Run 'sphinx archive' as your normal user."
