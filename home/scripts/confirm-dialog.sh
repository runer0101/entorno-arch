#!/usr/bin/env bash
# =============================================================
# Diálogo de confirmación reutilizable (rofi).
#
#   confirm-dialog.sh <titulo> <detalle> <etiqueta-del-si>
#
# Sale 0 SOLO si el usuario elige explícitamente el "Sí". Esc, cerrar la
# ventana, "Cancelar" o cualquier fallo de rofi salen != 0, así que quien
# llama nunca ejecuta la acción por accidente.
#
# El aviso va en un cuadro propio (-mesg) que NO se puede seleccionar: solo
# hay dos filas clicables. "Cancelar" queda seleccionado por defecto, así que
# pulsar Enter sin mirar no hace nada.
#
# Se usa rofi y no wofi porque wofi 1.5.3 no tiene filas no seleccionables
# (no existe --mesg) y el aviso acababa siendo una tercera opción clicable.
# =============================================================

set -u

titulo="${1:?falta el título}"
detalle="${2:?falta el detalle}"
etiqueta="${3:?falta la etiqueta del sí}"

# El mensaje admite marcado pango, así que hay que escapar lo que venga de
# fuera (p. ej. el nombre de una contraseña) o un & rompe el diálogo entero.
escapar() { printf '%s' "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'; }

no="󰜺  Cancelar"
si="󰄬  $etiqueta"
mensaje="<b>$(escapar "$titulo")</b>
$(escapar "$detalle")"

# Paleta de pywal, la misma que usan waybar y wofi: el diálogo sigue el fondo
# de pantalla. set +u durante el source porque colors.sh de pywal expande
# $FZF_DEFAULT_OPTS sin comprobar que exista, y con set -u aborta el script
# entero (el diálogo no llegaría a salir).
# shellcheck disable=SC1091
set +u
[ -f "$HOME/.cache/wal/colors.sh" ] && . "$HOME/.cache/wal/colors.sh"
set -u
: "${background:=#181818}" "${foreground:=#c5c5c5}"
: "${color5:=#282828}" "${color9:=#437E81}"

tema=$(mktemp --suffix=.rasi)
trap 'rm -f "$tema"' EXIT

# En un tema rasi independiente NADA hereda: cada contenedor sin
# background-color explícito lo pinta blanco. De ahí los "transparent".
cat > "$tema" <<EOF
* { font: "JetBrainsMono Nerd Font 13"; }

window { width: 720px; background-color: transparent; border: 0; padding: 0; }

/* Sin inputbar en children: no hay barra de búsqueda que estorbe */
mainbox {
    background-color: $background;
    border: 2px; border-color: $color9; border-radius: 15px;
    padding: 16px; spacing: 14px;
    children: [ message, listview ];
}

/* El aviso: cartel relleno y sin borde. Se lee como texto, no como botón. */
message {
    background-color: $color5;
    border: 0; border-radius: 12px;
    padding: 14px 16px;
}
textbox { background-color: transparent; text-color: $foreground; }

/* Las opciones: píldoras con borde, como los módulos de waybar */
listview {
    lines: 2; spacing: 10px; border: 0; scrollbar: false;
    background-color: transparent;
}
element {
    background-color: $background;
    border: 2px; border-color: $color9; border-radius: 12px;
    padding: 12px 16px;
    text-color: $foreground;
}
element selected {
    background-color: $color9;
    text-color: $background;
}
element-text, element-icon {
    background-color: transparent;
    text-color: inherit;
    vertical-align: 0.5;
}
EOF

respuesta=$(printf '%s\n%s\n' "$no" "$si" | rofi -dmenu \
    -theme "$tema" \
    -mesg "$mensaje" \
    -l 2 \
    -no-custom \
    -i)

[ "$respuesta" = "$si" ]
