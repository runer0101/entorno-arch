#!/bin/sh
# =============================================================
#  wofi-outside-click.sh — cierra el cuadro de wofi si el clic fue FUERA.
#
#  Uso:
#      wofi-outside-click.sh /ruta/al/fichero-con-el-pid-de-wofi
#
#  ── Por qué hace falta un bind del compositor ────────────────
#  Ningún dmenu trae "click outside to close" cuando corre como
#  VENTANA normal (--normal-window). Y no se puede meter en
#  layer-shell para obtenerlo gratis, porque esa superficie agarra
#  el teclado en exclusiva: mientras el menú está abierto Hyprland
#  no entrega ni un clic a nadie y el ESCRITORIO ENTERO se queda
#  bloqueado. Es el problema que documenta menu-clic.sh del
#  launcher, que sufre de lo mismo y por eso pasa por un bind.
#
#  La solución es la de siempre: mientras el cuadro está abierto se
#  registra un bind NO CONSUMIDOR en el botón izquierdo y este
#  script decide, con la posición real del puntero, si el clic cayó
#  dentro o fuera del rectángulo del cuadro:
#
#    · Dentro  → no hace nada. Como el bind no consume, el clic
#                sigue su camino hasta wofi y elige la opción.
#    · Fuera   → mata el wofi de ESE menú (por PID), nunca un
#                pkill global: el launcher u otro menú pueden estar
#                abiertos a la vez.
#
#  Por PID y no por "cualquier wofi": así cerrar un menú no se lleva
#  por delante los demás. Por eso el fichero del PID es un
#  argumento: cada menú tiene el suyo.
#
#  Salida: 0 siempre (es un hook del compositor; no debe fallar).
# =============================================================

WOFI_PID_FILE="${1:?Uso: wofi-outside-click.sh <fichero-con-el-pid-de-wofi>}"

pgrep -x wofi >/dev/null 2>&1 || exit 0

# Rectángulo del cuadro. Con --normal-window wofi es un CLIENTE
# normal, así que se saca de `clients`, no de `layers`.
CAJA=$(hyprctl -j clients 2>/dev/null | jq -r '
    .[] | select(.class == "wofi" or .initialClass == "wofi")
    | "\(.at[0]) \(.at[1]) \(.size[0]) \(.size[1])"' | head -1)
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

# Fuera del cuadro → cerrar sólo este.
WOFI_PID=$(cat "$WOFI_PID_FILE" 2>/dev/null)
[ -n "$WOFI_PID" ] && kill "$WOFI_PID" 2>/dev/null
exit 0