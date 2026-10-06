#!/bin/sh
# =============================================================
# window-switcher.sh — Alt-Tab para Hyprland
# Muestra ventanas del workspace actual en wofi y enfoca la elegida
# Reemplaza: alt + Tab (bspwm: rofi window switcher)
# =============================================================

WOFI_STYLE="$HOME/.config/wofi/style.css"

# Map address -> "class — title"
LIST=$(hyprctl clients -j 2>/dev/null \
    | jq -r '.[] | "\(.address)\t\(.class) — \(.title)"')

[ -z "$LIST" ] && exit 0

# Mostrar con icon y permitir buscar por clase/título
SELECTED=$(printf "%s\n" "$LIST" | cut -f2- \
    | wofi --dmenu \
           --prompt "Window" \
           --style "$WOFI_STYLE" \
           --insensitive 2>/dev/null)

[ -z "$SELECTED" ] && exit 0

# Encontrar el address de la línea seleccionada
TARGET=$(printf "%s\n" "$LIST" | cut -f2- | grep -F -m1 -n "$SELECTED" | cut -d: -f1)
[ -z "$TARGET" ] && exit 0

ADDR=$(printf "%s\n" "$LIST" | sed -n "${TARGET}p" | cut -f1)
[ -n "$ADDR" ] && hyprctl dispatch focuswindow "address:$ADDR"
