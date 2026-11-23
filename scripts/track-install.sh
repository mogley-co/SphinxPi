#!/bin/sh
set -eu
[ "$(id -u)" -eq 0 ] || exit 1
mkdir -p /var/lib/sphinxpi
manifest=/var/lib/sphinxpi/apt-packages
touch "$manifest"
# Simulate the exact install so newly required dependencies are tracked too.
apt-get --simulate install --no-install-recommends "$@" | awk '$1 == "Inst" { print $2 }' | while IFS= read -r package; do
 status=$(dpkg-query -W -f='${db:Status-Status}' "$package" 2>/dev/null || true)
 if [ "$status" != installed ] && ! grep -Fxq "$package" "$manifest"; then printf '%s\n' "$package" >> "$manifest"; fi
done
