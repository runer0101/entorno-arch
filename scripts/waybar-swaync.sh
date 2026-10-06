#!/usr/bin/env bash
# Módulo waybar para swaync (notificaciones).
#
# Por qué no usamos `swaync-client -swb`: esa salida NO dice si el panel de
# notificaciones está abierto. Ese dato solo viaja por D-Bus, en la señal
# SubscribeV2 → (count, dnd, cc_open, inhibited). Aquí la escuchamos y la
# traducimos a clases CSS.
#
# Clases que emite:
#   cc-open      → panel abierto (icono blanco)
#   dnd          → modo silencio
#   notification → hay notificaciones sin leer
#   none         → normal
#   dead         → swaync no está corriendo (el botón no engaña)

set -u

DEST=org.erikreider.swaync.cc
OBJ=/org/erikreider/swaync/cc

emit() {
    local count=$1 dnd=$2 cc=$3
    local class icon

    if [ "$cc" = "true" ]; then
        class="cc-open"
    elif [ "$dnd" = "true" ]; then
        class="dnd"
    elif [ "${count:-0}" -gt 0 ] 2>/dev/null; then
        class="notification"
    else
        class="none"
    fi

    # En silencio mantenemos la campana tachada; el resto usa el glifo de siempre.
    if [ "$dnd" = "true" ]; then icon="󰂛"; else icon="󰗃"; fi

    printf '{"text":"%s","class":"%s"}\n' "$icon" "$class"
}

# swaync caído. Antes esto no existía: el script solo emitía al recibir
# SubscribeV2, así que si swaync moría el icono se congelaba en su último estado
# (típicamente cc-open, blanco y fijo) mientras los clics no hacían nada.
emit_dead() {
    printf '{"text":"󰗃","class":"dead"}\n'
}

# Estado real preguntando al daemon. GetSubscribeData devuelve:
# (bbub) dnd cc_open count inhibited — ojo, orden distinto al de SubscribeV2.
# Si el nombre es activable por D-Bus esta llamada además levanta swaync, que es
# justo lo que queremos al arrancar waybar.
query() {
    local out i_dnd i_cc i_count
    if out=$(busctl --user call "$DEST" "$OBJ" "$DEST" GetSubscribeData 2>/dev/null); then
        read -r _ i_dnd i_cc i_count _ <<< "$out"
        emit "${i_count:-0}" "${i_dnd:-false}" "${i_cc:-false}"
    else
        emit_dead
    fi
}

mon_pid=""
trap '[ -n "$mon_pid" ] && kill "$mon_pid" 2>/dev/null; exit 0' EXIT INT TERM HUP

# Bucle externo: si gdbus se cae (reinicio del bus, cierre del monitor) volvemos
# a levantarlo en vez de quedarnos mudos para siempre.
while :; do
    # Sustitución de proceso en vez de tubería: así conservamos el PID de gdbus y
    # lo podemos matar al salir. Con `gdbus | while` el monitor quedaba huérfano
    # (reparentado a init) cada vez que waybar recargaba, acumulando procesos.
    exec 3< <(gdbus monitor --session --dest "$DEST" --object-path "$OBJ" 2>/dev/null)
    mon_pid=$!

    query

    while read -r line <&3; do
        case "$line" in
            # gdbus anuncia los cambios de dueño del nombre aunque filtremos por
            # object-path. Son nuestra señal de que swaync murió o volvió.
            *"does not have an owner"*)
                emit_dead
                ;;
            *"is owned by"*)
                query
                ;;
            *SubscribeV2*)
                args=${line#*SubscribeV2 (}
                args=${args%)}
                args=${args//uint32 /}
                IFS=', ' read -r count dnd cc _ <<< "$args"
                emit "$count" "$dnd" "$cc"
                ;;
        esac
    done

    exec 3<&-
    kill "$mon_pid" 2>/dev/null
    wait "$mon_pid" 2>/dev/null
    mon_pid=""
    sleep 2
done
