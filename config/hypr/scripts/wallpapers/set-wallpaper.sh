#!/bin/bash
# Selector de wallpaper estático (estilo LeyzS, adaptado)
# wofi para elegir + awww/swww para aplicar + pywal para sincronizar colores
set -eu

WALL_DIR="$HOME/Pictures/wallpapers"

# Detectar daemon de wallpaper (awww es el fork empaquetado en Arch)
if command -v swww >/dev/null 2>&1; then SWWW=swww
elif command -v awww >/dev/null 2>&1; then SWWW=awww
else notify-send "Wallpaper" "No hay swww/awww instalado"; exit 1; fi

FILE_LIST=$(find "$WALL_DIR" -maxdepth 1 -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" \) -printf "%f\n" | sort)
SELECTED_FILE=$(echo "$FILE_LIST" | wofi --dmenu --style "$HOME/.config/wofi/style.css" --prompt "Wallpaper")

pkill mpvpaper 2>/dev/null || true
[ -z "$SELECTED_FILE" ] && exit 1
WALL="$WALL_DIR/$SELECTED_FILE"

$SWWW img "$WALL" --transition-type fade --transition-step 255 --transition-fps 60 --transition-duration 0.70

# Sincronización de colores en segundo plano
(
    command -v swaync-client >/dev/null 2>&1 && swaync-client -R && swaync-client -rs || true

    if command -v wal >/dev/null 2>&1; then
        wal -i "$WALL" -n -q -t -e
        cp "$WALL" "$HOME/.cache/current_wallpaper.png"
    fi
    # Persistencia usada por wallpaper.sh en el autostart
    echo "$WALL" > "$HOME/.cache/current_wallpaper"

    # Recargar UI con la nueva paleta
    pkill -USR2 -x waybar 2>/dev/null || true
    hyprctl reload >/dev/null 2>&1 || true
    command -v swaync-client >/dev/null 2>&1 && swaync-client -R && swaync-client -rs || true
) &
