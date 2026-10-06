#!/bin/sh
# =============================================================
# close-workspace.sh — Cierra todas las ventanas del workspace actual
# Reemplaza: super + ctrl + x (bspwm: bspc query -N -d | xargs ... close)
# =============================================================

WS_ID=$(hyprctl activeworkspace -j | jq -r '.id')
ADDRS=$(hyprctl clients -j | jq -r ".[] | select(.workspace.id == $WS_ID) | .address")
HAS_WD=$(hyprctl clients -j | jq -r "[.[] | select(.workspace.id == $WS_ID and .class == \"Waydroid\")] | length")

# Waydroid: window.close crashea el hwcomposer, se detiene con session stop
[ "$HAS_WD" != "0" ] && waydroid session stop

for addr in $ADDRS; do
    hyprctl dispatch "hl.dsp.window.close(\"address:$addr\")" 2>/dev/null
done