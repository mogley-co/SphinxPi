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
for helper in desktop-install.sh desktop-layout.sh archive-install.sh archive-manager.sh update.sh; do
    install -m 0755 "$ROOT/scripts/$helper" "$PKGROOT/usr/lib/sphinxpi/$helper"
done
install -m 0644 "$ROOT/VERSION" "$PKGROOT/usr/share/sphinxpi/version"

cat > "$PKGROOT/DEBIAN/preinst" <<'EOF'
#!/bin/sh
set -e
case "${1:-}" in
    install|upgrade)
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
 A small Debian package providing the SphinxPi command and optional
 installers for a lightweight LXDE desktop and archive utilities.
EOF

mkdir -p "$OUT"
OUTPUT="$OUT/${PACKAGE}_${VERSION}_${ARCH}.deb"
dpkg-deb --build --root-owner-group "$PKGROOT" "$OUTPUT"
echo
echo "Built: $OUTPUT"
echo "Install with: sudo apt install '$OUTPUT'"
