#!/bin/bash
# =============================================================
# fix-laptop-kbd.sh — Workaround para teclado HP Omen laptop
#
# Problema: el EC (Embedded Controller) del HP Omen entra en un
# estado donde solo transmite el scan code 0xe0 0x2b (tecla fantasma)
# en lugar de los scan codes reales del teclado, bloqueando todas
# las teclas. El setkeycodes silencia la tecla fantasma para
# reducir el spam en dmesg.
#
# Causa real: bug de firmware del EC. Solución definitiva:
# reiniciar la laptop (power cycle resetea el EC) o entrar a BIOS.
# =============================================================

set -e

# 1. Re-bind atkbd para forzar re-detección
if [ -d /sys/bus/serio/drivers/atkbd ]; then
    if [ -L /sys/bus/serio/drivers/atkbd/serio0 ]; then
        echo serio0 > /sys/bus/serio/drivers/atkbd/unbind 2>/dev/null || true
        sleep 1
        echo serio0 > /sys/bus/serio/drivers/atkbd/bind 2>/dev/null || true
        sleep 1
    fi
fi

# 2. Silenciar tecla fantasma 0xe0 0x2b (HP Omen EC bug)
#    Mapea a keycode 240 (KEY_UNKNOWN) para que no se retransmita
if command -v setkeycodes >/dev/null 2>&1; then
    setkeycodes e02b 240 2>/dev/null || true
fi

# 3. Verificar
if ls /dev/input/event* 2>/dev/null | xargs -I {} cat /sys/class/input/$(basename {})/device/name 2>/dev/null | grep -q "AT Translated"; then
    echo "AT Translated Set 2 keyboard: detectado"
else
    echo "AT Translated Set 2 keyboard: NO DETECTADO"
fi
