#!/bin/bash
# =============================================================
# workspace-picker.sh — Selector visual de workspaces (wofi)
# Click en el módulo pacman del waybar → abre este picker
# Lista workspaces 1-10, marca el activo, cambia al seleccionado
# =============================================================

WOFI_STYLE="$HOME/.config/wofi/style.css"

ACTIVE_ID=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id // empty')
ACTIVE_MON=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.monitor // empty')
WS_JSON=$(hyprctl workspaces -j 2>/dev/null)

# Iconos
I_PAC="󰮯"   # pacman
I_OCC="󰊠"   # fantasma
I_EMP="󰑊"   # punto

# Construye la lista: "icono+ID   monitor   ventanas"
list=""
for id in 1 2 3 4 5 6 7 8 9 10; do
    WS=$(echo "$WS_JSON" | jq -c --argjson id "$id" '.[] | select(.id == $id)' 2>/dev/null)
    ws_mon=$(echo "$WS" | jq -r '.monitor // empty')
    win_count=$(echo "$WS" | jq -r '.windows // 0')

    if [ -z "$ws_mon" ]; then
        [ "$id" -le 5 ] && ws_mon="eDP-1" || ws_mon="HDMI-A-1"
        win_count=0
    fi

    if [ "$id" = "$ACTIVE_ID" ]; then
        icon="$I_PAC"
    elif [ "$win_count" -gt 0 ]; then
        icon="$I_OCC"
    else
        icon="$I_EMP"
    fi

    marker=" "
    [ "$id" = "$ACTIVE_ID" ] && marker="▶"

    list+="${icon}  ${id}  ${marker}  ${ws_mon}  (${win_count})\n"
done

# Muestra wofi y captura selección
SELECTED=$(printf "%b" "$list" | wofi --dmenu \
    --prompt "Workspace" \
    --style "$WOFI_STYLE" \
    --width 320 \
    --lines 10 2>/dev/null)

[ -z "$SELECTED" ] && exit 0

# Extrae el número de workspace (segundo campo)
TARGET_ID=$(echo "$SELECTED" | awk '{print $2}')
[ -n "$TARGET_ID" ] && hyprctl dispatch workspace "$TARGET_ID" >/dev/null 2>&1
