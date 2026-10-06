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
# Necesario en config/, home/, scripts/ y bin/ por igual.
substitute_paths() {
    local target="$1"
    grep -rIl '__HOME__' "$target" 2>/dev/null | while read -r f; do
        sed -i "s|__HOME__|$HOME|g" "$f"
    done
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

# ---------------------------------------------------------- 1. paquetes
if [[ $DO_PACKAGES -eq 1 ]]; then
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

# --------------------------------------------------------- 5. verificacion
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