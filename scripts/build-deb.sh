#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
VERSION=$(cat "$ROOT/VERSION")
PACKAGE="sphinxpi"
ARCH="all"
OUT="$ROOT/dist"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/sphinxpi-package.XXXXXX")
trap 'rm -rf "$WORK"' EXIT HUP INT TERM

command -v dpkg-deb >/dev/null 2>&1 || {
    echo "dpkg-deb is required. Install it with: sudo apt install dpkg"
    exit 1
}

PKGROOT="$WORK/$PACKAGE"
mkdir -p "$PKGROOT/DEBIAN" "$PKGROOT/usr/bin" "$PKGROOT/usr/lib/sphinxpi" "$PKGROOT/usr/share/sphinxpi"

install -m 0755 "$ROOT/src/sphinx" "$PKGROOT/usr/bin/sphinx"
for helper in platform-check.sh desktop-install.sh desktop-layout.sh archive-install.sh archive-manager.sh dev-manager.sh system-manager.sh update.sh track-install.sh remove.sh; do
    install -m 0755 "$ROOT/scripts/$helper" "$PKGROOT/usr/lib/sphinxpi/$helper"
done
install -m 0644 "$ROOT/VERSION" "$PKGROOT/usr/share/sphinxpi/version"
install -m 0644 "$ROOT/data/apps.tsv" "$PKGROOT/usr/share/sphinxpi/apps.tsv"

cat > "$PKGROOT/DEBIAN/preinst" <<'EOF'
#!/bin/sh
set -e
case "${1:-}" in
    install|upgrade)
        # Enforce Debian 13 (Trixie) or newer, including Raspberry Pi OS.
        if [ -r /etc/os-release ]; then
            . /etc/os-release
            case "${ID:-}" in debian|raspbian|raspios) ;; *) echo "SphinxPi requires Debian 13+ or Debian-based Raspberry Pi OS." >&2; exit 1 ;; esac
            major=$(printf '%s' "${VERSION_ID:-0}" | sed 's/[^0-9].*//')
            case "$major" in ''|*[!0-9]*) echo "Cannot determine Debian release version." >&2; exit 1 ;; esac
            [ "$major" -ge 13 ] || { echo "SphinxPi requires Debian 13 (Trixie) or newer." >&2; exit 1; }
        else
            echo "Cannot identify operating system; SphinxPi requires Debian 13+." >&2
            exit 1
        fi
        # Remove the legacy command so /usr/local/bin cannot shadow the
        # Debian-managed /usr/bin/sphinx command.
        rm -f /usr/local/bin/sphinx
        rm -f /usr/lib/sphinxpi/uninstall.sh
        rm -rf /etc/sphinxpi
        ;;
esac
exit 0
EOF
chmod 0755 "$PKGROOT/DEBIAN/preinst"

cat > "$PKGROOT/DEBIAN/control" <<EOF
Package: sphinxpi
Version: $VERSION
Section: utils
Priority: optional
Architecture: $ARCH
Maintainer: Mogley <mogley@example.invalid>
Description: Lightweight command-line tools for SphinxPi
 A small Debian package providing SphinxPi system tools, an interactive
 development manager, a lightweight LXDE installer and archive utilities.
EOF

mkdir -p "$OUT"
OUTPUT="$OUT/${PACKAGE}_${VERSION}_${ARCH}.deb"
dpkg-deb --build --root-owner-group "$PKGROOT" "$OUTPUT"
echo
echo "Built: $OUTPUT"
echo "Install with: sudo apt install '$OUTPUT'"
