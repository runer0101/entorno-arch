#!/usr/bin/env bash
# Pide confirmación antes de ejecutar una acción del menú de energía (wlogout).
# Uso: powermenu-confirm.sh <lock|logout|suspend|reboot|shutdown>
#
# La primera opción de la lista es el texto explicativo y queda seleccionada
# por defecto: si pulsas Enter sin pensar, NO pasa nada.

set -u

case "${1:-}" in
    lock)
        titulo="Bloquear pantalla"
        detalle="Bloquea la pantalla. Todo sigue abierto detrás; vuelves con tu contraseña."
        verbo="bloquear"
        accion="hyprlock"
        ;;
    logout)
        titulo="Cerrar sesión"
        detalle="Cierra TODAS las apps sin guardar y vuelve al login. La PC sigue encendida."
        verbo="cerrar sesión"
        accion="hyprctl dispatch exit || loginctl kill-session ${XDG_SESSION_ID:-self}"
        ;;
    suspend)
        titulo="Suspender"
        detalle="Duerme en RAM. Ojo: en esta máquina el despertar con NVIDIA puede colgarse."
        verbo="suspender"
        accion="systemctl suspend"
        ;;
    reboot)
        titulo="Reiniciar"
        detalle="Cierra todo y la PC arranca de nuevo. Tarda unos 40 segundos."
        verbo="reiniciar"
        accion="systemctl reboot"
        ;;
    shutdown)
        titulo="Apagar"
        detalle="Cierra todo y apaga la PC por completo."
        verbo="apagar"
        accion="systemctl poweroff"
        ;;
    *)
        notify-send -u critical "Menú de energía" "Acción desconocida: ${1:-(vacía)}"
        exit 1
        ;;
esac

# El diálogo vive en un script aparte para que sea idéntico aquí y en
# RofiPass. Sale 0 solo si se elige explícitamente el "Sí".
"$HOME/scripts/confirm-dialog.sh" "$titulo" "$detalle" "Sí, $verbo" || exit 0

exec sh -c "$accion"
