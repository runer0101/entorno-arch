#!/usr/bin/env bash
set -euo pipefail

show_help() {
    cat <<'EOF'
Uso: info_wifi [opciones]

Muestra información detallada de la conexión Wi-Fi actual
(incluyendo la contraseña en texto plano).
Requiere permisos root para leer la contraseña (te los pide con sudo).

Opciones:
  --copy        Copiar la contraseña al portapapeles (wl-copy o xclip)
  --no-color    Desactivar colores en la salida
  -h, --help    Mostrar esta ayuda

Ejemplos:
  info_wifi                # Mostrar toda la info + contraseña
  info_wifi --copy         # Ídem y copiar al portapapeles
EOF
}

# ── Colors ─────────────────────────────────────────────
setup_colors() {
    if [[ -z "${NO_COLOR:-}" ]] && [[ -t 1 ]]; then
        if command -v tput &>/dev/null && tput setaf 1 &>/dev/null; then
            BOLD=$(tput bold)
            RED=$(tput setaf 1)
            GREEN=$(tput setaf 2)
            YELLOW=$(tput setaf 3)
            CYAN=$(tput setaf 6)
            RESET=$(tput sgr0)
        else
            BOLD='\033[1m'
            RED='\033[31m'
            GREEN='\033[32m'
            YELLOW='\033[33m'
            CYAN='\033[36m'
            RESET='\033[0m'
        fi
    else
        BOLD=''; RED=''; GREEN=''; YELLOW=''; CYAN=''; RESET=''
    fi
}

# ── Flag parsing ──────────────────────────────────────
COPY_TO_CLIPBOARD=false
FLAGS=()

parse_flags() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --copy)      COPY_TO_CLIPBOARD=true; FLAGS+=("$1") ;;
            --no-color)  export NO_COLOR=1; FLAGS+=("$1") ;;
            -h|--help)   show_help; exit 0 ;;
            -*)
                echo "Opción desconocida: $1" >&2
                show_help
                exit 1
                ;;
        esac
        shift
    done
}

# ── Non-root → re-exec with sudo ──────────────────────
if [ "$(id -u)" -ne 0 ]; then
    parse_flags "$@"
    SSID=""

    # 1) iw (rápido, no escanea)
    if command -v iw &>/dev/null; then
        IFACE=$(iw dev 2>/dev/null | awk '/Interface/{print $2}' | head -n 1)
        if [ -n "$IFACE" ]; then
            SSID=$(iw dev "$IFACE" link 2>/dev/null | sed -n 's/.*SSID: //p')
        fi
    fi

    # 2) nmcli (usa caché si está fresco)
    if [ -z "$SSID" ] && command -v nmcli &>/dev/null; then
        SSID=$(LC_ALL=C nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null \
            | sed -n 's/^yes://p' | head -n 1)
    fi

    # 3) iwgetid (wireless-tools)
    if [ -z "$SSID" ] && command -v iwgetid &>/dev/null; then
        SSID=$(iwgetid -r 2>/dev/null)
    fi

    # 4) wpa_cli (wpa_supplicant)
    if [ -z "$SSID" ] && command -v wpa_cli &>/dev/null; then
        SSID=$(wpa_cli status 2>/dev/null | sed -n 's/^ssid=//p')
    fi

    # 5) iwctl (iwd)
    if [ -z "$SSID" ] && command -v iwctl &>/dev/null; then
        IFACE=$(iwctl station list 2>/dev/null | awk '/station/{print $1}' | head -n 1)
        if [ -n "$IFACE" ]; then
            SSID=$(iwctl station "$IFACE" show 2>/dev/null \
                | sed -n 's/.*Connected network[[:space:]]*//p')
        fi
    fi

    if [ -z "$SSID" ]; then
        echo "[-] Error: No estás conectado a ninguna red Wi-Fi." >&2
        exit 1
    fi

    # Mejora: NetworkManager permite leer la contraseña sin root. Si nmcli la
    # obtiene, evitamos pedir sudo por completo; solo lo usamos como respaldo
    # (por ejemplo para leer /etc/NetworkManager si nmcli no la tuviera).
    if command -v nmcli &>/dev/null && \
       nmcli -s -g 802-11-wireless-security.psk connection show "$SSID" 2>/dev/null | grep -q .; then
        set -- "$SSID" "${FLAGS[@]}"    # continuar SIN root
    else
        exec sudo "$0" "$SSID" "${FLAGS[@]}"
    fi
fi

# ═══════════════════════════════════════════════════════
# ROOT: toda la extracción de datos
# ═══════════════════════════════════════════════════════
SSID="$1"
shift
COPY_TO_CLIPBOARD=false
for arg in "$@"; do
    case "$arg" in
        --copy)     COPY_TO_CLIPBOARD=true ;;
        --no-color) export NO_COLOR=1 ;;
    esac
done

setup_colors

# ── Interface ──────────────────────────────────────────
INTERFAZ=""
if command -v iw &>/dev/null; then
    INTERFAZ=$(iw dev 2>/dev/null | awk '/Interface/{print $2}' | head -n 1)
fi
if [ -z "$INTERFAZ" ] && command -v nmcli &>/dev/null; then
    INTERFAZ=$(LC_ALL=C nmcli -t -f DEVICE,TYPE device 2>/dev/null \
        | sed -n 's/:wifi$//p' | head -n 1)
fi
[ -z "$INTERFAZ" ] && INTERFAZ="N/A"

# ── Signal, Channel, BSSID, Band ──────────────────────
SENAL="Desconocida"
BSSID=""
BANDA=""
SEGURIDAD=""
IP_ADDR=""
HAVE_IW=false
command -v iw &>/dev/null && HAVE_IW=true

if [ "$INTERFAZ" != "N/A" ] && $HAVE_IW; then
    LINK_INFO=$(iw dev "$INTERFAZ" link 2>/dev/null || true)

    # Signal (dBm → % aproximado)
    SIG_DBM=$(echo "$LINK_INFO" | sed -n 's/.*signal: -\([0-9]*\).*/\1/p')
    if [ -n "$SIG_DBM" ]; then
        QUAL=$(( 100 - (SIG_DBM - 30) * 100 / 60 ))
        [ "$QUAL" -lt 0 ] && QUAL=0
        [ "$QUAL" -gt 100 ] && QUAL=100
    fi

    # BSSID
    BSSID=$(echo "$LINK_INFO" | sed -n 's/.*Connected to \([0-9a-f:]\{17\}\).*/\1/p')

    # Channel & Frequency
    INFO=$(iw dev "$INTERFAZ" info 2>/dev/null || true)
    CHAN=$(echo "$INFO" | sed -n 's/.*channel \([0-9]*\).*/\1/p')
    FREQ=$(echo "$INFO" | sed -n 's/.*channel [0-9]* (\([0-9]*\).*/\1/p')

    if [ -n "$FREQ" ]; then
        if   [ "$FREQ" -lt 2500 ]; then BANDA="2.4 GHz"
        elif [ "$FREQ" -lt 5900 ]; then BANDA="5 GHz"
        elif [ "$FREQ" -lt 7200 ]; then BANDA="6 GHz"
        else BANDA="${FREQ} MHz"
        fi
    fi

    if [ -n "${QUAL:-}" ] && [ -n "$CHAN" ]; then
        SENAL="${QUAL}% (Canal: ${CHAN})"
    elif [ -n "$CHAN" ]; then
        SENAL="?% (Canal: ${CHAN})"
    fi
fi

# Signal fallback vía nmcli (sin rescan, usa caché)
if [ "$SENAL" = "Desconocida" ] && command -v nmcli &>/dev/null; then
    RAW=$(LC_ALL=C nmcli -t -f IN-USE,SIGNAL,CHAN dev wifi list --rescan no 2>/dev/null \
        | sed -n 's/^\*://p' | head -n 1)
    if [ -n "$RAW" ]; then
        SIG=$(echo "$RAW" | cut -d':' -f1)
        CH=$(echo "$RAW"  | cut -d':' -f2)
        [ -n "$SIG" ] && [ -n "$CH" ] && SENAL="${SIG}% (Canal: ${CH})"
    fi
fi

# BSSID fallback vía nmcli
if [ -z "$BSSID" ] && command -v nmcli &>/dev/null; then
    BSSID=$(LC_ALL=C nmcli -t -f ACTIVE,BSSID dev wifi list --rescan no 2>/dev/null \
        | sed -n 's/^yes://p' | head -n 1)
fi
[ -z "$BSSID" ] && BSSID="N/A"
[ -z "$BANDA" ] && BANDA="N/A"

# ── IP ─────────────────────────────────────────────────
if [ "$INTERFAZ" != "N/A" ]; then
    if command -v ip &>/dev/null; then
        IP_ADDR=$(ip -4 -br addr show dev "$INTERFAZ" 2>/dev/null \
            | awk '{print $3}' | cut -d'/' -f1)
    fi
    # Fallback con nmcli
    if [ -z "$IP_ADDR" ] && command -v nmcli &>/dev/null; then
        IP_ADDR=$(LC_ALL=C nmcli -t -f IP4.ADDRESS device show "$INTERFAZ" 2>/dev/null \
            | sed -n 's/.*:\/.*[[:space:]]\{1,\}//p' | head -n 1)
    fi
fi
[ -z "$IP_ADDR" ] && IP_ADDR="N/A"

# ── Security type ──────────────────────────────────────
if command -v nmcli &>/dev/null; then
    SEGURIDAD=$(LC_ALL=C nmcli -g 802-11-wireless-security.key-mgmt \
        connection show "$SSID" 2>/dev/null | head -n1 || true)
fi
[ -z "$SEGURIDAD" ] && SEGURIDAD="Desconocido"

# ── Password ───────────────────────────────────────────
PASSWORD=""

get_nmcli_field() {
    local field="$1" con="$2"
    # nmcli a veces repite el valor (perfiles duplicados); tomar solo el 1º
    LC_ALL=C nmcli -s -g "$field" connection show "$con" 2>/dev/null | head -n1 || true
}

if command -v nmcli &>/dev/null; then
    PASSWORD=$(get_nmcli_field "802-11-wireless-security.psk" "$SSID")
    [ -z "$PASSWORD" ] && \
        PASSWORD=$(get_nmcli_field "802-11-wireless-security.wep-key0" "$SSID")
fi

# Fallback: leer archivos de NetworkManager
if [ -z "$PASSWORD" ] && [ -d /etc/NetworkManager/system-connections/ ]; then
    while IFS= read -r -d '' archivo; do
        if grep -Fxq "id=$SSID" "$archivo" 2>/dev/null; then
            PASSWORD=$(sed -n 's/^psk=//p' "$archivo")
            break
        fi
    done < <(find /etc/NetworkManager/system-connections/ -type f -print0 2>/dev/null)
fi

# ── Display ────────────────────────────────────────────
HEADER="  DATOS DE LA CONEXIÓN ACTUAL  "
SEP=$(printf '%*s' "${#HEADER}" '' | tr ' ' '=')
SEP2=$(printf '%*s' "${#HEADER}" '' | tr ' ' '-')

field() {
    printf "  ${BOLD}%-18s${RESET} %s\n" "$1:" "$2"
}

echo
echo "${BOLD}${SEP}${RESET}"
echo "${BOLD}${HEADER}${RESET}"
echo "${BOLD}${SEP}${RESET}"
echo

field "Interfaz"     "${GREEN}${INTERFAZ}${RESET}"
field "Red (SSID)"   "${CYAN}${SSID}${RESET}"
field "BSSID"        "${YELLOW}${BSSID}${RESET}"
field "Banda"        "${BANDA}${RESET}"
field "Seguridad"    "${SEGURIDAD}${RESET}"
field "Señal/Canal"  "${SENAL}${RESET}"
field "IP (IPv4)"    "${IP_ADDR}${RESET}"

echo
echo "${BOLD}${SEP2}${RESET}"

if [ -n "$PASSWORD" ]; then
    field "Contraseña" "${GREEN}${PASSWORD}${RESET}"
else
    echo
    field "Contraseña" "${RED}No encontrada (red abierta o empresarial)${RESET}"
fi

echo
echo "${BOLD}${SEP}${RESET}"
echo

# ── Clipboard ──────────────────────────────────────────
if $COPY_TO_CLIPBOARD && [ -n "$PASSWORD" ]; then
    COPIED=false
    if command -v wl-copy &>/dev/null; then
        printf '%s' "$PASSWORD" | wl-copy 2>/dev/null && COPIED=true
    elif command -v xclip &>/dev/null; then
        printf '%s' "$PASSWORD" | xclip -selection clipboard 2>/dev/null && COPIED=true
    fi
    if $COPIED; then
        echo "  ${GREEN} Contraseña copiada al portapapeles.${RESET}"
    else
        echo "  ${RED} No se pudo copiar (instalá wl-copy o xclip).${RESET}" >&2
    fi
    echo
fi
