#!/bin/sh
# =============================================================
# Reset opacity / restart shader — placeholder para picom-trans
# Reemplaza: ctrl + alt + {plus,minus,t} (bspwm: picom-trans)
# Nota: Hyprland no usa picom, blur/opacity son nativos
# =============================================================

case "$1" in
    +|-)
        # En Hyprland no se ajusta opacidad por ventana en vivo sin reglas
        # Se notifica al usuario
        notify-send -u low "Hyprland" "Opacidad: usar 'hyprctl dispatch setopacity' o windowrule"
        ;;
    d)
        # Reset
        notify-send -u low "Hyprland" "Opacidad reseteada (default)"
        ;;
esac
