#!/bin/bash
# Toggle del shader vibrance (estilo LeyzS): activa/desactiva saturación extra
CURRENT=$(hyprctl getoption decoration:screen_shader -j 2>/dev/null | grep -o 'vibrance' | head -1)
if [ "${1:-}" = "off" ] || [ -n "$CURRENT" ]; then
    hyprctl eval "hl.config({ decoration = { screen_shader = \"$HOME/.config/hypr/shaders/off.glsl\" } })"
else
    hyprctl eval "hl.config({ decoration = { screen_shader = \"$HOME/.config/hypr/shaders/vibrance.glsl\" } })"
fi
