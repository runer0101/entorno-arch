#!/bin/sh
# =============================================================
#  netmenu-clic.sh — cierra el menú de red si el clic fue FUERA.
#
#  Mismo mecanismo que menu-clic.sh (el del launcher), con la
#  diferencia importante de DÓNDE se saca el rectángulo del cuadro:
#
#  · El launcher usa wofi en LAYER-SHELL. Eso agarra el teclado en
#    exclusiva y deja el escritorio entero bloqueado (no te llega ni
#    un clic), así que el cierre tiene que pasar por un bind del
#    compositor. El rectángulo sale de `hyprctl -j layers`.
#
#  · El menú de red usa wofi como VENTANA NORMAL (--normal-window).
#    Así NO bloquea el escritorio — que es lo que tiene que pasar,
#    si no mientras el menú está abierto no se puede hacer nada más.
#    Al ser un cliente normal, su rectángulo sale de
#    `hyprctl -j clients`, y los clics salen y vuelven con normalidad.
#
#  El bind es NO CONSUMIDOR a propósito: un clic dentro del cuadro
#  tiene que llegar a wofi para poder elegir la opción. El clic
#  fuera no necesita llegar a ninguna parte; aquí lo cerramos.
#
#  Además NO hace falta testigo como en el launcher: el launcher
#  abre un wofi nuevo en cada clic, así que el mismo clic le
#  llegaría por waybar y lo reabriría al instante. El menú de red
#  es de instancia única con interruptor, de modo que ese segundo
#  clic igual cierra (es el comportamiento que queremos).
# =============================================================

pgrep -x wofi >/dev/null 2>&1 || exit 0

# Rectángulo del cuadro. Con --normal-window wofi es un cliente.
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

# Fuera. Se mata SÓLO el wofi de este menú (por PID), nunca un
# pkill global: el launcher de apps puede estar abierto a la vez.
WOFI_PID=$(cat "/tmp/netmanagerdm.wofi.pid" 2>/dev/null)
[ -n "$WOFI_PID" ] && kill "$WOFI_PID" 2>/dev/null
exit 0