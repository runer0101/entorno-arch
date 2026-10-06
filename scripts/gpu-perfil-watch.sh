#!/usr/bin/env bash
# Adapta el perfil de GPU a cómo estés usando el portátil.
#
# Qué puede y qué no: AQ_DRM_DEVICES lo lee aquamarine al arrancar el backend,
# así que NADA puede cambiar de GPU en caliente. Lo que sí se puede es detectar
# el momento en que enchufas o quitas la pantalla externa y dejar el perfil
# correcto escrito para el próximo inicio de Hyprland, avisándote solo cuando
# ese cambio te afecta de verdad.
#
# La detección va por eventos de udev (el kernel los empuja) y no sondeando
# /sys/class/drm/*/status: leer ese fichero puede forzar un sondeo del conector
# y despertar a la GPU, que es justo lo que queremos evitar.

set -u

PERFIL="${GPU_PERFIL_BIN:-$HOME/scripts/gpu-perfil.sh}"   # override = probar sin tocar hardware
DEBOUNCE=3   # un enchufe genera varios eventos seguidos; esperamos a que amaine

[ -x "$PERFIL" ] || { echo "falta $PERFIL" >&2; exit 1; }

avisar() {
    local conveniente=$1 activo=$2
    # Único aviso que queda: enchufaste la pantalla y esta sesión no puede usarla.
    # Tras el cambio de abajo esto solo pasa si TÚ elegiste 'movil' a mano, así que
    # ya no es un sobresalto sino la consecuencia de una decisión tuya. Se cierra
    # solo; el recordatorio persistente vive en el panel de notificaciones.
    if [ "$conveniente" = "hibrido" ] && [ "$activo" = "movil" ]; then
        notify-send -u normal -t 8000 -a "GPU" "Pantalla externa conectada" \
            "Elegiste el perfil «movil», que no abre la NVIDIA.\nReinicia Hyprland para usarla (SUPER+SHIFT+G)." 2>/dev/null
    fi
}

revisar() {
    local conveniente guardado activo
    conveniente=$("$PERFIL" conveniente)
    guardado=$("$PERFIL" guardado)
    activo=$("$PERFIL" activo)

    # NUNCA bajamos a 'movil' por nuestra cuenta.
    #
    # AQ_DRM_DEVICES se lee una sola vez, al crear el backend: si la sesión arranca
    # sin la NVIDIA, enchufar el HDMI una hora después no puede hacer nada. Como el
    # cable puede aparecer en cualquier momento, el único perfil en el que el HDMI
    # funciona SIEMPRE es 'hibrido', y por eso es el que dejamos por defecto.
    #
    # 'movil' pasa a ser una elección manual y consciente (SUPER+SHIFT+G), que es
    # lo único que era de verdad: con el cable puesto no ahorra nada, porque un
    # conector conectado mantiene despierta a la dGPU aunque Hyprland no la abra.
    if [ "$conveniente" = "hibrido" ] && [ "$guardado" != "hibrido" ]; then
        "$PERFIL" hibrido >/dev/null 2>&1
        logger -t gpu-perfil "perfil guardado → hibrido (activo: $activo)" 2>/dev/null
    fi

    # Avisar solo si la sesión actual no case con lo que hay enchufado.
    [ "$conveniente" != "$activo" ] && avisar "$conveniente" "$activo"
    return 0
}

# Estado al iniciar sesión.
revisar

mon_pid=""
trap '[ -n "$mon_pid" ] && kill "$mon_pid" 2>/dev/null; exit 0' EXIT INT TERM HUP

while :; do
    exec 3< <(udevadm monitor --udev --subsystem-match=drm 2>/dev/null)
    mon_pid=$!

    while read -r line <&3; do
        case "$line" in
            *"change"*drm*|*drm*"change"*)
                # Absorbe la ráfaga: seguimos leyendo hasta que pasen DEBOUNCE
                # segundos sin novedades, y solo entonces decidimos.
                while read -r -t "$DEBOUNCE" _ <&3; do :; done
                revisar
                ;;
        esac
    done

    exec 3<&-
    kill "$mon_pid" 2>/dev/null
    wait "$mon_pid" 2>/dev/null
    mon_pid=""
    sleep 5
done
