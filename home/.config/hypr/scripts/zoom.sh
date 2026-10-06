#!/bin/sh
# =============================================================
# Lupa / zoom de pantalla — equivalente a la lupa de Windows
# Usa el zoom nativo de Hyprland (cursor:zoom_factor), sigue al cursor
#
# El OSD lo pinta zoom-osd.py, que se ancla al cursor: swayosd se
# quedaba fuera de la region visible en cuanto ampliabas, porque el
# zoom amplia toda la salida. Si el daemon no esta, cae a swayosd.
#
# Binds: super + {+,-} (y el numerico) | CTRL + rueda | reset: shift
# =============================================================

STEP=0.25
MAX=5.0
MIN=1.0
FIFO=/tmp/zoom-osd.fifo

actual=$(hyprctl getoption cursor:zoom_factor -j | jq '.float')

case "$1" in
    +)  nuevo=$(echo "$actual $STEP $MAX" | awk '{v=$1+$2; print (v>$3)?$3:v}') ;;
    -)  nuevo=$(echo "$actual $STEP $MIN" | awk '{v=$1-$2; print (v<$3)?$3:v}') ;;
    1|reset) nuevo=$MIN ;;
    *)  exit 1 ;;
esac

# 'keyword' no funciona con config Lua (parser no-legado); hay que usar eval
hyprctl eval "hl.config({ cursor = { zoom_factor = $nuevo } })" >/dev/null

if [ -p "$FIFO" ]; then
    echo "$nuevo" > "$FIFO" &
else
    # Fallback: OSD fijo (solo se ve bien sin zoom o con zoom bajo)
    prog=$(echo "$nuevo $MIN $MAX" | awk '{printf "%.3f", ($1-$2)/($3-$2)}')
    txt=$(echo "$nuevo" | awk '{printf "%d%%", $1*100}')
    swayosd-client --custom-icon edit-find \
                   --custom-progress "$prog" \
                   --custom-progress-text "$txt"
fi
