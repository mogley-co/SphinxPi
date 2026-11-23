#!/bin/sh
set -eu

if [ -z "${DISPLAY:-}" ]; then
    echo "Run this from inside an LXDE graphical session."
    exit 1
fi

PANEL_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/lxpanel/LXDE/panels/panel"
if [ ! -f "$PANEL_FILE" ]; then
    echo "LXPanel configuration was not found:"
    echo "  $PANEL_FILE"
    echo "Start the LXDE session once, then run this command again."
    exit 1
fi

if ! grep -q '^[[:space:]]*Global[[:space:]]*{' "$PANEL_FILE"; then
    echo "The panel file has no LXPanel Global section. Nothing changed."
    exit 1
fi

BACKUP="$PANEL_FILE.sphinx-backup.$(date +%Y%m%d%H%M%S)"
TMP=$(mktemp "${PANEL_FILE}.sphinx.XXXXXX")
cp -p "$PANEL_FILE" "$BACKUP"

if ! awk '
function add_missing() {
    if (!seen_edge) print "  edge=top"
    if (!seen_widthtype) print "  widthtype=percent"
    if (!seen_width) print "  width=100"
    if (!seen_height) print "  height=28"
}
BEGIN { in_global=0; done_global=0 }
/^[[:space:]]*Global[[:space:]]*\{/ && !done_global {
    in_global=1
    done_global=1
    print
    next
}
in_global && /^[[:space:]]*\}/ {
    add_missing()
    in_global=0
    print
    next
}
in_global && /^[[:space:]]*edge=/ {
    sub(/edge=.*/, "edge=top")
    seen_edge=1
}
in_global && /^[[:space:]]*widthtype=/ {
    sub(/widthtype=.*/, "widthtype=percent")
    seen_widthtype=1
}
in_global && /^[[:space:]]*width=/ {
    sub(/width=.*/, "width=100")
    seen_width=1
}
in_global && /^[[:space:]]*height=/ {
    sub(/height=.*/, "height=28")
    seen_height=1
}
{ print }
END {
    if (in_global) add_missing()
    if (!done_global) exit 2
}
' "$PANEL_FILE" > "$TMP"; then
    rm -f "$TMP"
    echo "Could not safely update the LXPanel Global section. Original file was preserved."
    exit 1
fi

cat "$TMP" > "$PANEL_FILE"
rm -f "$TMP"

if command -v lxpanelctl >/dev/null 2>&1; then
    lxpanelctl restart || true
fi

echo "Set the LXPanel edge to the top and width to 100%."
echo "Previous configuration backed up to: $BACKUP"
