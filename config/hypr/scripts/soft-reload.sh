#!/bin/sh
# =============================================================
# Soft reload — Recarga todo: hyprland + waybar + mako
# Reemplaza: super + Escape (bspwm: pkill -USR1 sxhkd) +
#            ctrl + super + alt + s (bspwm: SoftReload)
# =============================================================

hyprctl reload
sleep 0.3
pkill -SIGUSR2 waybar 2>/dev/null
sleep 0.5
pkill -SIGUSR2 waybar 2>/dev/null
makoctl reload 2>/dev/null
notify-send -u low "Hyprland" "Recargado" 2>/dev/null
