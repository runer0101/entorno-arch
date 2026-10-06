#!/bin/sh
# =============================================================
#  Menu de aplicaciones (wofi drun) con tres formas de cerrarlo:
#    - volver a pulsar el icono de Arch
#    - clic en cualquier sitio fuera del cuadro
#    - Escape, como siempre
#
#  Anclado arriba a la izquierda, justo debajo de waybar, en vez de
#  centrado en la pantalla.
#
#  --- Por que el cierre va por un bind del compositor (28 jul 2026) ---
#  wofi es una superficie layer-shell con teclado EXCLUSIVO: mientras
#  esta abierta, Hyprland no entrega eventos de puntero a NADIE mas.
#  Se probo inyectando clics de verdad: una ventana propia por encima
#  no los recibe, y waybar tampoco (el script ni se invocaba), asi que
#  el interruptor "pulsa otra vez el icono" no podia funcionar. Lo que
#  si funciona con wofi abierta son los binds de Hyprland, y de ahi
#  sale el bind de raton temporal que se registra aqui.
#
#  Hubo un boton [X] flotando a la derecha del cuadro (wofi-cerrar.py).
#  Se quito: por lo de arriba no podia recibir el clic, asi que era un
#  dibujo que dependia igualmente de la regla "clic fuera = cerrar", y
#  esa regla ya cubre todo el borde del menu.
# =============================================================
echo "$(date +%T.%3N) invocado, wofi=$(pgrep -x -c wofi 2>/dev/null || echo 0)" >> /tmp/menu-apps.log

X=12        # waybar empieza en x=12; el menu queda a plomo con la barra
Y=6         # separacion por debajo de la barra
W=550       # el ancho se queda como estaba
H=700       # mucho mas alto que el 325 del config de wofi: unas 15 apps a la
            # vista. Se queda en menu-apps.sh y no se toca ~/.config/wofi/config,
            # que lo usan otros menus (powermenu, etc.)

CLIC="$HOME/.config/hypr/scripts/menu-clic.sh"
TESTIGO="${XDG_RUNTIME_DIR:-/tmp}/menu-apps-cerrado"

# Solo el bind SIN modificadores. El `bindm = SUPER, mouse:272, movewindow`
# de hyprland.conf lleva modmask y no lo toca (comprobado).
# 'keyword' no funciona con config Lua (parser no-legado); hay que usar eval
poner_bind() { hyprctl eval "hl.bind(\"mouse:272\", hl.dsp.exec_cmd(\"$CLIC\"), { non_consuming = true })" >/dev/null 2>&1; }
quitar_bind() { hyprctl eval 'hl.unbind("mouse:272")' >/dev/null 2>&1; }

# El mismo clic que cierra el menu llega TAMBIEN a waybar, porque el bind
# es no consumidor (tiene que serlo: si consumiera, no se podria elegir una
# app con el raton). Sin este testigo, ese clic reabriria el menu al vuelo.
if [ -f "$TESTIGO" ]; then
    CERRADO=$(cat "$TESTIGO" 2>/dev/null)
    rm -f "$TESTIGO"
    AHORA=$(date +%s%3N)
    case "$CERRADO" in
        ''|*[!0-9]*) ;;
        *) [ $((AHORA - CERRADO)) -lt 600 ] && exit 0 ;;
    esac
fi

# Interruptor para el teclado (SUPER+Space) y red de seguridad: con el raton
# el cierre lo hace antes menu-clic.sh, que si ve el clic.
if pgrep -x wofi >/dev/null 2>&1; then
    pkill -x wofi
    quitar_bind
    exit 0
fi

# Pase lo que pase, el bind de raton no debe sobrevivir al menu: es global
# mientras existe. Se limpia tambien al entrar, por si una ejecucion
# anterior murio a medias.
quitar_bind
trap 'quitar_bind' EXIT INT TERM HUP

poner_bind

wofi --show drun \
     --style "$HOME/.config/wofi/style.css" \
     --location top_left \
     --xoffset "$X" --yoffset "$Y" \
     --width "$W" --height "$H"

# wofi ya termino (Escape, clic fuera, o se eligio una app).
quitar_bind
