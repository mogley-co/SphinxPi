#!/bin/sh
# SphinxPi platform gate: Debian 13 (Trixie) or newer, including Debian-based
# Raspberry Pi OS releases. This checks OS family/version, not CPU architecture.
set -eu

if [ ! -r /etc/os-release ]; then
    echo "Cannot identify this operating system. SphinxPi requires Debian 13 (Trixie) or newer." >&2
    exit 1
fi

. /etc/os-release
case "${ID:-}" in
    debian|raspbian|raspios) ;;
    *)
        echo "Unsupported operating system: ${PRETTY_NAME:-unknown}" >&2
        echo "SphinxPi requires Debian 13 (Trixie) or newer, or a Debian-based Raspberry Pi OS release." >&2
        exit 1
        ;;
esac

version_major=$(printf '%s' "${VERSION_ID:-0}" | sed 's/[^0-9].*//')
case "$version_major" in
    ''|*[!0-9]*)
        echo "Could not determine the Debian release version: ${VERSION_ID:-unknown}" >&2
        exit 1
        ;;
esac

if [ "$version_major" -lt 13 ]; then
    echo "Unsupported Debian release: ${PRETTY_NAME:-unknown}" >&2
    echo "SphinxPi requires Debian 13 (Trixie) or newer." >&2
    exit 1
fi

for command_name in dpkg apt-get apt-cache; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "Required Debian package tool is missing: $command_name" >&2
        exit 1
    fi
done

exit 0
