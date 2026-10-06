#!/bin/bash
exec >> /tmp/maximize-debug.log 2>&1
echo "--- $(date) ---"

if hyprctl activewindow -j | grep -q '"floating": true'; then
    echo "-> apagando floating"
    hyprctl eval 'hl.dispatch(hl.dsp.window.float({action="off"}))'
else
    W=$(hyprctl activewindow -j | python3 -c "import sys,json; print(json.load(sys.stdin)['size'][0])")
    H=$(hyprctl activewindow -j | python3 -c "import sys,json; print(json.load(sys.stdin)['size'][1])")
    echo "-> tamanho tiled: ${W}x${H}"
    hyprctl eval 'hl.dispatch(hl.dsp.window.float({action="on"}))'
    hyprctl eval "hl.dispatch(hl.dsp.window.resize({x=${W},y=${H},relative=false}))"
    echo "-> floating con tamaño tiled"
fi
