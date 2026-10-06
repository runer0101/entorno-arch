#!/bin/bash
# Espera a Waydroid y lo pone fullscreen en workspace 2
sleep 3
WINDOW=$(hyprctl clients -j | python3 -c "
import json, sys
for w in json.load(sys.stdin):
    if w.get('class') == 'Waydroid':
        print(w['address'])
        break
")
if [ -n "$WINDOW" ]; then
    hyprctl dispatch movetoworkspacesilent 2 address:$WINDOW
    hyprctl dispatch fullscreen 1 address:$WINDOW
fi
