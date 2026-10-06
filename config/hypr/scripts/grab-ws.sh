#!/bin/sh
# =============================================================
# grab-ws.sh — Trae TODAS las ventanas del workspace N al actual
# Uso: grab-ws.sh <n>
# Reemplaza: super + n ; {1-9} (bspwm: bring everything from desktop X)
# =============================================================

N="$1"
[ -z "$N" ] && exit 1

# hyprctl clients -j entrega una lista JSON; iteramos por address.
# Solo movemos ventanas de workspaces != current.
hyprctl clients -j 2>/dev/null \
    | jq -r --argjson n "$N" '.[] | select(.workspace.id == $n) | .address' \
    | while read -r addr; do
        [ -n "$addr" ] && hyprctl dispatch movetoworkspacesilent "address:$addr,current" >/dev/null 2>&1
    done
