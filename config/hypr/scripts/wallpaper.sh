#!/bin/sh
# =============================================================
# wallpaper.sh — Aplica wallpaper actual con swww/awww
# Lee del rice emilia (o el rice activo) o usa el último set
# =============================================================

# Lee el rice activo (hyprland primary, bspwm fallback)
if [ -f "$HOME/.config/hypr/.rice" ]; then
    RICE=$(cat "$HOME/.config/hypr/.rice" 2>/dev/null)
    WALL_DIR="$HOME/.config/hypr/rices/$RICE/walls"
else
    RICE=$(cat "$HOME/.config/bspwm/.rice" 2>/dev/null)
    WALL_DIR="$HOME/.config/bspwm/rices/$RICE/walls"
fi
PERSISTENT_WALL="$HOME/.cache/current_wallpaper"

# Detectar comando (swww o awww según repo)
if command -v swww >/dev/null 2>&1; then
    SWWW="swww"
elif command -v awww >/dev/null 2>&1; then
    SWWW="awww"
else
    echo "No swww/awww found, wallpaper no se aplicará"
    exit 1
fi

# Espera a que el daemon esté listo (puede tardar 1-2s en Wayland)
for i in 1 2 3 4 5 6 7 8 9 10; do
    if $SWWW query >/dev/null 2>&1; then
        break
    fi
    sleep 0.5
done

# Decide qué wallpaper usar
if [ -f "$PERSISTENT_WALL" ]; then
    WALLPAPER=$(cat "$PERSISTENT_WALL")
elif [ -d "$WALL_DIR" ] && [ -n "$(ls -A "$WALL_DIR" 2>/dev/null)" ]; then
    WALLPAPER=$(find "$WALL_DIR" -type f | shuf -n 1)
else
    WALLPAPER=$(find "$HOME/Pictures/wallpapers" -type f 2>/dev/null | shuf -n 1)
fi

if [ -n "$WALLPAPER" ] && [ -f "$WALLPAPER" ]; then
    $SWWW img "$WALLPAPER" \
        --transition-type grow \
        --transition-pos center \
        --transition-step 90 \
        --transition-fps 60 \
        --transition-duration 1 \
        --transition-bezier 0.23,1,0.32,1

    echo "$WALLPAPER" > "$PERSISTENT_WALL"
fi
