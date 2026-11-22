#!/bin/sh
set -eu

if [ -z "${DISPLAY:-}" ]; then
    echo "Run this from inside an XFCE graphical session."
    exit 1
fi
if ! command -v xfconf-query >/dev/null 2>&1; then
    echo "xfconf-query is missing. Is XFCE installed?"
    exit 1
fi

PANEL=""
for candidate in 1 2 0; do
    if xfconf-query -c xfce4-panel -p "/panels/panel-$candidate/position" >/dev/null 2>&1; then
        PANEL="panel-$candidate"
        break
    fi
done

if [ -z "$PANEL" ]; then
    echo "Could not find an existing XFCE panel. No settings changed."
    exit 1
fi

xfconf-query -c xfce4-panel -p "/panels/$PANEL/position" --create -t string -s "p=6;x=0;y=0"
xfconf-query -c xfce4-panel -p "/panels/$PANEL/position-locked" --create -t bool -s true
xfconf-query -c xfce4-panel -p "/panels/$PANEL/size" --create -t uint -s 28
xfce4-panel -r
echo "Moved $PANEL to the top edge."
