#!/bin/sh
# =============================================================
#  iconos-originales.sh — genera el tema de iconos "Logos-Originales"
#
#  Los packs de iconos temáticos (TokyoNight-SE, Papirus...) redibujan los
#  logos de las aplicaciones con su propio estilo, y quedan versiones raras
#  del logo de Steam, Firefox, etc. Este tema recupera el icono ORIGINAL que
#  cada programa instala en /usr/share/icons/hicolor/*/apps y deja el resto
#  (carpetas, acciones, simbólicos) al pack que toque.
#
#  Por qué enlaza los directorios en vez de heredar "hicolor": si pones
#  hicolor delante en Inherits, GTK corta ahí la cadena y los iconos de
#  interfaz caen a los internos de GTK, que son horribles. Metiendo los
#  logos DENTRO del tema, ganan sin romper nada detrás.
#
#  Uso: iconos-originales.sh <tema-padre>      (p.ej. TokyoNight-SE)
# =============================================================

PARENT="${1:-TokyoNight-SE}"
THEME_NAME="Logos-Originales"
THEME="$HOME/.local/share/icons/$THEME_NAME"

# Si el padre no existe, no hay nada que envolver: mejor no tocar nada.
for base in "$HOME/.local/share/icons" "$HOME/.icons" /usr/share/icons; do
    [ -d "$base/$PARENT" ] && found=1
done
[ -n "$found" ] || exit 1

# Solo contiene enlaces + index.theme, así que se puede rehacer entero.
rm -rf "$THEME"
mkdir -p "$THEME"

dirs=""
for d in /usr/share/icons/hicolor/*/apps; do
    [ -d "$d" ] || continue
    size=$(basename "$(dirname "$d")")
    case "$size" in *@2) continue ;; esac   # las variantes @2 las deriva GTK
    mkdir -p "$THEME/$size"
    ln -sfn "$d" "$THEME/$size/apps"
    dirs="${dirs}${size}/apps,"
done
# Alias: apps cuyo .desktop pide un nombre que su propio paquete no instala en
# hicolor/*/apps. VirtualBox, por ejemplo, pide "virtualbox" pero deja su logo
# en hicolor/*/mimetypes, asi que sin esto ganaba el pack. Formato:
#   nombre-que-pide-el-desktop|patron-de-ruta-con-NN-por-el-tamano
# Se enlaza cada tamano disponible, asi que no hay reescalados feos.
ALIAS="virtualbox|/usr/share/icons/hicolor/NNxNN/mimetypes/virtualbox.png"

for entry in $ALIAS; do
    name=${entry%%|*}
    pattern=${entry#*|}
    for size in 16 20 22 24 32 36 40 48 64 72 96 128 192 256 384 512; do
        src=$(echo "$pattern" | sed "s/NNxNN/${size}x${size}/")
        [ -f "$src" ] || continue
        # Directorio propio: los de hicolor son enlaces al sistema y no
        # admiten anadir ficheros dentro.
        mkdir -p "$THEME/alias-${size}x${size}/apps"
        ln -sfn "$src" "$THEME/alias-${size}x${size}/apps/${name}.${src##*.}"
    done
done
for d in "$THEME"/alias-*/apps; do
    [ -d "$d" ] || continue
    dirs="${dirs}$(basename "$(dirname "$d")")/apps,"
done

# /usr/share/pixmaps es la ubicacion antigua donde algunas apps siguen dejando
# su icono (Alacritty, nvidia-settings, vscode, ipython). GTK ya la mira, pero
# DESPUES de los temas, asi que el pack ganaba igual; metida aqui gana el
# original. Son 16 ficheros y todos son logos de apps, no hay riesgo de pisar
# iconos de interfaz.
if [ -d /usr/share/pixmaps ]; then
    ln -sfn /usr/share/pixmaps "$THEME/pixmaps"
    dirs="${dirs}pixmaps,"
fi

dirs=${dirs%,}
[ -n "$dirs" ] || { rm -rf "$THEME"; exit 1; }

{
    echo "[Icon Theme]"
    echo "Name=$THEME_NAME"
    echo "Comment=Logos originales de cada app sobre $PARENT"
    echo "# Generado por iconos-originales.sh — no editar a mano."
    echo "Inherits=$PARENT,hicolor"
    echo "Directories=$dirs"
    echo
    for d in $(echo "$dirs" | tr ',' ' '); do
        size=${d%%/*}
        echo "[$d]"
        echo "Context=Applications"
        case "$size" in
            scalable) printf 'Size=48\nMinSize=8\nMaxSize=512\nType=Scalable\n\n' ;;
            symbolic) printf 'Size=16\nMinSize=8\nMaxSize=512\nType=Scalable\n\n' ;;
            # Mezcla de tamanos reales (32 a 1024 px). Escalable con tope
            # para que GTK no estire un PNG de 32 px a 128 y salga borroso.
            pixmaps)  printf 'Size=48\nMinSize=24\nMaxSize=256\nType=Scalable\n\n' ;;
            alias-*)  n=${size#alias-}; printf 'Size=%s\nType=Fixed\n\n' "${n%%x*}" ;;
            *)        printf 'Size=%s\nType=Fixed\n\n' "${size%%x*}" ;;
        esac
    done
} > "$THEME/index.theme"

echo "$THEME_NAME"
