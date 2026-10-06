#!/usr/bin/env bash
# Conmuta qué GPUs abre Hyprland al arrancar.
#
#   hibrido  → las dos (AMD + NVIDIA). Necesario para el HDMI, que en este
#              portátil sale por la NVIDIA (card1). Es el comportamiento de
#              siempre y el que debe quedar si dudas.
#   movil    → solo la AMD. Hyprland no abre el nodo DRM de la NVIDIA, así que
#              la dGPU puede entrar en D3cold y dejar de comerse la batería.
#              A cambio el HDMI NO funciona hasta volver a "hibrido".
#
# AQ_DRM_DEVICES lo lee aquamarine UNA SOLA VEZ al iniciar Hyprland: cambiar de
# perfil no tiene efecto hasta reiniciar la sesión. No hay forma de hacerlo en
# caliente; cerrar el monitor con hyprctl no suelta el dispositivo DRM.

set -u

CONF="$HOME/.config/hypr/gpu-profile.conf"
AMD_SLOT="0000:06:00.0"                        # la AMD (la NVIDIA es 0000:01:00.0)
AMD_BY_PATH="/dev/dri/by-path/pci-$AMD_SLOT-card"   # lo crea udev de serie (60-drm.rules)

c_ok=$'\e[32m'; c_warn=$'\e[33m'; c_err=$'\e[31m'; c_dim=$'\e[2m'; c_off=$'\e[0m'

# Slot PCI al que pertenece un nodo /dev/dri/* (siguiendo symlinks).
slot_de() {
    local n destino
    destino=$(readlink -f "$1" 2>/dev/null) || return 1
    n=${destino##*/}
    destino=$(readlink -f "/sys/class/drm/$n/device" 2>/dev/null) || return 1
    echo "${destino##*/}"
}

# La comprobación que importa: que el nodo sea DE VERDAD la AMD. /dev/dri/cardN
# puede cambiar de número entre arranques, así que "el fichero existe" NO basta:
# card2 podría ser la NVIDIA en el siguiente boot y el panel eDP se quedaría fuera.
es_amd() { [ "$(slot_de "$1" 2>/dev/null)" = "$AMD_SLOT" ]; }

# Devuelve el nodo DRM de la AMD como ruta CANÓNICA (/dev/dri/cardN).
#
# Se localiza por by-path (slot PCI, estable) pero se escribe el cardN resuelto,
# nunca la propia ruta by-path: aquamarine parte AQ_DRM_DEVICES por ':' igual que
# $PATH, y pci-0000:06:00.0-card lleva tres. Al trocearse, el backend DRM no
# encontraba ninguna GPU y Hyprland abortaba en initServer — el login de SDDM
# rebotaba al greeter como si la contraseña estuviera mal (incidente 27 jul 2026).
#
# Tampoco usamos un symlink propio de udev: /dev/dri/cardN es exactamente el tipo
# de ruta que aquamarine ya acepta y tenemos probada en esta máquina. Que el
# número pueda bailar entre arranques da igual, porque sanear() lo vuelve a
# resolver y verifica el slot ANTES de que Hyprland lea el conf.
amd_card() {
    local ruta
    ruta=$(readlink -f "$AMD_BY_PATH" 2>/dev/null) || return 1
    [ -e "$ruta" ] && es_amd "$ruta" || return 1
    case "$ruta" in
        *:*) return 1 ;;   # con ':' dentro, aquamarine la trocea y no arranca
    esac
    echo "$ruta"
}

# ¿Hay algún conector de la NVIDIA con cable? (HDMI sale por ella)
nvidia_con_cable() {
    local c card
    for c in /sys/class/drm/card*-*; do
        [ "$(cat "$c/status" 2>/dev/null)" = "connected" ] || continue
        card=${c##*/}; card=${card%%-*}
        [ "$(cat "/sys/class/drm/$card/device/vendor" 2>/dev/null)" = "0x10de" ] && return 0
    done
    return 1
}

perfil_guardado() {
    [ -f "$CONF" ] || { echo "hibrido"; return; }
    grep -q '^env = AQ_DRM_DEVICES' "$CONF" 2>/dev/null && echo "movil" || echo "hibrido"
}

# El perfil que de verdad está corriendo. NO se puede mirar $AQ_DRM_DEVICES: Hyprland
# aplica los `env =` del config al recargar (y recarga solo al tocar el fichero), así
# que la variable acaba puesta aunque aquamarine —que la lee UNA vez, al crear el
# backend— nunca la haya visto. Durante días el script dijo "movil" mientras el
# compositor tenía las dos tarjetas abiertas. La única fuente fiable es el log del
# backend: cuántas GPUs registró de verdad.
perfil_activo() {
    local log n
    log=$(ls -t "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"/hypr/*/hyprland.log 2>/dev/null | head -1)
    if [ -n "$log" ] && [ -r "$log" ]; then
        n=$(grep -c 'drm: Registered gpu' "$log" 2>/dev/null) || n=0
        if [ "$n" -ge 1 ] 2>/dev/null; then
            [ "$n" -eq 1 ] && echo "movil" || echo "hibrido"
            return
        fi
    fi
    echo "desconocido"
}

escribir() {
    local modo=$1 card
    if [ "$modo" = "movil" ]; then
        card=$(amd_card) || {
            echo "${c_err}No hay una ruta usable a la AMD ($AMD_SLOT).${c_off}" >&2
            echo "${c_err}Me quedo en 'hibrido': un AQ_DRM_DEVICES malo impide entrar a la sesión.${c_off}" >&2
            exit 1
        }
        cat > "$CONF" <<EOF
# Generado por ~/scripts/gpu-perfil.sh — no editar a mano.
# Perfil: movil (solo AMD). La NVIDIA queda libre y puede dormir en D3cold.
# OJO: el HDMI sale por la NVIDIA, así que con este perfil no hay pantalla externa.
env = AQ_DRM_DEVICES,$card
EOF
    else
        cat > "$CONF" <<EOF
# Generado por ~/scripts/gpu-perfil.sh — no editar a mano.
# Perfil: hibrido (AMD + NVIDIA). Hace falta para el HDMI.
# Sin AQ_DRM_DEVICES aquamarine abre las dos tarjetas, que es lo de siempre.
EOF
    fi
}

reiniciar_hyprland() {
    echo "${c_warn}Se va a cerrar la sesión de Hyprland. Guarda lo que tengas abierto.${c_off}"
    read -r -p "¿Seguir? [s/N] " r
    case "$r" in
        s|S|si|SI|sí|Sí) hyprctl dispatch exit ;;
        *) echo "Cancelado. El perfil ya está escrito; se aplicará al próximo inicio." ;;
    esac
}

estado() {
    local g a n
    g=$(perfil_guardado); a=$(perfil_activo)
    nvidia_con_cable && n="sí" || n="no"
    echo "Perfil guardado : $g   ${c_dim}(se aplica al próximo inicio de Hyprland)${c_off}"
    echo "Perfil activo   : $a   ${c_dim}(el de esta sesión)${c_off}"
    echo "Pantalla externa: $n"
    [ "$g" != "$a" ] && echo "${c_warn}→ Hay un cambio pendiente: reinicia Hyprland para aplicarlo.${c_off}"
    if [ "$a" = "hibrido" ]; then
        local st
        st=$(cat /sys/bus/pci/devices/0000:01:00.0/power/runtime_status 2>/dev/null)
        echo "NVIDIA          : $st ${c_dim}$([ "$n" = "sí" ] && echo '(normal: está moviendo el HDMI)')${c_off}"
    fi
    return 0
}

aplicar() {
    local modo=$1 forzar=${2:-}
    if [ "$modo" = "movil" ] && nvidia_con_cable && [ "$forzar" != "--force" ]; then
        echo "${c_warn}Tienes la pantalla externa conectada y sale por la NVIDIA.${c_off}"
        echo "Con el perfil 'movil' esa pantalla dejaría de funcionar."
        echo "Si aun así lo quieres: $0 movil --force"
        exit 1
    fi
    escribir "$modo"
    echo "${c_ok}Perfil guardado: $modo${c_off}"
    echo "${c_dim}Se aplica al próximo inicio de Hyprland.${c_off}"
}

# Red de seguridad. Si el AQ_DRM_DEVICES guardado lleva ':', ha desaparecido o
# ha dejado de ser la AMD (cardN renumerado), Hyprland abortaría al arrancar y el
# login de SDDM rebotaría al greeter: te quedas fuera sin saber por qué.
#
# La llama ~/.zprofile, que SDDM sí carga ANTES de lanzar Hyprland, así que la
# reparación llega a tiempo para ESTE arranque, no para el siguiente.
# Primero intenta reapuntar al nodo correcto (conserva el perfil 'movil'); si no
# hay AMD localizable, cae a 'hibrido', que arranca siempre.
sanear() {
    local ruta buena
    ruta=$(grep -m1 '^env = AQ_DRM_DEVICES,' "$CONF" 2>/dev/null) || return 0
    ruta=${ruta#env = AQ_DRM_DEVICES,}
    case "$ruta" in
        *:*) ;;                                        # troceable: hay que tocarlo
        *) if [ -e "$ruta" ] && es_amd "$ruta"; then return 0; fi ;;
    esac
    if buena=$(amd_card 2>/dev/null) && [ -n "$buena" ]; then
        escribir movil
        echo "${c_warn}gpu-profile.conf apuntaba a «$ruta», que ya no es la AMD; reapuntado a «$buena».${c_off}" >&2
        notify-send -u normal -a "GPU" "Perfil de GPU corregido" \
            "El nodo DRM de la AMD cambió de sitio.\nEl perfil «movil» ahora apunta a $buena." 2>/dev/null
        return 0
    fi
    escribir hibrido
    echo "${c_warn}gpu-profile.conf apuntaba a «$ruta», que no sirve; vuelto a 'hibrido'.${c_off}" >&2
    notify-send -u critical -a "GPU" "Perfil de GPU reparado" \
        "El perfil «movil» apuntaba a un nodo DRM inválido y habría impedido iniciar sesión.\nSe volvió a «hibrido»." 2>/dev/null
    return 0
}

TESTIGO="${XDG_CACHE_HOME:-$HOME/.cache}/gpu-perfil-intento"

# Lo llama ~/.zprofile, que SDDM carga ANTES de lanzar Hyprland. Imprime la línea de
# export para que AQ_DRM_DEVICES esté en el entorno cuando aquamarine cree el backend.
#
# Hace falta porque `env = AQ_DRM_DEVICES` dentro del config NO sirve: Hyprland lo
# aplica al parsear, que es DESPUÉS de crear el backend DRM. Se comprobó en el log
# (`drm: Found 2 GPUs` y dos `Registered gpu`, sin `Explicit device list`): el perfil
# movil no se estaba aplicando y el compositor tenía abiertas las dos tarjetas.
#
# Red de seguridad propia: deja un testigo antes de exportar y lo borra `notificar`
# cuando la sesión ya está arriba. Si al arrancar el testigo sigue ahí, el intento
# anterior no llegó a sesión: se salta el export y entra en hibrido, que siempre
# arranca. Se reintenta en el arranque siguiente.
entorno() {
    [ "$(perfil_guardado)" = "movil" ] || return 0

    # Adaptable DE VERDAD. Este es el único momento del arranque en que mirar el
    # cable sirve para algo: aquamarine todavía no ha creado el backend, así que
    # con no exportar basta para entrar en hibrido y tener HDMI desde el primer
    # segundo. Antes se confiaba solo en el perfil guardado de la sesión anterior
    # y gpu-perfil-watch.sh descubría el cable ~5 s después, cuando la variable
    # ya estaba leída y lo único que quedaba era pedir un reinicio.
    #
    # No se reescribe el conf: el perfil guardado sigue siendo 'movil', para que
    # al desenchufar vuelvas solo a ahorrar batería sin tener que pedirlo otra vez.
    if nvidia_con_cable; then
        echo "Pantalla externa enchufada: arranco en hibrido pese al perfil 'movil' guardado." >&2
        return 0
    fi

    if [ -e "$TESTIGO" ]; then
        rm -f "$TESTIGO"
        echo "El intento anterior de 'movil' no llegó a sesión; arranco en hibrido." >&2
        return 0
    fi

    local ruta
    ruta=$(grep -m1 '^env = AQ_DRM_DEVICES,' "$CONF" 2>/dev/null) || return 0
    ruta=${ruta#env = AQ_DRM_DEVICES,}
    case "$ruta" in *:*) return 0 ;; esac
    [ -e "$ruta" ] && es_amd "$ruta" || return 0

    : > "$TESTIGO"
    printf 'export AQ_DRM_DEVICES=%s\n' "$ruta"
}

# Cierre del arranque: confirma que la sesión subió y repara el conf si hacía falta.
#
# Ya NO notifica nada. Avisaba de lo mismo que gpu-perfil-watch.sh en su primera
# pasada, con otro texto y unos milisegundos después, así que en cada arranque
# desajustado salían dos notificaciones criticas duplicadas (28 jul 2026). El aviso
# vive ahora en un solo sitio: avisar() del vigilante.
notificar() {
    rm -f "$TESTIGO"   # la sesión arrancó: el intento fue bien
    sanear
    return 0
}

# Lo que lanza la tecla: alterna, enseña cómo queda y ofrece reiniciar. Va aquí
# y no en el bind para que hyprland.conf no lleve comillas — con ellas
# `hyprctl binds -j` devuelve JSON inválido.
menu() {
    if [ "$(perfil_guardado)" = "movil" ]; then
        aplicar hibrido
    else
        nvidia_con_cable && aplicar movil --force || aplicar movil
    fi
    echo; estado; echo
    if [ "$(perfil_guardado)" != "$(perfil_activo)" ]; then
        reiniciar_hyprland
    else
        read -r -p "Enter para cerrar " _
    fi
}

case "${1:-estado}" in
    estado|--estado|status) estado ;;
    notificar|--notificar) notificar ;;
    sanear|--sanear) sanear ;;
    entorno|--entorno) entorno ;;   # lo llama ~/.zprofile antes de arrancar Hyprland
    menu|--menu) menu ;;
    # Salidas de una palabra, para guionizar (las usa gpu-perfil-watch.sh)
    guardado) perfil_guardado ;;
    activo)   perfil_activo ;;
    conveniente) nvidia_con_cable && echo hibrido || echo movil ;;
    movil|móvil)    aplicar movil "${2:-}" ;;
    hibrido|híbrido) aplicar hibrido ;;
    auto)
        if nvidia_con_cable; then aplicar hibrido; else aplicar movil; fi ;;
    toggle)
        if [ "$(perfil_guardado)" = "movil" ]; then aplicar hibrido; else aplicar movil "${2:-}"; fi ;;
    reiniciar|--reiniciar) reiniciar_hyprland ;;
    *)
        cat <<EOF
Uso: gpu-perfil.sh [estado|movil|hibrido|auto|toggle|reiniciar]

  estado     qué perfil hay guardado, cuál corre y si la NVIDIA duerme
  movil      solo AMD — la dGPU puede dormir, pero te quedas sin HDMI
  hibrido    AMD + NVIDIA — lo de siempre, necesario para el HDMI
  auto       elige según tengas o no la pantalla externa enchufada
  toggle     alterna entre los dos
  reiniciar  cierra Hyprland para aplicar el perfil pendiente

Añade --force a 'movil' para asumir que perderás la pantalla externa.
EOF
        exit 1 ;;
esac
