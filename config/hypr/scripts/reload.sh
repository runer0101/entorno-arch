#!/bin/sh
# =============================================================
# reload.sh — Recarga Hyprland + waybar + mako
# =============================================================

# Recargar config de Hyprland
hyprctl reload
sleep 0.3

# Recargar waybar (dos señales con espera, el reinit del módulo
# hyprland/workspaces puede dejar la barra sin pintar tras la primera)
pkill -SIGUSR2 waybar
sleep 0.5
pkill -SIGUSR2 waybar

# Recargar mako y notificar (orden correcto: mako primero, luego notify)
makoctl reload 2>/dev/null
notify-send -u low "Hyprland" "Recargado" 2>/dev/null
