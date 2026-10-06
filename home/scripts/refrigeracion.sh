#!/usr/bin/env bash
# =============================================================================
# refrigeracion.sh — Control seguro de ventiladores (HP Victus) vía nbfc
# =============================================================================
# Uso:
#   refrigeracion.sh              Menú interactivo
#   refrigeracion.sh status       Mostrar estado y salir
#   refrigeracion.sh auto         Volver a control automático (BIOS) y salir
#   refrigeracion.sh set N        Fijar ventiladores en N% (25-100) y vigilar
#   refrigeracion.sh max          Ventiladores al 100% y vigilar
#
# SEGURIDAD (lo más importante):
#   - Al fijar una velocidad manual, el script se QUEDA vigilando en primer
#     plano. Al salir por CUALQUIER vía (tecla q, Ctrl+C, cerrar la terminal,
#     error), un 'trap' devuelve los ventiladores a AUTOMÁTICO. Nunca se
#     quedan fijos por olvido.
#   - Piso mínimo de 25%: no se permite bajar de ahí para no sobrecalentar.
#   - Vigilancia térmica: si la CPU pasa de 85°C sube solo a 100%; si pasa de
#     90°C devuelve el control a la BIOS (más agresiva) y avisa.
# =============================================================================
set -uo pipefail

MIN_FAN=25          # % mínimo permitido (seguridad)
TEMP_BUMP=85        # °C: forzar 100%
TEMP_PANIC=90       # °C: devolver a automático
REFRESH=2           # s entre lecturas

R='\033[1;31m'; G='\033[1;32m'; Y='\033[1;33m'; C='\033[1;36m'; B='\033[1m'; N='\033[0m'
msg(){ printf "${C}▶${N} %s\n" "$*"; }
ok(){ printf "${G}✔${N} %s\n" "$*"; }
warn(){ printf "${Y}!${N} %s\n" "$*"; }
err(){ printf "${R}✖${N} %s\n" "$*" >&2; }

# ---- Comprobaciones ----
command -v nbfc >/dev/null 2>&1 || { err "nbfc no está instalado (pacman -S nbfc o AUR)"; exit 1; }
if ! systemctl is-active --quiet nbfc_service; then
    err "El servicio nbfc_service no está activo. Actívalo con:"
    echo "    sudo systemctl enable --now nbfc_service"
    exit 1
fi

# ---- Lecturas ----
get_temp(){ sensors -j 2>/dev/null | jq -r '.["k10temp-pci-00c3"].Tctl.temp1_input // 0' | cut -d. -f1; }
get_rpm(){ sensors -j 2>/dev/null | jq -r '.["hp-isa-0000"] | "\(.fan1.fan1_input // 0 | floor) / \(.fan2.fan2_input // 0 | floor)"'; }
is_auto(){ nbfc status 2>/dev/null | grep -q 'Auto Control Enabled *: *true'; }

# ---- Estado de seguridad ----
MANUAL_ACTIVE=0     # 1 cuando nosotros fijamos velocidad manual

restore_auto(){
    # Devuelve SIEMPRE a automático si nosotros tocamos los ventiladores.
    if [ "$MANUAL_ACTIVE" -eq 1 ]; then
        nbfc set -a >/dev/null 2>&1
        MANUAL_ACTIVE=0
        printf "\n${G}✔ Ventiladores devueltos a modo AUTOMÁTICO (seguro).${N}\n"
    fi
}
trap 'restore_auto; exit' INT TERM HUP
trap 'restore_auto' EXIT

mostrar_estado(){
    local t rpm modo
    t=$(get_temp); rpm=$(get_rpm)
    is_auto && modo="${G}AUTOMÁTICO${N}" || modo="${Y}MANUAL${N}"
    printf "${B}Estado de refrigeración${N}\n"
    printf "  Modo         : %b\n" "$modo"
    printf "  Temp CPU     : %s°C\n" "$t"
    printf "  Ventiladores : %s RPM\n" "$rpm"
}

# ---- Bucle de vigilancia mientras hay velocidad manual ----
vigilar(){
    local objetivo="$1"
    MANUAL_ACTIVE=1
    nbfc set -s "$objetivo" >/dev/null 2>&1
    ok "Ventiladores fijados en ${objetivo}%."
    msg "Vigilando… pulsa ${B}q${N} (o Ctrl+C) para volver a automático."
    while true; do
        local t rpm; t=$(get_temp); rpm=$(get_rpm)
        printf "\r  ${B}%s%%${N} fijo  │  CPU ${B}%s°C${N}  │  %s RPM        " "$objetivo" "$t" "$rpm"
        # Protección térmica
        if [ "$t" -ge "$TEMP_PANIC" ]; then
            printf "\n"; err "¡${t}°C! Devolviendo a la BIOS (más agresiva)."
            restore_auto; return
        elif [ "$t" -ge "$TEMP_BUMP" ] && [ "$objetivo" -lt 100 ]; then
            objetivo=100; nbfc set -s 100 >/dev/null 2>&1
            printf "\n"; warn "${t}°C: subiendo a 100% por seguridad."
        fi
        # Espera REFRESH s o hasta que pulsen una tecla
        if read -rsn1 -t "$REFRESH" key 2>/dev/null; then
            [ "$key" = "q" ] && { printf "\n"; return; }
        fi
    done
}

fijar(){
    local n="$1"
    [[ "$n" =~ ^[0-9]+$ ]] || { err "Valor inválido: $n"; exit 1; }
    if [ "$n" -lt "$MIN_FAN" ]; then
        warn "Mínimo permitido: ${MIN_FAN}% (pediste ${n}%). Ajustado a ${MIN_FAN}%."
        n=$MIN_FAN
    fi
    [ "$n" -gt 100 ] && n=100
    vigilar "$n"
}

menu(){
    echo; mostrar_estado; echo
    printf "${B}¿Qué quieres hacer?${N}\n"
    echo "  1) Fijar un porcentaje (25-100%)"
    echo "  2) Ventiladores al máximo (100%)"
    echo "  3) Volver a automático (BIOS)"
    echo "  4) Ver estado"
    echo "  q) Salir"
    printf "Opción: "; read -r op
    case "$op" in
        1) printf "Porcentaje (25-100): "; read -r p; fijar "$p" ;;
        2) vigilar 100 ;;
        3) MANUAL_ACTIVE=1; restore_auto ;;
        4) mostrar_estado ;;
        q|Q) exit 0 ;;
        *) warn "Opción no válida" ;;
    esac
}

case "${1:-menu}" in
    status)  mostrar_estado ;;
    auto)    MANUAL_ACTIVE=1; restore_auto ;;
    max)     vigilar 100 ;;
    set)     fijar "${2:-}" ;;
    menu|"") menu ;;
    -h|--help) sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//' ;;
    *)       err "Comando desconocido: $1"; echo "Usa: refrigeracion.sh -h"; exit 1 ;;
esac
