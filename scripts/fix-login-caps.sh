#!/usr/bin/env bash
# fix-login-caps.sh — evita repetir el bloqueo de cuenta del 22 jul 2026.
#
# Hace dos cosas:
#  A) Suaviza pam_faillock: 5 intentos (antes 3) y 1 min de bloqueo (antes 10).
#  B) Vía nativa del LED de Caps Lock (diagnóstico jul 8-9): desactiva el
#     daemon led-caps (probablemente INVERTÍA el LED), quita las dos reglas
#     udev (una hardcodeaba input2, que ya no existe; la otra hacía rebinds
#     que cambian la numeración) y ordena fix-laptop-kbd ANTES de SDDM.
#
# Uso:  sudo bash fix-login-caps.sh aplicar
#       sudo bash fix-login-caps.sh revertir
set -euo pipefail

BK="__HOME__/.backups/capslock-cleanup-20260722"
MODO="${1:-}"

aplicar() {
  mkdir -p "$BK"

  # A) faillock más tolerante
  cp -n /etc/security/faillock.conf "$BK/faillock.conf"
  sed -i -E 's/^#?\s*deny\s*=.*/deny = 5/' /etc/security/faillock.conf
  grep -qE '^deny = 5' /etc/security/faillock.conf || printf '\ndeny = 5\n' >> /etc/security/faillock.conf
  sed -i -E 's/^#?\s*unlock_time\s*=.*/unlock_time = 60/' /etc/security/faillock.conf
  grep -qE '^unlock_time = 60' /etc/security/faillock.conf || printf 'unlock_time = 60\n' >> /etc/security/faillock.conf

  # B1) daemon led-caps fuera (los archivos quedan por si hay que revertir)
  systemctl disable --now led-caps.service

  # B2) reglas udev fuera (a backup)
  for r in 99-capslock-led.rules 99-rebind-atkbd.rules; do
    [ -f "/etc/udev/rules.d/$r" ] && mv "/etc/udev/rules.d/$r" "$BK/$r"
  done
  udevadm control --reload

  # B3) trigger nativo del kernel en el LED real (sea cual sea su número)
  for led in /sys/class/leds/input*::capslock; do
    echo kbd-capslock > "$led/trigger" 2>/dev/null || true
  done

  # B4) el rebind del teclado debe terminar ANTES de que arranque SDDM
  mkdir -p /etc/systemd/system/fix-laptop-kbd.service.d
  printf '[Unit]\nBefore=display-manager.service\n' > /etc/systemd/system/fix-laptop-kbd.service.d/before-dm.conf
  systemctl daemon-reload

  echo "== Verificación =="
  grep -E '^(deny|unlock_time)' /etc/security/faillock.conf
  systemctl is-enabled led-caps.service || true
  ls /etc/udev/rules.d/ | grep -E 'caps|atkbd' || echo "(sin reglas udev de caps/atkbd — correcto)"
  grep -H . /sys/class/leds/input*::capslock/trigger | grep -o '\[.*\]' || true
  echo "Listo. Backup en $BK"
}

revertir() {
  [ -f "$BK/faillock.conf" ] && cp "$BK/faillock.conf" /etc/security/faillock.conf
  for r in 99-capslock-led.rules 99-rebind-atkbd.rules; do
    [ -f "$BK/$r" ] && mv "$BK/$r" "/etc/udev/rules.d/$r"
  done
  udevadm control --reload
  rm -f /etc/systemd/system/fix-laptop-kbd.service.d/before-dm.conf
  systemctl daemon-reload
  systemctl enable --now led-caps.service
  echo "Revertido."
}

case "$MODO" in
  aplicar)  aplicar ;;
  revertir) revertir ;;
  *) echo "Uso: sudo bash $0 {aplicar|revertir}"; exit 1 ;;
esac
