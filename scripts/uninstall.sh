#!/bin/sh
set -eu
if [ "$(id -u)" -eq 0 ]; then
    exec apt-get remove sphinxpi
elif command -v sudo >/dev/null 2>&1; then
    exec sudo apt-get remove sphinxpi
else
    echo "Use Debian's package manager as root: apt-get remove sphinxpi" >&2
    exit 1
fi
