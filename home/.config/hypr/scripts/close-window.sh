#!/usr/bin/env bash
# Win+X inteligente: Waydroid se detiene con "session stop" porque window.close
# crashea el hwcomposer de Android (bug waydroid 1.6.3). El resto cierra normal.
ACTIVE=$(hyprctl activewindow -j)
CLASS=$(echo "$ACTIVE" | jq -r '.class // empty')

if [ "$CLASS" = "Waydroid" ]; then
    waydroid session stop
else
    # Hyprland 0.56 + config Lua: dispatch string clásico roto, va vía API Lua
    hyprctl dispatch 'hl.dsp.window.close("activewindow")'
fi
