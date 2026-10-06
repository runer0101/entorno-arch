#!/bin/bash
# Analiza ~/.local/state/bateria.log y saca solo lo que merece mirarse.
# El log lo escribe waybar-battery en cada refresco (10 s).
#
#   bateria-log.sh            → anomalías de las últimas 24 h
#   bateria-log.sh 72         → anomalías de las últimas 72 h
#   bateria-log.sh 24 todo    → además, la traza completa de cada anomalía
#
# Campos del log: ts  status  ac  vcell  vadj  vsmooth  cap  cap_fw

set -u
LOG="${XDG_STATE_HOME:-$HOME/.local/state}/bateria.log"
HORAS=${1:-24}
MODO=${2:-}

if [ ! -s "$LOG" ]; then
    echo "No hay log todavía en $LOG (¿waybar corriendo?)"
    exit 1
fi

DESDE=$(( $(date +%s) - HORAS * 3600 ))

awk -F'\t' -v desde="$DESDE" -v modo="$MODO" '
function hora(t) { return strftime("%d %b %H:%M:%S", t) }
function pad(s, n) { return sprintf("%-*s", n, s) }

$1 >= desde {
    n++
    ts[n]=$1; st[n]=$2; ac[n]=$3; vc[n]=$4; va[n]=$5; vs[n]=$6; cap[n]=$7; fw[n]=$8
}

END {
    if (n < 2) { print "Muy pocas muestras en la ventana."; exit }

    printf "Ventana: %s  ->  %s   (%d muestras)\n", hora(ts[1]), hora(ts[n]), n
    printf "%s\n\n", "════════════════════════════════════════════════════════════"

    # ── 1. Saltos del porcentaje mostrado ──
    # Con la mediana de 3 min, el % no deberia moverse mas de 2-3 puntos entre
    # muestras consecutivas. Mas que eso es que algo se salto el suavizado.
    print "▸ SALTOS DEL % (>4 puntos entre muestras seguidas)"
    saltos = 0
    for (i = 2; i <= n; i++) {
        d = cap[i] - cap[i-1]
        if (d < 0) d = -d
        hueco = ts[i] - ts[i-1]
        if (d > 4 && hueco <= 60) {
            saltos++
            printf "  %s  %3d%% -> %3d%%  (%+d)  %s -> %s  V %s -> %s\n",
                   hora(ts[i]), cap[i-1], cap[i], cap[i]-cap[i-1],
                   st[i-1], st[i], vs[i-1], vs[i]
            if (modo == "todo") {
                for (j = (i-6 > 1 ? i-6 : 1); j <= (i+6 < n ? i+6 : n); j++)
                    printf "        %s  %-12s ac=%s vcell=%s vadj=%s vsuav=%s  %s%%\n",
                           hora(ts[j]), st[j], ac[j], vc[j], va[j], vs[j], cap[j]
                print ""
            }
        }
    }
    if (!saltos) print "  ninguno"
    print ""

    # ── 2. Flapping de status ──
    # Al enchufar/desenchufar el firmware manda status contradictorios durante
    # ~1 min. Es normal en este equipo; se lista para descartarlo como causa.
    print "▸ FLAPPING DE STATUS (3+ cambios en 90 s)"
    flaps = 0
    for (i = 2; i <= n; i++) {
        if (st[i] == st[i-1]) continue
        c = 1; j = i
        while (j < n && ts[j+1] - ts[i] <= 90) { j++; if (st[j] != st[j-1]) c++ }
        if (c >= 3) {
            flaps++
            printf "  %s  %d cambios en %ds  (ac=%s)\n", hora(ts[i]), c, ts[j]-ts[i], ac[i]
            i = j
        }
    }
    if (!flaps) print "  ninguno"
    print ""

    # ── 3. Huecos de registro ──
    print "▸ HUECOS (>5 min sin muestras: suspensión, waybar caída, apagado)"
    huecos = 0
    for (i = 2; i <= n; i++) {
        g = ts[i] - ts[i-1]
        if (g > 300) {
            huecos++
            printf "  %s  ->  %s   (%d min)\n", hora(ts[i-1]), hora(ts[i]), g/60
        }
    }
    if (!huecos) print "  ninguno"
    print ""

    # ── 4. Contraste con el firmware ──
    print "▸ FIRMWARE vs VOLTAJE"
    dmax = 0; imax = 0; sum = 0
    for (i = 1; i <= n; i++) {
        d = fw[i] - cap[i]; if (d < 0) d = -d
        sum += d
        if (d > dmax) { dmax = d; imax = i }
    }
    printf "  desvío medio %.0f puntos, máximo %d puntos\n", sum/n, dmax
    if (imax) printf "  peor caso: %s  firmware %s%% vs voltaje %s%%  (%s V/celda, %s)\n",
                     hora(ts[imax]), fw[imax], cap[imax], vc[imax], st[imax]
    print ""

    # ── 5. Carga detenida antes de tiempo ──
    # El fallo de fondo de este pack: el cargador corta y el firmware dice Full.
    print "▸ CARGA DETENIDA POR DEBAJO DEL 85%"
    ult = ""
    for (i = 1; i <= n; i++) {
        if (ac[i] == 1 && st[i] == "Full" && cap[i] < 85) {
            k = int(ts[i] / 3600)
            if (k != ult) {
                printf "  %s  se planta en %s%% (%s V/celda) diciendo \"Full\"\n",
                       hora(ts[i]), cap[i], vc[i]
                ult = k
            }
        }
    }
    if (ult == "") print "  ninguno"
}
' "$LOG"
