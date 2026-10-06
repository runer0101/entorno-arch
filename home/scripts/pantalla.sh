#!/bin/bash
# pantalla.sh - gestor de pantalla externa (HDMI) auto-detectando sesion
#
# Detecta automaticamente si estamos en:
#   - Wayland (Hyprland)  -> wlr-randr + hyprctl + awww + waybar
#   - X11   (bspwm)       -> xrandr  + bspc  + feh    + polybar
#
# Logica de desktops:
#   - HDMI a la IZQUIERDA de la laptop: HDMI = 1-5 (primary), laptop = 6-10
#   - HDMI a la DERECHA / ARRIBA / ABAJO: laptop = 1-5 (primary), HDMI = 6-10
#   - HDMI apagado / solo laptop: laptop = 1-5
#   - Clonar: HDMI espeja al laptop (mirror), desktops 1-5

set -e

INTERNAL="eDP-1"
EXTERNAL="HDMI-A-1"

# Lo que aplicamos aqui lo lee ~/scripts/pantalla-watch.sh para restaurarlo tal
# cual cuando vuelvas a enchufar el cable. Linea 1: la regla de monitor completa
# (con su ",mirror,eDP-1" si toca). Linea 2: la posicion, para los workspaces.
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}"
MODO="$CACHE/pantalla-modo"

guardar_modo() {
    printf '%s\n%s\n' "$1" "$2" > "$MODO" 2>/dev/null || true
}

ROJO='\033[0;31m'
VERDE='\033[0;32m'
AMARILLO='\033[1;33m'
AZUL='\033[0;34m'
NEGRITA='\033[1m'
NC='\033[0m'

# ===================== DETECCION DE SESION ==========================
detectar_sesion() {
    # Prioridad: variable de entorno, luego herramientas disponibles
    if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || pgrep -x Hyprland >/dev/null 2>&1; then
        echo "wayland"
    elif [ -n "${WAYLAND_DISPLAY:-}" ] && [ -z "${DISPLAY:-}" ]; then
        echo "wayland"
    elif [ -n "${DISPLAY:-}" ] && command -v bspc >/dev/null 2>&1; then
        echo "x11"
    elif [ -n "${DISPLAY:-}" ]; then
        echo "x11"
    else
        # Fallback: detectar por lo que este instalado
        if command -v hyprctl >/dev/null 2>&1; then
            echo "wayland"
        elif command -v bspc >/dev/null 2>&1; then
            echo "x11"
        else
            echo "none"
        fi
    fi
}

SESION=$(detectar_sesion)

if [ "$SESION" = "none" ]; then
    echo -e "${ROJO}Error: no se detecta sesion grafica (ni X11 ni Wayland).${NC}"
    exit 1
fi

# Mensaje informativo solo en modo interactivo
if [ "$#" -eq 0 ]; then
    if [ "$SESION" = "wayland" ]; then
        echo -e "${AZUL}[sesion: Wayland/Hyprland]${NC}"
    else
        echo -e "${AZUL}[sesion: X11/bspwm]${NC}"
    fi
fi

# ===================== DETECCION DE HERRAMIENTAS =====================
if [ "$SESION" = "wayland" ]; then
    if ! command -v wlr-randr >/dev/null 2>&1; then
        echo -e "${ROJO}Error: wlr-randr no esta instalado.${NC}"
        echo -e "${AMARILLO}Instala con: sudo pacman -S wlr-randr${NC}"
        exit 1
    fi
    if ! command -v hyprctl >/dev/null 2>&1; then
        echo -e "${ROJO}Error: hyprctl no esta disponible (Hyprland no instalado).${NC}"
        exit 1
    fi
    if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        echo -e "${ROJO}Error: no estas en una sesion Hyprland activa.${NC}"
        exit 1
    fi
else
    if ! command -v xrandr >/dev/null 2>&1; then
        echo -e "${ROJO}Error: xrandr no esta instalado.${NC}"
        exit 1
    fi
    if [ -z "${DISPLAY:-}" ]; then
        echo -e "${ROJO}Error: no estas en una sesion grafica X11 (DISPLAY vacio).${NC}"
        exit 1
    fi
fi

# ===================== FUNCIONES ESPECIFICAS =========================
# HDMI fisicamente presente (aunque este deshabilitado, p.ej. tras -L)
detectar_hdmi() {
    if [ "$SESION" = "wayland" ]; then
        hyprctl monitors all -j 2>/dev/null \
            | jq -e --arg ext "$EXTERNAL" 'any(.[]; .name == $ext)' >/dev/null 2>&1 \
            || wlr-randr 2>/dev/null | grep -q "^${EXTERNAL} "
    else
        xrandr --query | grep -q "^${EXTERNAL} connected"
    fi
}

# HDMI presente Y activo (encendido)
hdmi_activa() {
    if [ "$SESION" = "wayland" ]; then
        hyprctl monitors all -j 2>/dev/null \
            | jq -e --arg ext "$EXTERNAL" \
              'any(.[]; .name == $ext and (.disabled | not))' >/dev/null 2>&1
    else
        xrandr --query | sed -n "/^${EXTERNAL} connected/,/^[^ ]/p" | grep -q '\*'
    fi
}

# Aborta con mensaje claro si no hay HDMI conectado
requiere_hdmi() {
    if ! detectar_hdmi; then
        echo -e "${ROJO}Error: no se detecta el HDMI (${EXTERNAL}).${NC}"
        echo -e "${AMARILLO}Conecta el cable HDMI y vuelve a intentar.${NC}"
        exit 1
    fi
}

estado() {
    echo ""
    if detectar_hdmi; then
        if hdmi_activa; then
            echo -e "HDMI: ${VERDE}CONECTADA (activa)${NC}"
        else
            echo -e "HDMI: ${AMARILLO}CONECTADA (apagada — usa una opcion para encenderla)${NC}"
        fi
        if [ "$SESION" = "wayland" ]; then
            wlr-randr 2>/dev/null | awk -v ext="$EXTERNAL" '
                $0 !~ /^ / && $1 == ext {p=1; print; next}
                $0 !~ /^ / {p=0}
                p {print}
            ' | head -10
        else
            xrandr --query | grep -A2 "^${EXTERNAL}" | tail -n +2
        fi
    else
        echo -e "HDMI: ${ROJO}DESCONECTADA${NC}"
    fi
    echo ""
}

# Resoluciones disponibles (wayland devuelve por linea "1920x1080")
elegir_resolucion() {
    local salida="$1"
    local resoluciones
    if [ "$SESION" = "wayland" ]; then
        resoluciones=$(wlr-randr 2>/dev/null | awk -v s="$salida" '
            $0 !~ /^ / && $1 == s {p=1; next}
            $0 !~ /^ / {p=0}
            p && $1 ~ /^[0-9]+x[0-9]+$/ {print $1}
        ' | awk '!seen[$0]++')
    else
        resoluciones=$(xrandr --query | sed -n "/^${salida} connected/,/^[^ ]/p" \
            | grep -oE '[0-9]+x[0-9]+' | awk '!seen[$0]++')
    fi

    local opts=("auto")
    if [ -n "$resoluciones" ]; then
        while IFS= read -r r; do
            opts+=("$r")
        done <<< "$resoluciones"
    fi

    local total=${#opts[@]}

    echo "Resoluciones disponibles:" >&2
    echo "  1) auto (recomendado)" >&2
    local i=2
    for ((idx=1; idx<total; idx++)); do
        echo "  $i) ${opts[$idx]}" >&2
        i=$((i+1))
    done
    echo "" >&2

    local opcion
    read -rp "Elige resolucion [1-$total] (Enter = 1 = auto): " opcion
    opcion="${opcion:-1}"
    if ! [[ "$opcion" =~ ^[0-9]+$ ]] || [ "$opcion" -lt 1 ] || [ "$opcion" -gt "$total" ]; then
        echo "auto"
        return
    fi
    echo "${opts[$((opcion-1))]}"
}

# Aplica desktops en el WM
# pos = "izquierda"  -> HDMI = 1-5 (primary), laptop = 6-10
# pos = "derecha|arriba|abajo" -> laptop = 1-5 (primary), HDMI = 6-10
# pos = "clonar" -> solo laptop, 1-5
setup_wm() {
    local pos="$1"

    if [ "$SESION" = "wayland" ]; then
        # Hyprland: usar hyprctl para configurar monitores y workspaces
        # El EXTERNAL ya lo configuro aplicar_xrandr (resolucion y posicion
        # relativa auto-left/right/up/down); aqui solo aseguramos el interno
        # en su base sin pisar la resolucion elegida para el HDMI.
        hyprctl keyword monitor "$INTERNAL,preferred,auto,1" >/dev/null 2>&1
        # Reaplicar workspaces (los ya estaban en hyprland.conf, esto es recordatorio).
        # En clonar/solo-laptop los 6-10 se quedan en el portatil: mandarlos a un
        # HDMI espejado (o ausente) solo sirve para perder ventanas de vista.
        local destino="$EXTERNAL"
        case "$pos" in
            clonar) destino="$INTERNAL" ;;
        esac
        for ws in 1 2 3 4 5; do
            hyprctl keyword workspace "$ws,monitor:$INTERNAL" >/dev/null 2>&1 || true
        done
        for ws in 6 7 8 9 10; do
            hyprctl keyword workspace "$ws,monitor:$destino" >/dev/null 2>&1 || true
        done
        return 0
    fi

    # X11 + bspwm
    if ! command -v bspc >/dev/null 2>&1; then
        return
    fi

    # Purga cualquier monitor de bspwm que ya no exista en xrandr
    for m in $(bspc query -M --names 2>/dev/null); do
        if ! xrandr --query | grep -q "^${m} connected"; then
            bspc monitor "$m" --remove >/dev/null 2>&1 || true
        fi
    done

    case "$pos" in
        izquierda)
            xrandr --output "$EXTERNAL" --primary
            bspc monitor "$EXTERNAL" -d 1 2 3 4 5
            bspc monitor "$INTERNAL" -d 6 7 8 9 10
            bspc wm -O "$EXTERNAL" "$INTERNAL"
            ;;
        derecha|arriba|abajo)
            xrandr --output "$INTERNAL" --primary
            bspc monitor "$INTERNAL" -d 1 2 3 4 5
            bspc monitor "$EXTERNAL" -d 6 7 8 9 10
            bspc wm -O "$INTERNAL" "$EXTERNAL"
            ;;
        clonar)
            xrandr --output "$INTERNAL" --primary
            bspc monitor "$EXTERNAL" --remove 2>/dev/null || true
            bspc monitor "$INTERNAL" -d 1 2 3 4 5
            ;;
    esac
}

# Reaplica wallpaper + barra despues de un cambio de monitor
reaplicar_visuales() {
    if [ "$SESION" = "wayland" ]; then
        # Reaplicar wallpaper con awww/swww
        if [ -x "$HOME/.config/hypr/scripts/wallpaper.sh" ]; then
            ( "$HOME/.config/hypr/scripts/wallpaper.sh" >/dev/null 2>&1 ) &
        fi
        # Reiniciar waybar para que detecte los nuevos monitores
        pkill -x waybar 2>/dev/null || true
        sleep 0.3
        nohup waybar -c "$HOME/.config/waybar/config.jsonc" -s "$HOME/.config/waybar/style.css" >/dev/null 2>&1 &
    else
        # X11
        if [ -f "${HOME}/.fehbg" ] && command -v feh >/dev/null 2>&1; then
            ( sh "${HOME}/.fehbg" >/dev/null 2>&1 ) &
        fi
        if [ -x "${HOME}/.config/bspwm/bin/WallSync" ]; then
            ( "${HOME}/.config/bspwm/bin/WallSync" >/dev/null 2>&1 ) &
        fi
        pkill -x polybar 2>/dev/null || true
        sleep 0.3
        if [ -f "${HOME}/.config/bspwm/.rice" ]; then
            RICE=$(cat "${HOME}/.config/bspwm/.rice")
            if [ -f "${HOME}/.config/bspwm/rices/$RICE/Bar.bash" ]; then
                ( . "${HOME}/.config/bspwm/rices/$RICE/Bar.bash" >/dev/null 2>&1 ) &
            fi
        fi
    fi
    return 0
}

# Aplica el cambio de salida (xrandr o wlr-randr)
aplicar_xrandr() {
    local pos="$1"
    local res="$2"
    local flag="--right-of"
    case "$pos" in
        izquierda) flag="--left-of"  ;;
        arriba)    flag="--above"    ;;
        abajo)     flag="--below"    ;;
        clonar)    flag="--same-as"  ;;
    esac

    if [ "$SESION" = "wayland" ]; then
        # Hyprland NO acepta "auto" como resolucion (solo como posicion):
        # normalizar a "preferred" o el keyword falla con "invalid resolution"
        if [ "$res" = "auto" ] || [ -z "$res" ]; then
            res="preferred"
        fi
        local regla
        case "$pos" in
            izquierda) regla="$EXTERNAL,$res,auto-left,1"  ;;
            derecha)   regla="$EXTERNAL,$res,auto-right,1" ;;
            arriba)    regla="$EXTERNAL,$res,auto-up,1"    ;;
            abajo)     regla="$EXTERNAL,$res,auto-down,1"  ;;
            # Espejo nativo de Hyprland: HDMI muestra lo mismo que el laptop
            clonar)    regla="$EXTERNAL,$res,auto,1,mirror,$INTERNAL" ;;
        esac
        # Aplicar la regla tambien LEVANTA el monitor si estaba en "disable":
        # es la unica forma de deshacer un apagado anterior, porque las reglas de
        # hyprctl duran toda la sesion y se reaplican por nombre al reconectar.
        hyprctl keyword monitor "$regla" >/dev/null 2>&1
        guardar_modo "$regla" "$pos"
        setup_wm "$pos"
        reaplicar_visuales
        return
    fi

    if [ "$pos" = "clonar" ]; then
        if [ "$res" = "auto" ] || [ -z "$res" ]; then
            xrandr --output "$EXTERNAL" --auto "$flag" "$INTERNAL"
        else
            xrandr --output "$EXTERNAL" --mode "$res" "$flag" "$INTERNAL"
        fi
    else
        if [ "$res" = "auto" ] || [ -z "$res" ]; then
            xrandr --output "$EXTERNAL" --auto "$flag" "$INTERNAL"
        else
            xrandr --output "$EXTERNAL" --mode "$res" "$flag" "$INTERNAL"
        fi
    fi
    setup_wm "$pos"
    reaplicar_visuales
}

solo_laptop() {
    if [ "$SESION" = "wayland" ]; then
        # Wayland: antes de deshabilitar el monitor externo, mover
        # todas sus ventanas a un workspace del laptop (5).
        local monitor_id
        monitor_id=$(hyprctl monitors -j 2>/dev/null \
            | jq -r --arg ext "$EXTERNAL" '.[] | select(.name == $ext) | .id' \
            | head -1)
        if [ -n "$monitor_id" ] && [ "$monitor_id" != "null" ]; then
            hyprctl clients -j 2>/dev/null \
                | jq -r --argjson mid "$monitor_id" '.[] | select(.monitor == $mid) | .address' \
                | while read -r addr; do
                    [ -n "$addr" ] && hyprctl dispatch movetoworkspacesilent "address:$addr,5" >/dev/null 2>&1
                done
        fi
        # El "disable" SOLO si el cable esta puesto. Las reglas de hyprctl duran
        # toda la sesion y se reaplican por nombre cuando el monitor aparece: un
        # disable escrito con el cable fuera dejaria la pantalla negra al volver a
        # enchufarla dentro de una hora, sin nada que lo explicara. Sin cable no
        # hay nada que apagar, asi que no se escribe la regla.
        if detectar_hdmi; then
            hyprctl keyword monitor "$EXTERNAL,disable" >/dev/null 2>&1
        fi
        sleep 0.3
        hyprctl keyword monitor "$INTERNAL,preferred,auto,1" >/dev/null 2>&1
        setup_wm "clonar"
        reaplicar_visuales
        return
    fi

    # X11
    if command -v bspc >/dev/null 2>&1; then
        if bspc query -M --names 2>/dev/null | grep -qx "${EXTERNAL}"; then
            bspc monitor "$INTERNAL" -d 1 2 3 4 5 >/dev/null 2>&1 || true
            local node
            for node in $(bspc query -N -m "$EXTERNAL" .leaf 2>/dev/null); do
                bspc node "$node" -d 5 --follow >/dev/null 2>&1 || true
            done
        fi
    fi

    xrandr --output "$EXTERNAL" --off
    sleep 0.5

    if command -v bspc >/dev/null 2>&1; then
        if xrandr --query | grep -q "^${INTERNAL} connected"; then
            xrandr --output "$INTERNAL" --primary
            bspc monitor "$EXTERNAL" --remove >/dev/null 2>&1 || true
            bspc monitor "$INTERNAL" -d 1 2 3 4 5
            bspc wm -O "$INTERNAL"
        fi
        reaplicar_visuales
    fi
}

monitor_only() {
    requiere_hdmi
    if [ "$SESION" = "wayland" ]; then
        # Encender el HDMI PRIMERO; si fallara, nunca apagar el laptop
        hyprctl keyword monitor "$EXTERNAL,preferred,auto,1" >/dev/null 2>&1
        sleep 0.5
        if ! hdmi_activa; then
            echo -e "${ROJO}El HDMI no se activo; NO se apaga la pantalla del laptop.${NC}"
            return 1
        fi
        hyprctl keyword monitor "$INTERNAL,disable" >/dev/null 2>&1
        for ws in 1 2 3 4 5; do
            hyprctl keyword workspace "$ws,monitor:$EXTERNAL" >/dev/null 2>&1 || true
        done
        # Guardamos una posicion normal, no este modo: si desenchufas el cable
        # estando asi, pantalla-watch.sh reenciende el portatil (si no, te
        # quedarias sin ninguna pantalla) y al reenchufar vuelve a un reparto util.
        guardar_modo "$EXTERNAL,preferred,auto,1" "derecha"
        reaplicar_visuales
    else
        xrandr --output "$EXTERNAL" --primary --output "$INTERNAL" --off
        if command -v bspc >/dev/null 2>&1; then
            bspc monitor "$EXTERNAL" -d 1 2 3 4 5
            bspc wm -O "$EXTERNAL"
        fi
        reaplicar_visuales
    fi
    echo -e "${VERDE}Monitor externo activo, laptop apagada.${NC}"
    echo -e "${AMARILLO}Puedes cerrar la laptop.${NC}"
    echo ""
    echo "Para permitir cerrar la tapa sin suspender, ejecuta:"
    echo "  sudo systemctl edit systemd-logind.conf"
    echo "Y agrega:"
    echo "  [Login]"
    echo "  HandleLidSwitch=ignore"
    echo ""
    echo "Luego reinicia: sudo systemctl restart systemd-logind"
}

# Deshace cualquier apagado y vuelve al reparto normal (HDMI a la derecha).
# Es la salida de emergencia si una regla vieja dejo algo apagado: reaplicar una
# regla de monitor es lo unico que levanta un "disable" anterior.
restaurar() {
    if [ "$SESION" != "wayland" ]; then
        xrandr --output "$INTERNAL" --auto --primary
        if detectar_hdmi; then
            xrandr --output "$EXTERNAL" --auto --right-of "$INTERNAL"
            setup_wm derecha
        else
            setup_wm clonar
        fi
        reaplicar_visuales
        echo -e "${VERDE}Pantallas restauradas.${NC}"
        return 0
    fi

    hyprctl keyword monitor "$INTERNAL,preferred,auto,1" >/dev/null 2>&1
    if detectar_hdmi; then
        hyprctl keyword monitor "$EXTERNAL,preferred,auto-right,1" >/dev/null 2>&1
        guardar_modo "$EXTERNAL,preferred,auto-right,1" "derecha"
        setup_wm derecha
        sleep 0.3
        if hdmi_activa; then
            echo -e "${VERDE}Pantallas restauradas: laptop = 1-5, HDMI = 6-10${NC}"
        else
            echo -e "${AMARILLO}El HDMI sigue sin encender. Revisa el cable.${NC}"
        fi
    else
        setup_wm clonar
        echo -e "${VERDE}Solo laptop (no hay HDMI conectado). desktops 1-5${NC}"
    fi
    reaplicar_visuales
    return 0
}

confirmar() {
    local msg="$1"
    read -rp "$msg [s/N]: " r
    [[ "$r" =~ ^[sSyY]$ ]]
}

menu() {
    echo -e "${AZUL}${NEGRITA}=================================${NC}"
    echo -e "${AZUL}${NEGRITA}   GESTOR DE PANTALLAS - HDMI    ${NC}"
    echo -e "${AZUL}${NEGRITA}=================================${NC}"
    estado

    if ! detectar_hdmi; then
        echo -e "${AMARILLO}No se detecta HDMI.${NC}"
        solo_laptop
        echo -e "${VERDE}Solo laptop activa. desktops 1-5${NC}"
        echo ""
        echo "0) Salir"
        read -rp "Opcion: " _
        exit 0
    fi

    echo "Que quieres hacer?"
    echo ""
    echo "  1) Solo laptop (pantalla principal)  -> apaga HDMI, laptop con desktops 1-5"
    echo "  2) HDMI a la IZQUIERDA de la laptop  -> HDMI = 1-5 (primary), laptop = 6-10"
    echo "  3) HDMI a la DERECHA de la laptop   -> laptop = 1-5 (primary), HDMI = 6-10"
    echo "  4) HDMI ARRIBA de la laptop          -> laptop = 1-5 (primary), HDMI = 6-10"
    echo "  5) HDMI ABAJO de la laptop           -> laptop = 1-5 (primary), HDMI = 6-10"
    echo "  6) Clonar pantalla (espejo)"
    echo "  7) Elegir resolucion del HDMI manualmente"
    echo "  8) Listar todas las salidas"
    echo "  9) Restaurar todo (enciende lo que este apagado)"
    echo "  0) Salir"
    echo ""
    read -rp "Elige una opcion [0-9]: " op
    echo ""

    case "$op" in
        1) solo_laptop
           echo -e "${VERDE}Pantalla principal: laptop. desktops 1-5${NC}" ;;
        2) res=$(elegir_resolucion "$EXTERNAL")
           aplicar_xrandr izquierda "$res"
           echo -e "${VERDE}HDMI a la izquierda. HDMI = 1-5, laptop = 6-10${NC}" ;;
        3) res=$(elegir_resolucion "$EXTERNAL")
           aplicar_xrandr derecha "$res"
           echo -e "${VERDE}HDMI a la derecha. laptop = 1-5, HDMI = 6-10${NC}" ;;
        4) res=$(elegir_resolucion "$EXTERNAL")
           aplicar_xrandr arriba "$res"
           echo -e "${VERDE}HDMI arriba. laptop = 1-5, HDMI = 6-10${NC}" ;;
        5) res=$(elegir_resolucion "$EXTERNAL")
           aplicar_xrandr abajo "$res"
           echo -e "${VERDE}HDMI abajo. laptop = 1-5, HDMI = 6-10${NC}" ;;
        6) res=$(elegir_resolucion "$EXTERNAL")
           aplicar_xrandr clonar "$res"
           echo -e "${VERDE}HDMI clonando laptop. desktops 1-5${NC}" ;;
        7) res=$(elegir_resolucion "$EXTERNAL")
           if [ "$SESION" = "wayland" ]; then
               # Ojo: esto era `[ a ] || [ b ] && res=...`, que con `set -e` mataba
               # el script sin decir nada en cuanto elegias una resolucion concreta
               # (la lista entera devolvia 1 y no habia nadie comprobandola).
               if [ "$res" = "auto" ] || [ -z "$res" ]; then res="preferred"; fi
               hyprctl keyword monitor "$EXTERNAL,$res,auto-right,1" >/dev/null 2>&1
               guardar_modo "$EXTERNAL,$res,auto-right,1" "derecha"
           elif [ "$res" = "auto" ]; then
               xrandr --output "$EXTERNAL" --auto
           else
               xrandr --output "$EXTERNAL" --mode "$res"
           fi
           echo -e "${VERDE}HDMI configurado en ${res}.${NC}" ;;
        8) if [ "$SESION" = "wayland" ]; then
               wlr-randr
           else
               xrandr --query
           fi ;;
        9) restaurar ;;
        0) echo "Adios."; exit 0 ;;
        *) echo -e "${ROJO}Opcion invalida.${NC}" ;;
    esac
    echo ""
}

if [ "$#" -gt 0 ]; then
    case "$1" in
        -d|--derecha)   requiere_hdmi; aplicar_xrandr derecha auto ;;
        -i|--izquierda) requiere_hdmi; aplicar_xrandr izquierda auto ;;
        -a|--arriba)    requiere_hdmi; aplicar_xrandr arriba auto ;;
        -b|--abajo)     requiere_hdmi; aplicar_xrandr abajo auto ;;
        -c|--clonar)    requiere_hdmi; aplicar_xrandr clonar auto ;;
        -L|--laptop)    solo_laptop ;;
        -o|--off)       solo_laptop ;;
        -m|--monitor)   monitor_only ;;
        -r|--restaurar) restaurar ;;
        -s|--status)    estado ;;
        -l|--listar)
            if [ "$SESION" = "wayland" ]; then wlr-randr; else xrandr --query; fi
            ;;
        -h|--help)
            echo "Uso: pantalla.sh [opciones]"
            echo "  Sin opcion -> menu interactivo"
            echo "  -L  Solo laptop (apaga HDMI)"
            echo "  -i  HDMI a la IZQUIERDA  -> HDMI = 1-5, laptop = 6-10"
            echo "  -d  HDMI a la DERECHA   -> laptop = 1-5, HDMI = 6-10"
            echo "  -a  HDMI ARRIBA         -> laptop = 1-5, HDMI = 6-10"
            echo "  -b  HDMI ABAJO          -> laptop = 1-5, HDMI = 6-10"
            echo "  -c  Clonar"
            echo "  -o  Apagar HDMI (laptop 1-5)"
            echo "  -m  Solo monitor (laptop apagada, cerrar tapa)"
            echo "  -r  Restaurar todo (enciende lo que este apagado)"
            echo "  -s  Ver estado"
            echo "  -l  Listar salidas"
            echo ""
            echo "El cable manda: ~/scripts/pantalla-watch.sh enciende el HDMI solo"
            echo "cuando lo enchufas, aunque antes lo hubieras apagado con -L."
            echo "Auto-detecta sesion: Wayland (wlr-randr+hyprctl) o X11 (xrandr+bspc)."
            ;;
        *) echo "Opcion desconocida: $1 (usa -h para ayuda)" ;;
    esac
    exit 0
fi

while true; do
    menu
    echo "Pulsa Enter para SALIR (o escribe 'm' y Enter para volver al menu)..."
    read -r r
    if [ -z "$r" ] || [ "$r" = "s" ] || [ "$r" = "S" ] || [ "$r" = "q" ] || [ "$r" = "Q" ]; then
        echo "Adios."
        exit 0
    fi
done
