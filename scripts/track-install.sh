#!/bin/sh
set -eu
[ "$(id -u)" -eq 0 ] || exit 1
mkdir -p /var/lib/sphinxpi
manifest=/var/lib/sphinxpi/apt-packages
touch "$manifest"
for package in "$@"; do
 status=$(dpkg-query -W -f='${db:Status-Status}' "$package" 2>/dev/null || true)
 if [ "$status" != installed ] && ! grep -Fxq "$package" "$manifest"; then printf '%s\n' "$package" >> "$manifest"; fi
done
