#!/bin/sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this command as root, or use: sudo sphinx desktop-install"
    exit 1
fi

sh /usr/lib/sphinxpi/platform-check.sh
ARCH=$(dpkg --print-architecture)

FREE_KB=$(df -Pk / | awk 'NR==2 {print $4}')
if [ -z "$FREE_KB" ] || [ "$FREE_KB" -lt 1200000 ]; then
    echo "At least 1.2 GB of free space is required. Nothing changed."
    df -h /
    exit 1
fi

PACKAGES="xserver-xorg xinit dbus-x11 lxde-core lxterminal lxappearance lxtask lxrandr fonts-dejavu adwaita-icon-theme"

echo "SphinxPi lightweight LXDE desktop profile"
echo "Detected Debian architecture: $ARCH"
echo "This installs Xorg, Xinit, LXDE core and lightweight utilities."
echo "It will NOT enable automatic graphical login or change the default boot target."
echo "Network configuration is left untouched."
echo "Desktop performance depends on your hardware and available RAM."
printf "Continue? [y/N] "
read answer
case "$answer" in
    y|Y|yes|YES) ;;
    *) echo "Cancelled. Nothing installed."; exit 0 ;;
esac

export DEBIAN_FRONTEND=noninteractive
apt-get update

missing=""
for package in $PACKAGES; do
    candidate=$(apt-cache policy "$package" 2>/dev/null | awk '$1 == "Candidate:" {print $2}')
    if [ -z "$candidate" ] || [ "$candidate" = "(none)" ]; then
        missing="$missing $package"
    fi
done

if [ -n "$missing" ]; then
    echo "The desktop profile cannot be installed completely on architecture $ARCH."
    echo "Packages without an APT candidate:$missing"
    echo "Nothing has been installed."
    exit 1
fi

sh /usr/lib/sphinxpi/track-install.sh $PACKAGES
apt-get install -y --no-install-recommends $PACKAGES

echo
echo "Lightweight LXDE desktop packages installed."
echo "No display manager, automatic login, boot target or network settings were changed."
echo "Log in as a normal non-root account, then run: sphinx desktop"
