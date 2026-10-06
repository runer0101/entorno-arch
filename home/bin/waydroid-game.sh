#!/usr/bin/env bash
# waydroid-game.sh — Arrancar Waydroid con un juego (Saint Seiya, etc.) y
# dejar un vigilante que apague el contenedor cuando ya no estés jugando.
#
# USO:
#   waydroid-game.sh                          # solo abre Waydroid UI
#   waydroid-game.sh com.tencent.tmgp.sskeus   # abre Saint Seiya directo
#============================================================

set -euo pipefail

PKG="${1:-}"
LOCK="/tmp/waydroid-game.lock"
WATCHDOG_PID_FILE="/tmp/waydroid-watchdog.pid"
LOG="$HOME/.config/waydroid-custom/logs/session.log"

mkdir -p "$(dirname "$LOG")"

_ts() { date '+%Y-%m-%d %H:%M:%S'; }
log() { printf '[%s] %s\n' "$(_ts)" "$*" | tee -a "$LOG" >&2; }

# ---------- Lock para no duplicar sesiones ----------
exec 9>"$LOCK"
if ! flock -n 9; then
  log "Ya hay otra sesión Waydroid activa (lock $LOCK)."
  exit 0
fi

# ---------- Helper: esperar a que systemctl diga activo ----------
wait_active() {
  local unit="$1" max="${2:-30}"
  for ((i=1; i<=max; i++)); do
    if systemctl is-active --quiet "$unit"; then return 0; fi
    sleep 1
  done
  return 1
}

# ---------- 1. Contenedor ----------
if ! systemctl -q is-active waydroid-container.service 2>/dev/null; then
  log "▶ Iniciando contenedor Waydroid (sudo)..."
  if ! sudo systemctl start waydroid-container.service; then
    log "✗ No pude iniciar el contenedor. ¿Tienes sudo configurado?"
    exit 1
  fi
  wait_active waydroid-container.service 30 || {
    log "✗ El contenedor no levantó en 30s"
    exit 1
  }
fi

# ---------- 2. Sesión Android ----------
if ! waydroid status 2>/dev/null | grep -q "Session:.*RUNNING"; then
  log "▶ Iniciando sesión Android..."
  nohup waydroid session start >/dev/null 2>&1 &
  for ((i=1; i<=30; i++)); do
    if waydroid status 2>/dev/null | grep -q "Session:.*RUNNING"; then break; fi
    sleep 1
  done
fi

# ---------- 3. Lanzar juego o UI ----------
if [[ -n "$PKG" ]]; then
  log "▶ Lanzando $PKG..."
  nohup waydroid app launch "$PKG" >/dev/null 2>&1 &
else
  log "▶ Abriendo Waydroid UI..."
  # Forzar la aparición de la ventana
  if command -v waydroid-gui >/dev/null; then
    nohup waydroid-gui >/dev/null 2>&1 &
  else
    # Fallback — el watchman creará ventana cuando sea necesario
    :
  fi
fi

# ---------- 4. Lanzar watchdog en background ----------
if [[ -f "$WATCHDOG_PID_FILE" ]] && kill -0 "$(cat "$WATCHDOG_PID_FILE")" 2>/dev/null; then
  log "▶ Watchdog ya estaba corriendo (PID $(cat "$WATCHDOG_PID_FILE"))"
else
  nohup "$HOME/bin/waydroid-watchdog.sh" "$PKG" >/dev/null 2>&1 &
  echo $! > "$WATCHDOG_PID_FILE"
  log "▶ Watchdog iniciado (PID $(cat "$WATCHDOG_PID_FILE"))"
fi

log "✓ Listo. Para apagar: SUPER+X o 'waydroid-stop'."
exit 0