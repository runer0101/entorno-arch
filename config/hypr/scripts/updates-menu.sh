#!/bin/bash
# =============================================================
#  updates-menu — menú de confirmación del botón de updates del Waybar.
#  Sale primero "Salir" (norma), y debajo "Actualizar paquetes", que lanza
#  la misma actualización de antes (paru -Syu en una kitty).
# =============================================================

WOFI_STYLE="$HOME/.config/wofi/style-net.css"
[ -f "$WOFI_STYLE" ] || WOFI_STYLE="$HOME/.config/wofi/style.css"

menu() {
    wofi --dmenu --hide-search --insensitive --cache-file=/dev/null \
         -L 2 --prompt "Actualizaciones" --style "$WOFI_STYLE" 2>/dev/null
}

ACT_EXIT="✖  Salir"
ACT_UPDATE="󰚰  Actualizar paquetes"

sel=$(printf '%s\n%s\n' "$ACT_EXIT" "$ACT_UPDATE" | menu)

case "$sel" in
    "$ACT_UPDATE")
        kitty --hold -e sh -c 'echo Actualizando...; paru -Syu --nocombinedupgrade; read _ </dev/tty 2>/dev/null'
        ;;
    *) exit 0 ;;
esac
