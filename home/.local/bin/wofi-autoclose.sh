#!/bin/bash
# =============================================================
#  wofi-autoclose.sh — mata wofi cuando pierde foco
#
#  Wofi (ni ningún dmenu) trae "click outside to close" de fábrica:
#  en --normal-window queda como una ventana XWayland flotante
#  cualquiera y hay que cerrarla a mano. Este watcher escucha la
#  ventana activa de Hyprland vía hyprctl (polling 100 ms) y mata
#  el wofi en cuanto se enfoca cualquier otra cosa.
#
#  Uso:
#      wofi ... &
#      WOFI_PID=$!
#      wofi-autoclose.sh "$WOFI_PID" &
#      wait "$WOFI_PID"
#
#  Notas:
#  - Polling 100 ms (no socat al socket2): el coste es ~5 ms de CPU
#    por check, total despreciable mientras el menú esté abierto.
#    Más simple que parsear activewindowv2>> y más robusto si el
#    socket cambia de path entre versiones de Hyprland.
#  - Sale solo cuando wofi muere (kill -0 falla) o cuando wofi se
#    cerró por click outside → no deja zombies.
#  - Si no hay sesión Hyprland (CI, etc.) el while termina
#    inmediatamente por el kill -0, sin efectos.
# =============================================================

set -u
WOFI_PID="${1:?Uso: wofi-autoclose.sh <PID_DE_WOFI>}"

# Esperar un instante para que wofi se registre como ventana activa
# (sin esto, el primer check mataría wofi antes de que aparezca).
sleep 0.15

while kill -0 "$WOFI_PID" 2>/dev/null; do
    cls=$(hyprctl activewindow -j 2>/dev/null \
          | python3 -c 'import sys,json
try:
    d=json.load(sys.stdin)
    print(d.get("class",""))
except Exception:
    print("")' 2>/dev/null)

    # cls vacío = no hay ventana activa (raro) o hyprctl falló → no matar
    if [ -n "$cls" ] && [ "$cls" != "wofi" ]; then
        kill -TERM "$WOFI_PID" 2>/dev/null
        break
    fi
    sleep 0.1
done

# Limpieza: si wofi ya no existe, este watcher también puede morir
exit 0