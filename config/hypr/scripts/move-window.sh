#!/bin/bash
# ALT+arrows: mueve la ventana activa ±20px. Si esta tiled la flota primero
# (move solo afecta flotantes en Hyprland). Volver a tiled con ALT+T.
if ! hyprctl activewindow -j | grep -q '"floating": true'; then
    hyprctl eval 'hl.dispatch(hl.dsp.window.float({action="on"}))'
fi
hyprctl eval "hl.dispatch(hl.dsp.window.move({x=$1,y=$2,relative=true}))"