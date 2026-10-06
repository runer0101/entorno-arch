#!/usr/bin/env bash
# Vigilante del cable HDMI: si lo enchufas con la sesión ya arrancada, la pantalla
# se enciende sola; si lo quitas, nunca te quedas sin ninguna pantalla.
#
# Por qué hace falta, si Hyprland ya reacciona solo al hotplug:
#
#   1) Las reglas de `hyprctl keyword monitor` son PERMANENTES en la sesión y se
#      aplican por NOMBRE cuando el monitor aparece. Un `HDMI-A-1,disable` (lo que
#      escribe `pantalla.sh -L`, y lo que escribía el menú con el cable fuera) sigue
#      ahí una hora después: vuelves a enchufar el cable y la pantalla se queda
#      negra sin que nada lo explique. Aquí se pisa esa regla al detectar el cable.
#   2) `pantalla.sh -m` apaga el panel del portátil. Si con ese modo puesto quitas
#      el HDMI, te quedas sin ninguna salida encendida. Aquí se reenciende el eDP.
#
# El criterio es "manda el cable": enchufarlo es una intención nueva de usar la
# pantalla, así que un apagado anterior no sobrevive a un ciclo de desenchufe.
# Apagarla a mano con el cable puesto (`-L`) SÍ se respeta: no hay ausencia de
# por medio, y sin ausencia este script no toca nada.
#
# Dos fuentes de eventos, porque ninguna sola es de fiar aquí:
#   - socket2 de Hyprland: monitoradded/monitorremoved. Es lo natural, pero si la
#     regla `disable` está puesta, el monitor puede nacer ya apagado y no está
#     garantizado que el evento salga.
#   - udev (subsistema drm): el aviso del kernel, que llega pase lo que pase.
# Ambas son PUSH. No se sondea /sys/class/drm/*/status en bucle: leer ese fichero
# puede forzar un sondeo del conector y despertar a la dGPU (el HDMI sale por la
# NVIDIA en este portátil). La presencia del cable se consulta a Hyprland, que ya
# lo sabe: un conector sin cable no aparece en `hyprctl monitors all`.

set -u

INTERNAL="eDP-1"
EXTERNAL="HDMI-A-1"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}"
ESTADO="$CACHE/pantalla-cable"          # si | no — lo visto en la última pasada
MODO="$CACHE/pantalla-modo"             # lo escribe pantalla.sh: regla + posición
REGLA_DEFECTO="$EXTERNAL,1920x1080@60,auto-right,1"   # la misma de hyprland.conf
DEBOUNCE=2                              # un enchufe genera una ráfaga de eventos

command -v hyprctl >/dev/null 2>&1 || { echo "falta hyprctl" >&2; exit 1; }
command -v jq      >/dev/null 2>&1 || { echo "falta jq" >&2; exit 1; }

log() { logger -t pantalla-watch "$*" 2>/dev/null; }

monitores() { hyprctl monitors all -j 2>/dev/null; }

# ¿Está el cable puesto? Un conector desconectado NO figura en `monitors all`;
# uno apagado con `disable` sí, con disabled=true. Justo lo que necesitamos.
hdmi_presente() {
    monitores | jq -e --arg e "$EXTERNAL" 'any(.[]; .name == $e)' >/dev/null 2>&1
}

hdmi_encendida() {
    monitores | jq -e --arg e "$EXTERNAL" \
        'any(.[]; .name == $e and (.disabled | not))' >/dev/null 2>&1
}

interno_apagado() {
    monitores | jq -e --arg i "$INTERNAL" \
        'any(.[]; .name == $i and .disabled)' >/dev/null 2>&1
}

# Línea 1 del fichero de modo = la regla completa que aplicó pantalla.sh.
# Se guarda la regla entera (y no un nombre de modo) porque "clonar" lleva
# `,mirror,eDP-1` detrás y así no hay que reconstruir nada.
regla_guardada() {
    local r=""
    [ -r "$MODO" ] && r=$(sed -n '1p' "$MODO" 2>/dev/null)
    case "$r" in
        "$EXTERNAL",*) echo "$r" ;;   # solo aceptamos reglas del monitor externo
        *) echo "$REGLA_DEFECTO" ;;
    esac
}

# Línea 2 = posición, para saber a qué monitor van los workspaces 1-5 y 6-10.
pos_guardada() {
    local p=""
    [ -r "$MODO" ] && p=$(sed -n '2p' "$MODO" 2>/dev/null)
    case "$p" in
        izquierda|derecha|arriba|abajo|clonar) echo "$p" ;;
        *) echo "derecha" ;;
    esac
}

workspaces() {
    local primero=$1 segundo=$2 ws
    for ws in 1 2 3 4 5;      do hyprctl keyword workspace "$ws,monitor:$primero" >/dev/null 2>&1 || true; done
    for ws in 6 7 8 9 10;     do hyprctl keyword workspace "$ws,monitor:$segundo" >/dev/null 2>&1 || true; done
}

# El cable acaba de aparecer: encender pase lo que pase.
enchufado() {
    local regla pos
    regla=$(regla_guardada)
    pos=$(pos_guardada)

    hyprctl keyword monitor "$regla" >/dev/null 2>&1
    # Por si venía de `-m` (portátil apagado) o de un `disable` del interno.
    hyprctl keyword monitor "$INTERNAL,preferred,auto,1" >/dev/null 2>&1

    case "$pos" in
        izquierda) workspaces "$EXTERNAL" "$INTERNAL" ;;
        clonar)    workspaces "$INTERNAL" "$INTERNAL" ;;
        *)         workspaces "$INTERNAL" "$EXTERNAL" ;;
    esac

    log "HDMI enchufado → regla «$regla» (pos: $pos)"
    if hdmi_encendida; then
        notify-send -u low -t 4000 -a "Pantalla" "Pantalla externa conectada" \
            "HDMI encendido ($pos)." 2>/dev/null
    else
        # No debería pasar; si pasa, mejor enterarse que quedarse mirando una negra.
        log "HDMI presente pero sigue apagado tras aplicar «$regla»"
        notify-send -u normal -t 8000 -a "Pantalla" "El HDMI no se encendió" \
            "Prueba con: pantalla.sh -r" 2>/dev/null
    fi
}

# El cable se fue: lo único importante es no quedarse a oscuras.
desenchufado() {
    if interno_apagado; then
        hyprctl keyword monitor "$INTERNAL,preferred,auto,1" >/dev/null 2>&1
        workspaces "$INTERNAL" "$INTERNAL"
        log "HDMI fuera con el portátil apagado (modo -m): reencendido $INTERNAL"
        notify-send -u normal -t 6000 -a "Pantalla" "Pantalla del portátil reactivada" \
            "Quitaste el HDMI y era la única pantalla encendida." 2>/dev/null
    fi
    log "HDMI desenchufado"
}

revisar() {
    local previo="" ahora
    [ -r "$ESTADO" ] && previo=$(cat "$ESTADO" 2>/dev/null)

    if hdmi_presente; then
        ahora="si"
        # Solo actuamos en el FLANCO no→si. Así un apagado voluntario con el cable
        # puesto (`pantalla.sh -L`) no se deshace a los dos segundos.
        [ "$previo" = "si" ] || { [ -n "$previo" ] && enchufado; }
    else
        ahora="no"
        [ "$previo" = "no" ] || { [ -n "$previo" ] && desenchufado; }
    fi

    printf '%s\n' "$ahora" > "$ESTADO"
    return 0
}

case "${1:-vigilar}" in
    vigilar|--vigilar) ;;
    # Una sola pasada y fuera. Sirve para depurar ("¿qué haría ahora mismo?") y
    # es lo que permite probar la máquina de estados con un hyprctl de mentira,
    # sin tener que tirar del cable de verdad.
    revisar|--revisar) revisar; exit 0 ;;
    -h|--help|*)
        cat <<EOF
Uso: pantalla-watch.sh [vigilar|revisar]

  vigilar  (por defecto) se queda escuchando el cable HDMI. Lo lanza hyprland.conf.
  revisar  hace una sola pasada y sale.

El criterio: enchufar el cable enciende la pantalla siempre, aunque estuviera
apagada a mano. Apagarla con el cable puesto (pantalla.sh -L) se respeta.
EOF
        exit 0 ;;
esac

# Uno y solo uno. Lo lanza hyprland.conf con exec-once, pero si alguien lo arranca
# a mano habría dos escuchando y aplicando reglas a la vez sobre el mismo monitor.
LOCK="$CACHE/pantalla-watch.lock"
# Ojo: el `2>/dev/null` va aparte. `exec 9>fichero 2>/dev/null` aplica AMBAS
# redirecciones al shell entero y deja el script mudo el resto de la sesión.
exec 9>"$LOCK"
if command -v flock >/dev/null 2>&1 && ! flock -n 9; then
    echo "Ya hay otro pantalla-watch.sh vigilando; salgo." >&2
    exit 0
fi

# Estado inicial: solo se anota, no se actúa. Al arrancar la sesión Hyprland ya
# ha aplicado hyprland.conf y todo está donde debe.
if hdmi_presente; then echo si > "$ESTADO"; else echo no > "$ESTADO"; fi

# Las dos fuentes escriben en un mismo FIFO y el bucle principal lee de ahí.
# Con un FIFO (y no `fuentes | while read`) el bucle corre en el shell principal:
# los PIDs de las fuentes siguen siendo visibles, así que se pueden vigilar y
# matar de forma quirúrgica. Nada de `kill 0`: este script lo lanza Hyprland con
# exec-once y podría compartir grupo de procesos con el compositor.
FIFO=$(mktemp -u "${TMPDIR:-/tmp}/pantalla-watch.XXXXXX")
mkfifo "$FIFO" || exit 1
exec 3<>"$FIFO"      # lectura Y escritura: así el read nunca ve EOF
rm -f "$FIFO"        # ya está abierto; el nombre en disco sobra

pid_hypr=""
pid_udev=""

# Mata el subshell Y lo que cuelga de él. Sin bajar un nivel más, `udevadm` (nieto)
# se queda huérfano corriendo para siempre; se vio en pruebas. Nada de `kill 0`:
# el grupo de procesos puede ser el del compositor.
matar() {
    local pid=$1 hijo
    [ -n "$pid" ] || return 0
    for hijo in $(pgrep -P "$pid" 2>/dev/null); do
        pkill -P "$hijo" 2>/dev/null
        kill "$hijo" 2>/dev/null
    done
    kill "$pid" 2>/dev/null
    return 0
}

vivo() { [ -n "$1" ] && kill -0 "$1" 2>/dev/null; }

lanzar_hypr() {
    local sock="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr/${HYPRLAND_INSTANCE_SIGNATURE:-}/.socket2.sock"
    [ -S "$sock" ] || return 0
    command -v socat >/dev/null 2>&1 || return 0
    { socat -U - "UNIX-CONNECT:$sock" 2>/dev/null \
        | grep --line-buffered -E '^monitor(added|removed)' >&3; } &
    pid_hypr=$!
}

lanzar_udev() {
    command -v udevadm >/dev/null 2>&1 || return 0
    { udevadm monitor --udev --subsystem-match=drm 2>/dev/null \
        | grep --line-buffered -E 'change' >&3; } &
    pid_udev=$!
}

trap 'matar "$pid_hypr"; matar "$pid_udev"; exit 0' EXIT INT TERM HUP

lanzar_hypr
lanzar_udev

while :; do
    if read -r -t 60 _ <&3; then
        # Absorbe la ráfaga: seguimos leyendo hasta que pasen DEBOUNCE segundos
        # sin novedades, y solo entonces miramos cómo ha quedado la cosa.
        while read -r -t "$DEBOUNCE" _ <&3; do :; done
        revisar
    else
        # Sin eventos en 60 s: aprovechamos para resucitar lo que se haya caído
        # (socat se va cuando Hyprland recarga o cierra el socket).
        vivo "$pid_hypr" || { matar "$pid_hypr"; lanzar_hypr; }
        vivo "$pid_udev" || { matar "$pid_udev"; lanzar_udev; }
    fi
done
