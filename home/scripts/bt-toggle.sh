#!/usr/bin/env bash
# Botón único de Bluetooth para el panel de swaync: enciende/apaga la radio y,
# al encenderla, abre directamente el gestor de dispositivos.
#
# swaync exporta SWAYNC_TOGGLE_STATE con el estado NUEVO del interruptor.
# Se usa script en vez de un `sh -c '...'` en config.json porque swaync no
# procesa bien las comillas dobles anidadas en ese campo.

set -u

if [ "${SWAYNC_TOGGLE_STATE:-false}" = true ]; then
    rfkill unblock bluetooth 2>/dev/null
    bluetoothctl power on >/dev/null 2>&1

    # Esperar a que el adaptador esté realmente encendido: si lanzamos el menú
    # antes, BluetoothDM lista cero dispositivos.
    for _ in $(seq 20); do
        bluetoothctl show 2>/dev/null | grep Powered | grep -q yes && break
        sleep 0.1
    done

    # Cerrar el panel para que el menú de wofi quede visible y con el foco.
    swaync-client -cp -sw
    exec BluetoothDM
else
    bluetoothctl power off >/dev/null 2>&1
fi
