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
    *)
        echo "Unsupported Debian architecture: $ARCH"
        exit 1
        ;;
esac

FREE_KB=$(df -Pk / | awk 'NR==2 {print $4}')
if [ -z "$FREE_KB" ] || [ "$FREE_KB" -lt 1800000 ]; then
    echo "At least 1.8 GB of free space is required. Nothing changed."
    df -h /
    exit 1
fi

echo "SphinxPi XFCE desktop profile"
echo "Architecture: $ARCH"
echo "This will install XFCE, Xorg, LightDM components and desktop utilities."
echo "It will NOT enable automatic graphical login or change the default boot target."
echo "The Pi Zero W may feel slow with a full desktop."
printf "Continue? [y/N] "
read answer
case "$answer" in
    y|Y|yes|YES) ;;
    *) echo "Cancelled. Nothing installed."; exit 0 ;;
esac

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install --no-install-recommends     xserver-xorg     xinit     dbus-x11     xfce4     xfce4-goodies     lightdm     thunar     thunar-volman     file-roller     xfce4-terminal     mousepad     ristretto     pavucontrol     network-manager-gnome     xfce4-pulseaudio-plugin     xfce4-whiskermenu-plugin     xfce4-taskmanager     xfce4-screenshooter     fonts-dejavu     adwaita-icon-theme

echo
echo "XFCE desktop packages installed."
echo "The existing text login and boot target were left unchanged."
echo "Log in as your normal user, then run: sphinx desktop"
