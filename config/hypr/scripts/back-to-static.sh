#!/bin/bash
# Cortar el wallpaper de vídeo y volver al selector estático
pkill mpvpaper 2>/dev/null || true
exec "$HOME/.config/hypr/scripts/wallpapers/set-wallpaper.sh"
