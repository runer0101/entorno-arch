#!/bin/sh
# =============================================================
# close-others.sh — Cierra todas las ventanas EXCEPTO la enfocada
# Reemplaza: super + n ; x (bspwm: close unfocused)
# =============================================================

ACTIVE=$(hyprctl activewindow -j | jq -r '.address // empty')
WS_ID=$(hyprctl activeworkspace -j | jq -r '.id')
ADDRS=$(hyprctl clients -j | jq -r ".[] | select(.workspace.id == $WS_ID) | .address")
HAS_WD=$(hyprctl clients -j | jq -r "[.[] | select(.workspace.id == $WS_ID and .class == \"Waydroid\" and .address != \"$ACTIVE\")] | length")

# Waydroid: window.close crashea el hwcomposer, se detiene con session stop
[ "$HAS_WD" != "0" ] && waydroid session stop

for addr in $ADDRS; do
    [ "$addr" = "$ACTIVE" ] && continue
    hyprctl dispatch "hl.dsp.window.close(\"address:$addr\")" 2>/dev/null
done