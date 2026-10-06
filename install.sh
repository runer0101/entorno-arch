#!/usr/bin/env bash
# entorno-arch — instalador del escritorio
# Reconstruye el entorno visual en Arch Linux.
#
#   ./install.sh            -> solo instala (backup previo automatico)
#   ./install.sh --packages -> ademas instala los paquetes con pacman
#   ./install.sh --dry-run  -> muestra que haria, sin tocar nada

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
        -h|--help)  sed -n '2,9p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'; exit 0 ;;
        *) echo "Opcion desconocida: $arg (usa --help)"; exit 1 ;;
    esac
done

info()  { printf '\033[36m::\033[0m %s\n' "$1"; }
ok()    { printf '\033[32m  ok\033[0m %s\n' "$1"; }
warn()  { printf '\033[33m  !!\033[0m %s\n' "$1"; }

# Sustituye el token de portabilidad __HOME__ por la ruta real del usuario.
# Necesario en config/, home/, scripts/ y bin/ por igual.
substitute_paths() {
    local target="$1" changed=0
    grep -rIl '__HOME__' "$target" 2>/dev/null | while read -r f; do
        sed -i "s|__HOME__|$HOME|g" "$f"
    done
    return $changed
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
    info "Instalando paquetes (esto pide sudo)..."
    if [[ $DRY_RUN -eq 1 ]]; then
        echo "  pacman -S --needed - < packages.txt"
    else
        sudo pacman -S --needed - < "$REPO/packages.txt"
        ok "paquetes instalados"
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

echo
info "Listo. Ahora:"
echo "  1. Reinicia la sesion grafica (logout + login)"
echo "  2. Ajusta el teclado si tu laptop no es 'by-tech-gaming-keyboard'"
echo "     -> edita los bloques device{} en ~/.config/hypr/hyprland.conf"
echo "  3. Tus claves van aparte, en ~/.secrets/keys.env (NO esta en este repo)"
echo
info "Backup de lo anterior: $BACKUP"