#!/usr/bin/env bash
# entorno-arch — instalador del escritorio
# Reconstruye el entorno visual en Arch Linux.
#
#   ./install.sh            -> solo instala configs (backup previo automatico)
#   ./install.sh --packages -> ademas instala dependencias con pacman y pywal
#   ./install.sh --dry-run  -> muestra que haria, sin tocar nada
#
# Diseñado para ejecutarse justo despues de clonar:
#   git clone https://github.com/runer0101/entorno-arch.git && \
#     cd entorno-arch && ./install.sh --packages

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP=$(date +%Y%m%d-%H%M%S)
BACKUP="$HOME/.config-backups/$STAMP"

DO_PACKAGES=0
DRY_RUN=0

for arg in "$@"; do
    case "$arg" in
        --packages) DO_PACKAGES=1 ;;
        --dry-run)  DRY_RUN=1 ;;
        -h|--help)  sed -n '2,11p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'; exit 0 ;;
        *) echo "Opcion desconocida: $arg (usa --help)"; exit 1 ;;
    esac
done

info()  { printf '\033[36m::\033[0m %s\n' "$1"; }
ok()    { printf '\033[32m  ok\033[0m %s\n' "$1"; }
warn()  { printf '\033[33m  !!\033[0m %s\n' "$1"; }
err()   { printf '\033[31m xx\033[0m %s\n' "$1" >&2; }

# Sustituye el token de portabilidad __HOME__ por la ruta real del usuario.
# Necesario en config/, home/, scripts/, bin/, localbin/ y fonts/.
#
# Ojo con esto: grep devuelve 1 cuando NO encuentra nada. Con 'set -e' + pipefail
# eso abortaria el script entero en silencio justo aqui. Por eso se captura la
# salida con '|| true' y se comprueba antes de iterar.
substitute_paths() {
    local target="$1" encontrados
    encontrados=$(grep -rIl '__HOME__' "$target" 2>/dev/null || true)
    [[ -z "$encontrados" ]] && return 0
    while read -r f; do
        sed -i "s|__HOME__|$HOME|g" "$f"
    done <<< "$encontrados"
    return 0
}

# ---------------------------------------------------------------- plataforma
if [[ ! -f /etc/arch-release ]]; then
    warn "Esto no parece Arch Linux. Puede funcionar, pero no esta probado."
fi

# ------------------------------------------------------------- preflight
command -v rsync >/dev/null 2>&1 || {
    warn "Falta 'rsync', necesario para el instalador. Instalando..."
    sudo pacman -S --needed rsync
}

# No puede ejecutarse como root: crearia las configs en /root.
if [[ $EUID -eq 0 ]]; then
    echo "No ejecutes esto con sudo: instalaria las configs en /root." >&2
    exit 1
fi

# -------------------------------------------------------------- backup
backup_existing() {
    local what="$1" src="$2"
    [[ -e "$src" ]] || return 0
    if [[ $DRY_RUN -eq 1 ]]; then
        info "backup: $src"
        return 0
    fi
    mkdir -p "$BACKUP/$(dirname "${src#$HOME/}")"
    cp -a "$src" "$BACKUP/${src#$HOME/}" 2>/dev/null && ok "backup de $what"
}

info "Los cambios que ya tengas en ~/.config se guardan en:"
info "  $BACKUP"
echo

[[ $DRY_RUN -eq 1 ]] || mkdir -p "$BACKUP"

# ------------------------------------------------------- 1. repo externo
# Los temas (TokyoNight-zk, TokyoNight-SE, Qogirr-Dark) NO estan en los repos
# de Arch: vienen del repo gh0stzk-dotfiles. Sin anadirlo, el escritorio
# arranca sin tema porque apply-gtk.sh no encuentra esos ficheros.
add_theme_repo() {
    if grep -q '^\[gh0stzk-dotfiles\]' /etc/pacman.conf 2>/dev/null; then
        ok "repo gh0stzk-dotfiles ya configurado"
        return 0
    fi
    if [[ $DRY_RUN -eq 1 ]]; then
        echo "  anadir [gh0stzk-dotfiles] a /etc/pacman.conf"
        return 0
    fi
    warn "Se anade el repo externo gh0stzk-dotfiles a /etc/pacman.conf"
    warn "  (va por HTTP con TrustAll; es como lo tienes ya en tu maquina)"
    cp /etc/pacman.conf /etc/pacman.conf.entorno-arch.bak
    cat >> /etc/pacman.conf <<'REPO'

[gh0stzk-dotfiles]
SigLevel = Optional TrustAll
Server = http://gh0stzk.github.io/pkgs/x86_64
REPO
    sudo pacman -Sy --noconfirm >/dev/null 2>&1 || true
    ok "repo anadido (backup en /etc/pacman.conf.entorno-arch.bak)"
}

if [[ $DO_PACKAGES -eq 1 ]]; then
    add_theme_repo
    info "Instalando paquetes de los repos de Arch (pide sudo)..."
    if [[ $DRY_RUN -eq 1 ]]; then
        echo "  sudo pacman -S --needed - < packages.txt"
    else
        sudo pacman -S --needed - < "$REPO/packages.txt"
        ok "paquetes instalados"
    fi

    # pywal no existe en los repos de Arch: va con pip.
    # Los estilos de wofi importan ~/.cache/wal/colors-*.css, asi que sin
    # esto el tema se ve sin colores.
    if command -v wal >/dev/null 2>&1; then
        ok "pywal ya instalado ($(wal --version 2>&1 | head -1 | tr -d '\n'))"
    elif [[ $DRY_RUN -eq 1 ]]; then
        echo "  pipx install pywal16   # pywal NO esta en los repos de Arch"
    elif command -v pipx >/dev/null 2>&1; then
        pipx install pywal16 && ok "pywal instalado con pipx"
        pipx ensurepath || true
    elif command -v pip >/dev/null 2>&1; then
        pip install --user pywal16 && ok "pywal instalado con pip --user"
    else
        warn "Sin pipx ni pip: pywal no instalado. Los temas saldran sin color."
    fi
    echo
fi

# ------------------------------------------------------- 2. config/*
# Se COPIAN (no symlink) porque hay que sustituir el token __HOME__
# por la ruta real del usuario destino.
install_config() {
    local app="$1"
    local src="$REPO/config/$app"
    local dst="$HOME/.config/$app"
    [[ -d "$src" ]] || return 0

    backup_existing "$dst" "$dst"

    if [[ $DRY_RUN -eq 1 ]]; then
        info "config/$app -> ~/.config/$app"
        return 0
    fi

    mkdir -p "$(dirname "$dst")"
    rsync -a --delete-excluded \
        --exclude='*.bak' --exclude='*.bak-*' --exclude='*bak-*' \
        --exclude='*-bak' --exclude='*.swp' --exclude='*.log' \
        --exclude='.git' \
        "$src/" "$dst/"

    # Sustitucion del token de portabilidad
    if grep -rIlq '__HOME__' "$dst" 2>/dev/null; then
        substitute_paths "$dst"
        ok "config/$app (rutas adaptadas)"
    else
        ok "config/$app"
    fi
}

info "Instalando configuraciones visuales..."
for dir in "$REPO"/config/*/; do
    install_config "$(basename "$dir")"
done

# --------------------------------------------------------- 3. home/*
for f in "$REPO"/home/.*; do
    [[ -f "$f" ]] || continue
    name="$(basename "$f")"
    [[ "$name" == "." || "$name" == ".." ]] && continue
    backup_existing "$name" "$HOME/$name"
    if [[ $DRY_RUN -eq 1 ]]; then
        info "home/$name -> ~/$name"
    else
        cp -p "$f" "$HOME/$name"
        if grep -Iq '__HOME__' "$HOME/$name" 2>/dev/null; then
            sed -i "s|__HOME__|$HOME|g" "$HOME/$name"
            ok "home/$name (rutas adaptadas)"
        else
            ok "home/$name"
        fi
    fi
done

# ------------------------------------------------------- 4. scripts/ y bin/
if [[ -d "$REPO/scripts" ]]; then
    backup_existing "~/scripts" "$HOME/scripts"
    if [[ $DRY_RUN -eq 1 ]]; then
        info "scripts/ -> ~/scripts/"
    else
        mkdir -p "$HOME/scripts"
        rsync -a --exclude='*.bak-*' "$REPO/scripts/" "$HOME/scripts/"
        substitute_paths "$HOME/scripts"
        chmod +x "$HOME/scripts"/*.sh "$HOME/scripts"/* 2>/dev/null || true
        ok "scripts/ ($(ls "$HOME/scripts" | wc -l) ficheros)"
    fi
fi

if [[ -d "$REPO/bin" ]]; then
    backup_existing "~/bin" "$HOME/bin"
    if [[ $DRY_RUN -eq 1 ]]; then
        info "bin/ -> ~/bin/"
    else
        mkdir -p "$HOME/bin"
        rsync -a "$REPO/bin/" "$HOME/bin/"
        substitute_paths "$HOME/bin"
        chmod +x "$HOME/bin"/* 2>/dev/null || true
        ok "bin/ ($(ls "$HOME/bin" | wc -l) ficheros)"
    fi
fi

# --------------------------------------------------------- 5. wallpaper/
# El fondo por defecto es el logo de Arch. Si mas adelante eliges otra
# imagen, wallpaper.sh la respeta (la guarda en ~/.cache/current_wallpaper).
if [[ -d "$REPO/wallpaper" ]]; then
    if [[ $DRY_RUN -eq 1 ]]; then
        info "wallpaper/ -> ~/Pictures/wallpapers/"
    else
        mkdir -p "$HOME/Pictures/wallpapers" "$HOME/.cache"
        rsync -a "$REPO/wallpaper/" "$HOME/Pictures/wallpapers/"

        # Solo se fija el fondo si aun no hay ninguno elegido: si ya habia uno
        # en el cache, se respeta.
        actual=""
        [ -f "$HOME/.cache/current_wallpaper" ] && actual=$(cat "$HOME/.cache/current_wallpaper" 2>/dev/null)
        if [ -n "$actual" ] && [ -f "$actual" ]; then
            ok "wallpaper/ (se respeta el fondo actual: $(basename "$actual"))"
        else
            echo "$HOME/Pictures/wallpapers/arch-main.png" > "$HOME/.cache/current_wallpaper"
            ok "wallpaper/ (logo de Arch como fondo por defecto)"
        fi
    fi
fi

# ------------------------------------------------------- 6. localbin/ y fonts/
# localbin/ -> ~/.local/bin/  (scripts que las configs invocan por nombre:
#                              waybar-cpu no es un modulo de waybar, es un
#                              script propio. Sin esto la barra va vacia).
if [[ -d "$REPO/localbin" ]]; then
    if [[ $DRY_RUN -eq 1 ]]; then
        info "localbin/ -> ~/.local/bin/"
    else
        mkdir -p "$HOME/.local/bin"
        rsync -a "$REPO/localbin/" "$HOME/.local/bin/"
        substitute_paths "$HOME/.local/bin"
        chmod +x "$HOME/.local/bin"/* 2>/dev/null || true
        ok "localbin/ ($(ls "$HOME/.local/bin" | wc -l) scripts)"
    fi
fi

# fonts/ -> ~/.local/share/fonts/
# Fuentes instaladas a mano (Material Design Icons, Font Awesome 6, etc.).
# Sin ellas los iconos de waybar salen como cuadritos vacios.
if [[ -d "$REPO/fonts" ]]; then
    if [[ $DRY_RUN -eq 1 ]]; then
        info "fonts/ -> ~/.local/share/fonts/"
    else
        mkdir -p "$HOME/.local/share/fonts"
        rsync -a "$REPO/fonts/" "$HOME/.local/share/fonts/"
        if command -v fc-cache >/dev/null 2>&1; then
            if fc-cache -f >/dev/null 2>&1; then
                ok "fonts/ ($(ls "$REPO/fonts" | wc -l) familias, cache regenerada)"
            else
                ok "fonts/ ($(ls "$REPO/fonts" | wc -l) familias)"
                warn "fc-cache fallo: las fuentes cargaran al reiniciar la sesion"
            fi
        else
            ok "fonts/ ($(ls "$REPO/fonts" | wc -l) familias)"
            warn "fc-cache no disponible: reinicia la sesion para que las fuentes carguen"
        fi
    fi
fi

# --------------------------------------------------------- 7. verificacion
echo
info "Verificando la instalacion..."

check_file() {
    if [[ -e "$1" ]]; then ok "$2"; else warn "FALTA: $2"; fi
}

for app in hypr waybar swaync wofi kitty alacritty; do
    check_file "$HOME/.config/$app" "config/$app"
done
for f in .zshrc .bashrc .gitconfig; do
    check_file "$HOME/$f" "$f"
done
check_file "$HOME/scripts" "scripts/ ($(ls "$HOME"/scripts 2>/dev/null | wc -l) ficheros)"
check_file "$HOME/bin" "bin/ ($(ls "$HOME"/bin 2>/dev/null | wc -l) ficheros)"
check_file "$HOME/.local/bin" "localbin/ ($(ls "$HOME"/.local/bin 2>/dev/null | wc -l) scripts)"
check_file "$HOME/.local/share/fonts" "fonts/ ($(ls "$HOME"/.local/share/fonts 2>/dev/null | wc -l) familias)"
check_file "$HOME/Pictures/wallpapers/arch-main.png" "wallpaper/ (logo de Arch)"

# El fondo elegido en el cache debe existir de verdad: wallpaper.sh lo usa como
# fuente de verdad y si no existe, el escritorio se queda sin fondo.
if [[ -f "$HOME/.cache/current_wallpaper" ]]; then
    w=$(cat "$HOME/.cache/current_wallpaper" 2>/dev/null)
    if [[ -f "$w" ]]; then
        ok "fondo: $(basename "$w")"
    else
        warn "el fondo guardado no existe ($w) — se pondra el logo de Arch al reiniciar"
    fi
fi

# Binarios criticos del escritorio. Faltar uno = escritorio roto o sin estilo.
echo
info "Comprobando dependencias criticas..."
for b in hyprctl waybar wofi awww mako swaync gsettings; do
    if command -v "$b" >/dev/null 2>&1; then
        ok "$b"
    else
        warn "$b no instalado — falta el paquete"
    fi
done

# Los temas vienen del repo externo gh0stzk-dotfiles
for t in /usr/share/themes/TokyoNight-zk /usr/share/icons/TokyoNight-SE /usr/share/icons/Qogirr-Dark; do
    [[ -e "$t" ]] && ok "$(basename "$t")" || warn "FALTA el tema $(basename "$t") — revisa el repo gh0stzk-dotfiles"
done

# awww, hypridle y swaync NO tienen servicios systemd que habilitar: los arranca
# hyprland.lua al iniciar sesion. Si esas lineas desaparecieran del repo, el
# escritorio entraria sin fondo y sin notificaciones y no habria aviso.
echo
info "Comprobando que la sesion arrancara los demonios..."
lua="$HOME/.config/hypr/hyprland.lua"
if [[ -f "$lua" ]]; then
    for d in awww-daemon hypridle; do
        if grep -q "$d" "$lua" 2>/dev/null; then
            ok "$d se arranca desde hyprland.lua"
        else
            warn "hyprland.lua no arranca '$d' — el escritorio entrara sin el"
        fi
    done
    if grep -q "swaync" "$lua" 2>/dev/null; then
        ok "swaync se arranca desde hyprland.lua"
    else
        warn "hyprland.lua no arranca swaync — no habra notificaciones"
    fi
else
    warn "no encuentro $lua — no puedo verificar el arranque de los demonios"
fi

# Ningun __HOME__ debe haber sobrevivido a la sustitucion.
# Ojo: grep devuelve 1 cuando no encuentra nada, y con 'set -e' eso
# abortaria el script. Por eso el { ... || true; }.
pendientes=$( { grep -rIl '__HOME__' "$HOME/.config" "$HOME/scripts" "$HOME/bin" 2>/dev/null || true; } | wc -l)
if [[ "$pendientes" -eq 0 ]]; then
    ok "rutas resueltas correctamente (sin tokens __HOME__)"
else
    warn "$pendientes fichero(s) con __HOME__ sin resolver:"
    { grep -rIl '__HOME__' "$HOME/.config" "$HOME/scripts" "$HOME/bin" 2>/dev/null || true; } | sed 's/^/       /'
fi

# Hyprland necesita >= 0.56 por la config en Lua
if command -v hyprctl >/dev/null 2>&1; then
    ver=$(hyprctl version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)
    if [[ -n "${ver:-}" ]]; then
        if [[ "$(printf '0.56.0\n%s\n' "$ver" | sort -V | head -1)" == "0.56.0" ]]; then
            ok "Hyprland $ver (la config en Lua necesita 0.56+)"
        else
            warn "Hyprland $ver es antiguo: la config en Lua necesita 0.56 o superior"
        fi
    fi
fi

echo
info "Listo. Ahora:"
echo "  1. Cierra sesion y vuelve a entrar (no vale reiniciar el compositor)"
echo "  2. Ajusta el teclado si tu laptop no es 'by-tech-gaming-keyboard'"
echo "     -> edita los bloques device{} en ~/.config/hypr/hyprland.conf"
echo "  3. Genera un tema:  wal -n mis-img-favorita -i ~/fondo.png"
echo "  4. Tus claves van aparte, en ~/.secrets/keys.env (NO esta en este repo)"
echo
[[ $DRY_RUN -eq 1 ]] && info "(simulacion: no se escribio nada)"
info "Backup de lo anterior: $BACKUP"