#!/bin/sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
    echo "Run with sudo: sudo sphinx desktop-install"
    exit 1
fi

if [ ! -r /etc/os-release ]; then
    echo "Cannot identify the operating system. Nothing changed."
    exit 1
fi
. /etc/os-release

if [ "${VERSION_CODENAME:-}" != "trixie" ]; then
    echo "This desktop profile is currently prepared for Debian Trixie."
    echo "Detected: ${PRETTY_NAME:-unknown}"
    exit 1
fi

ARCH=$(dpkg --print-architecture)
case "$ARCH" in
    armel|armhf) ;;
    *) echo "Unsupported Debian architecture: $ARCH"; exit 1 ;;
esac

FREE_KB=$(df -Pk / | awk 'NR==2 {print $4}')
if [ -z "$FREE_KB" ] || [ "$FREE_KB" -lt 1200000 ]; then
    echo "At least 1.2 GB of free space is required. Nothing changed."
    df -h /
    exit 1
fi

echo "SphinxPi lightweight desktop profile"
echo "Desktop: LXDE core (Openbox, LXPanel and PCManFM)"
echo "Architecture: $ARCH"
echo "This installs Xorg, Xinit, LXDE core and lightweight utilities."
echo "It will NOT enable automatic graphical login or change the default boot target."
echo "Network configuration is left untouched to protect your existing Wi-Fi connection."
echo "The original Pi Zero W has limited RAM and CPU; avoid running many apps together."
printf "Continue? [y/N] "
read answer
case "$answer" in
    y|Y|yes|YES) ;;
    *) echo "Cancelled. Nothing installed."; exit 0 ;;
esac

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install --no-install-recommends \
    xserver-xorg \
    xinit \
    dbus-x11 \
    lxde-core \
    lxterminal \
    lxappearance \
    lxtask \
    lxrandr \
    fonts-dejavu \
    adwaita-icon-theme

echo
echo "Lightweight LXDE desktop packages installed."
echo "No display manager, automatic login, boot target or network settings were changed."
echo "Create/use a normal non-root account, log in as that account, then run: sphinx desktop"
