#!/usr/bin/env bash
# waydroid-watchdog.sh — Vigila que Waydroid tenga juego + ventana visibles.
# Si durante más de GRACE segundos no hay ninguno, llama a waydroid-stop.
#============================================================

PKG="${1:-}"
GRACE="${GRACE:-20}"           # segundos de inactividad antes de apagar
INTERVAL="${INTERVAL:-5}"      # cada cuántos segundos poll
WATCHDOG_PID_FILE="/tmp/waydroid-watchdog.pid"

# Guardar nuestro propio PID por si waydroid-stop quiere matarnos
echo $$ > "$WATCHDOG_PID_FILE"
trap 'rm -f "$WATCHDOG_PID_FILE"; exit 0' EXIT INT TERM

LOG="$HOME/.config/waydroid-custom/logs/session.log"
mkdir -p "$(dirname "$LOG")"

_ts() { date '+%Y-%m-%d %H:%M:%S'; }
log() { printf '[%s][watchdog] %s\n' "$(_ts)" "$*" | tee -a "$LOG" >&2; }

log "Vigilando (paquete='${PKG:-ninguno}', grace=${GRACE}s, interval=${INTERVAL}s)"

last_busy_ts=$(date +%s)

is_game_running() {
  [[ -z "$PKG" ]] && return 1   # sin paquete, nunca es "running"
  # El game process vive en PID 1 dentro del contenedor; aquí solo podemos
  # buscar si hay algo lanzado por waydroid que coincida.
  pgrep -af "waydroid app launch" | grep -q "$PKG"
}

is_waydroid_window_visible() {
  command -v hyprctl >/dev/null || return 1
  hyprctl clients -j 2>/dev/null \
    | python3 -c "
import json, sys
try:
  cs = json.load(sys.stdin)
  print(any('waydroid' in (c.get('class') or '').lower()
                 or 'waydroid' in (c.get('title') or '').lower()
                 for c in cs))
except Exception:
  print(False)
" | grep -qi true
}

is_container_active() {
  systemctl -q is-active waydroid-container.service 2>/dev/null
}

while true; do
  sleep "$INTERVAL"

  # Si el contenedor ya no existe, terminamos
  if ! is_container_active; then
    log "Contenedor ya no está activo, watchdog terminando"
    exit 0
  fi

  game_ok=0
  window_ok=0

  is_game_running && game_ok=1
  is_waydroid_window_visible && window_ok=1

  if (( game_ok || window_ok )); then
    last_busy_ts=$(date +%s)
    continue
  fi

  now=$(date +%s)
  idle=$(( now - last_busy_ts ))
  if (( idle >= GRACE )); then
    log "Sin juego ni ventana Waydroid durante ${idle}s — apagando"
    # Llamada idempotente; si ya está apagado no rompe
    if ! "$HOME/bin/waydroid-stop" --quiet 2>/dev/null; then
      log "No pude apagar automáticamente. Apaga con SUPER+X."
    fi
    exit 0
  fi
done