#!/bin/bash
# Wallpaper aleatorio + sincronización global de colores (estilo LeyzS, adaptado)
set -eu

WALL_DIR="$HOME/Pictures/wallpapers"

if command -v swww >/dev/null 2>&1; then SWWW=swww
elif command -v awww >/dev/null 2>&1; then SWWW=awww
else notify-send "Wallpaper" "No hay swww/awww instalado"; exit 1; fi

SELECTED_FILE=$(find "$WALL_DIR" -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" \) | shuf -n 1)

pkill mpvpaper 2>/dev/null || true
[ -z "$SELECTED_FILE" ] && exit 1
WALL="$SELECTED_FILE"

$SWWW img "$WALL" --transition-type fade --transition-step 255 --transition-fps 60 --transition-duration 0.70

(
    command -v swaync-client >/dev/null 2>&1 && swaync-client -R && swaync-client -rs || true

    if command -v wal >/dev/null 2>&1; then
        wal -i "$WALL" -n -q -t -e
        cp "$WALL" "$HOME/.cache/current_wallpaper.png"
    fi
    echo "$WALL" > "$HOME/.cache/current_wallpaper"

    pkill -USR2 -x waybar 2>/dev/null || true
    hyprctl reload >/dev/null 2>&1 || true
    command -v swaync-client >/dev/null 2>&1 && swaync-client -R && swaync-client -rs || true
) &
