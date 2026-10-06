#!/bin/sh
# =============================================================
# kill-others.sh — Mata (force close) todas EXCEPTO la enfocada
# Reemplaza: super + n ; k (bspwm: kill unfocused)
# =============================================================

ACTIVE=$(hyprctl activewindow -j | jq -r '.address // empty')
WS_ID=$(hyprctl activeworkspace -j | jq -r '.id')
ADDRS=$(hyprctl clients -j | jq -r ".[] | select(.workspace.id == $WS_ID) | .address")

for addr in $ADDRS; do
    [ "$addr" = "$ACTIVE" ] && continue
    hyprctl dispatch killwindow "address:$addr" 2>/dev/null
done
