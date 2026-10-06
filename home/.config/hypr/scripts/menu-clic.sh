#!/bin/sh
# =============================================================
#  Decide si un clic del raton cierra el menu de aplicaciones.
#
#  Lo llama un bind NO consumidor (bindn) que menu-apps.sh registra
#  mientras el menu esta abierto y retira al cerrarlo.
#
#  Por que hace falta pasar por un bind del compositor:
#  wofi es una superficie layer-shell con teclado EXCLUSIVO, y mientras
#  esta abierta Hyprland NO entrega eventos de puntero a ningun otro
#  cliente. Comprobado inyectando clics reales: ni una ventana propia
#  encima, ni waybar, ni la barra entera reciben nada. Por eso el boton
#  [X] no podia funcionar por muy bien colocado que estuviera, y por eso
#  volver a pulsar el icono de Arch tampoco cerraba: waybar no llegaba a
#  enterarse del clic. Los binds del compositor, en cambio, SI se
#  procesan (probado con wofi abierto).
#
#  Regla: clic DENTRO del cuadro -> no hacemos nada, y como el bind es
#  "no consumidor" el clic sigue su camino hasta wofi y elige la app.
#  Clic FUERA (el icono de Arch, la [X], el escritorio) -> cerrar, que
#  es exactamente lo que hace Escape.
# =============================================================

pgrep -x wofi >/dev/null 2>&1 || exit 0

# El testigo lo lee menu-apps.sh: sin el, el mismo clic que cierra el
# menu llegaria tambien a waybar (el bind no consume) y volveria a
# abrirlo al instante.
TESTIGO="${XDG_RUNTIME_DIR:-/tmp}/menu-apps-cerrado"

CAJA=$(hyprctl -j layers 2>/dev/null | jq -r '
    to_entries[].value.levels | to_entries[].value[]
    | select(.namespace == "wofi")
    | "\(.x) \(.y) \(.w) \(.h)"' | head -1)
[ -n "$CAJA" ] || exit 0

POS=$(hyprctl cursorpos 2>/dev/null | tr -d ' ')   # "x,y"
CX=${POS%%,*}
CY=${POS##*,}
case "$CX$CY" in *[!0-9-]*|"") exit 0 ;; esac      # sin cursor fiable, no tocar

set -- $CAJA
X=$1; Y=$2; W=$3; H=$4

dentro=0
if [ "$CX" -ge "$X" ] && [ "$CX" -lt $((X + W)) ] &&
   [ "$CY" -ge "$Y" ] && [ "$CY" -lt $((Y + H)) ]; then
    dentro=1
fi

[ "$dentro" -eq 1 ] && exit 0

date +%s%3N > "$TESTIGO" 2>/dev/null
pkill -x wofi
exit 0
