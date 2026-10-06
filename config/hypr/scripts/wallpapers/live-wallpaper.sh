#!/bin/bash
# Wallpaper animado (.mp4) con mpvpaper + extracción de paleta del vídeo
# (estilo LeyzS, adaptado: monitores detectados dinámicamente)
set -eu

WALL_DIR="$HOME/Videos/LiveWallpapers"
TEMP_THUMB="${XDG_RUNTIME_DIR:-/tmp}/wall_thumb.png"

command -v mpvpaper >/dev/null 2>&1 || { notify-send "Live Wallpaper" "Instala mpvpaper primero (paru -S mpvpaper)"; exit 1; }
mkdir -p "$WALL_DIR"

choice=$(find "$WALL_DIR" -maxdepth 1 -type f \( -iname "*.mp4" -o -iname "*.webm" -o -iname "*.mkv" \) -printf "%f\n" | sort | wofi --dmenu --style "$HOME/.config/wofi/style.css" --prompt "Live Wallpaper")
[ -z "$choice" ] && exit 1
VIDEO_PATH="$WALL_DIR/$choice"

# Congelar el primer frame con awww/swww para evitar pantallazo negro
ffmpeg -y -i "$VIDEO_PATH" -vframes 1 -f image2 -update 1 "$TEMP_THUMB" >/dev/null 2>&1
if command -v swww >/dev/null 2>&1; then swww img "$TEMP_THUMB" --transition-type fade --transition-step 255 --transition-fps 60
elif command -v awww >/dev/null 2>&1; then awww img "$TEMP_THUMB" --transition-type fade --transition-step 255 --transition-fps 60; fi

pkill mpvpaper 2>/dev/null || true
# Un mpvpaper por monitor conectado
for MON in $(hyprctl monitors -j | python3 -c "import json,sys;[print(m['name']) for m in json.load(sys.stdin)]"); do
    mpvpaper -o "--loop --hwdec=auto-safe --no-audio --panscan=1.0" "$MON" "$VIDEO_PATH" &
done

(
    command -v swaync-client >/dev/null 2>&1 && swaync-client -R && swaync-client -rs || true
    sleep 0.8
    if command -v wal >/dev/null 2>&1; then
        wal -i "$TEMP_THUMB" -n -q -t -e
        cp "$TEMP_THUMB" "$HOME/.cache/current_wallpaper.png"
    fi
    pkill -USR2 -x waybar 2>/dev/null || true
    hyprctl reload >/dev/null 2>&1 || true
    command -v swaync-client >/dev/null 2>&1 && swaync-client -R && swaync-client -rs || true
) &
