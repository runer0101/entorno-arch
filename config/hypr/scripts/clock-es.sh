#!/bin/bash
# =============================================================
# clock-es — Reloj/fecha en español con toggle
# Default: HH:MM · Click (on-click) toggle a fecha completa
# =============================================================

export LC_TIME=es_ES.UTF-8
export LANG=es_ES.UTF-8
export LC_ALL=es_ES.UTF-8

TOGGLE_FILE="$HOME/.cache/clock-toggle"
[ ! -f "$TOGGLE_FILE" ] && echo 0 > "$TOGGLE_FILE"
TOGGLE=$(cat "$TOGGLE_FILE" 2>/dev/null || echo 0)

TIME=$(date +"%H:%M")
DATE=$(date +"%A %d de %B")

case "$1" in
    time)
        date +"%H:%M"
        ;;
    date)
        date +"%a %d %b"
        ;;
    full)
        date +"%A %d de %B de %Y"
        ;;
    toggle)
        # usado por on-click: invierte el estado
        if [ "$TOGGLE" = "1" ]; then
            echo 0 > "$TOGGLE_FILE"
        else
            echo 1 > "$TOGGLE_FILE"
        fi
        ;;
    json)
        # ── Mini-calendario del mes en el tooltip (texto monoespaciado) ──
        # Pango no soporta <img>; cal + resaltado del día es lo que rinde bien.
        D=$(date +%-d)
        CAL=$(cal | sed 's/[[:space:]]*$//')
        # Resalta el día de hoy (solo en la grilla, no en el encabezado)
        CAL=$(echo "$CAL" | sed -E "3,\$ s/(^|[[:space:]])(${D})([[:space:]]|\$)/\1<span background='#e0af68' foreground='#1a1b26'>\2<\/span>\3/")
        # Encabezado (mes año) en color acento, días de semana atenuados
        CAL=$(echo "$CAL" | sed -E "1s|.*|<span foreground='#bb9af7'><b>&</b></span>|; 2s|.*|<span foreground='#565f89'>&</span>|")
        TOOLTIP="<span font_family='JetBrainsMono Nerd Font'>${CAL}</span>"

        if [ "$TOGGLE" = "1" ]; then
            TEXT="$DATE"
        else
            TEXT="$TIME"
        fi
        jq -c -n --arg text "$TEXT" --arg tip "$TOOLTIP" \
            '{text: $text, tooltip: $tip, class: "clock"}'
        ;;
    *)
        date +"%H:%M"
        ;;
esac
