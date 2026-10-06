#!/bin/sh
# =============================================================
# rotate.sh — Alterna split horizontal/vertical en dwindle
# Reemplaza: ctrl + Tab (bspwm: bspc node @/ --rotate)
# =============================================================

# togglesplit: dwindle alterna entre hsplit y vsplit
hyprctl dispatch togglesplit
