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

BASE="/panels/$PANEL"
xfconf-query -c xfce4-panel -p "$BASE/position" --create -t string -s "p=6;x=0;y=0"
xfconf-query -c xfce4-panel -p "$BASE/position-locked" --create -t bool -s true
xfconf-query -c xfce4-panel -p "$BASE/size" --create -t uint -s 28
xfconf-query -c xfce4-panel -p "$BASE/length" --create -t uint -s 100
xfconf-query -c xfce4-panel -p "$BASE/length-adjust" --create -t bool -s false
xfce4-panel -r
echo "Moved $PANEL to the top edge and set it to full width."
