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

BACKUP="$PANEL_FILE.sphinx-backup.$(date +%Y%m%d%H%M%S)"
cp -p "$PANEL_FILE" "$BACKUP"

# Change only existing geometry settings; preserve the user's plugin layout.
if grep -q '^ *edge=' "$PANEL_FILE"; then
    sed -i 's/^ *edge=.*/edge=top/' "$PANEL_FILE"
else
    printf '\nedge=top\n' >> "$PANEL_FILE"
fi
if grep -q '^ *widthtype=' "$PANEL_FILE"; then
    sed -i 's/^ *widthtype=.*/widthtype=percent/' "$PANEL_FILE"
else
    printf 'widthtype=percent\n' >> "$PANEL_FILE"
fi
if grep -q '^ *width=' "$PANEL_FILE"; then
    sed -i 's/^ *width=.*/width=100/' "$PANEL_FILE"
else
    printf 'width=100\n' >> "$PANEL_FILE"
fi
if grep -q '^ *height=' "$PANEL_FILE"; then
    sed -i 's/^ *height=.*/height=28/' "$PANEL_FILE"
else
    printf 'height=28\n' >> "$PANEL_FILE"
fi

if command -v lxpanelctl >/dev/null 2>&1; then
    lxpanelctl restart || true
fi

echo "Set the LXPanel edge to the top and width to 100%."
echo "Previous configuration backed up to: $BACKUP"
