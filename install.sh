#!/usr/bin/env bash
# entorno-arch — instalador del escritorio
# Reconstruye el entorno visual en Arch Linux.
#
#   ./install.sh            -> solo instala configs (backup previo automatico)
#   ./install.sh --packages -> ademas instala dependencias con pacman y pywal
#   ./install.sh --dry-run  -> muestra que haria, sin tocar nada
#
# El repo replica tu $HOME tal cual: todo lo que hay en home/ se copia a tu
# home. Por eso no hay nombres magicos ni carpetas intermedias.
#
#   git clone https://github.com/runer0101/entorno-arch.git && \
#     cd entorno-arch && ./install.sh --packages

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$REPO/home"
STAMP=$(date +%Y%m%d-%H%M%S)
BACKUP="$HOME/.config-backups/$STAMP"

DO_PACKAGES=0
DRY_RUN=0

for arg in "$@"; do
    case "$arg" in
        --packages) DO_PACKAGES=1 ;;
        --dry-run)  DRY_RUN=1 ;;
        -h|--help)  sed -n '2,13p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'; exit 0 ;;
        *) echo "Opcion desconocida: $arg (usa --help)"; exit 1 ;;
    esac
done

info() { printf '\033[36m::\033[0m %s\n' "$1"; }
ok()   { printf '\033[32m  ok\033[0m %s\n' "$1"; }
warn() { printf '\033[33m  !!\033[0m %s\n' "$1"; }

# Sustituye el token __HOME__ por la ruta real del usuario.
# Ojo: grep devuelve 1 cuando no encuentra nada, y con 'set -e' + pipefail
# eso abortaria el script entero en silencio. Por eso el '|| true'.
substitute_paths() {
    local target="$1" encontrados
    encontrados=$(grep -rIl '__HOME__' "$target" 2>/dev/null || true)
    [[ -z "$encontrados" ]] && return 0
    while read -r f; do
        sed -i "s|__HOME__|$HOME|g" "$f"
    done <<< "$encontrados"
    return 0
}

# -------------------------------------------------------------- preflight
if [[ $EUID -eq 0 ]]; then
    echo "No ejecutes esto con sudo: instalaria las configs en /root." >&2
    exit 1
fi

if [[ ! -d "$SRC" ]]; then
    echo "No encuentro $SRC. ¿Clone mal el repo?" >&2
    exit 1
fi

command -v rsync >/dev/null 2>&1 || {
    warn "Falta 'rsync'. Instalando..."
    sudo pacman -S --needed rsync
}

info "Destino: $HOME"
info "Backup de lo que se pise: $BACKUP"
echo

# --------------------------------------------------------------- backup
backup_if_exists() {
    # Ojo: 'local a=... b=$a' no funciona — bash evalua todas las palabras
    # antes de asignar ninguna, y con 'set -u' eso aborta el script.
    local rel="$1"
    local dst="$HOME/$rel"
    [[ -e "$dst" || -L "$dst" ]] || return 0
    if [[ $DRY_RUN -eq 1 ]]; then
        info "backup: ~/$rel"
        return 0
    fi
    mkdir -p "$BACKUP/$(dirname "$rel")"
    cp -a "$dst" "$BACKUP/$rel" 2>/dev/null && ok "backup de ~/$rel"
}

if [[ $DRY_RUN -eq 1 ]]; then
    :
else
    mkdir -p "$BACKUP"
    # Solo lo que el repo va a escribir encima: ficheros sueltos y apps.
    for f in .bashrc .zshrc .gitconfig .fzf.bash .fzf.zsh; do
        backup_if_exists "$f"
    done
    for d in "$SRC"/.config/*/; do
        [[ -d "$d" ]] && backup_if_exists ".config/$(basename "$d")"
    done
fi

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
    if command -v wal >/dev/null 2>&1; then
        ok "pywal ya instalado"
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

# ------------------------------------------------------- 2. copiar home/
if [[ $DRY_RUN -eq 1 ]]; then
    info "home/ -> $HOME/  (simulacion)"
    find "$SRC" -maxdepth 2 -mindepth 1 -not -path '*/.git*' -not -name '.config' \
        -not -path '*/.config/*' | sed "s|^$SRC|    ~|" | head -20
    info "  (mas los $(ls -1 "$SRC"/.config | wc -l) directorios de ~/.config)"
else
    # rsync sin --delete: fusiona con lo que ya exista y no borra nada tuyo.
    rsync -a \
        --exclude='*.bak' --exclude='*.bak-*' --exclude='*bak-*' \
        --exclude='*-bak' --exclude='*.swp' --exclude='*.log' \
        --exclude='.git' \
        "$SRC/" "$HOME/"
    ok "home/ copiado"

    # Sustitucion de rutas
    substitute_paths "$HOME/.config"
    substitute_paths "$HOME/.local/bin"
    substitute_paths "$HOME/scripts"
    substitute_paths "$HOME/bin"
    for f in .zshrc .bashrc .fzf.bash .fzf.zsh; do
        grep -Iq '__HOME__' "$HOME/$f" 2>/dev/null && sed -i "s|__HOME__|$HOME|g" "$HOME/$f"
    done
    ok "rutas adaptadas a $HOME"

    # Ejecutables
    chmod +x "$HOME"/.local/bin/* "$HOME"/scripts/* "$HOME"/bin/* 2>/dev/null || true

    # Cache de fuentes
    if [[ -d "$HOME/.local/share/fonts" ]] && command -v fc-cache >/dev/null 2>&1; then
        fc-cache -f >/dev/null 2>&1 || warn "fc-cache fallo: las fuentes cargaran al reiniciar"
    fi
fi

# --------------------------------------------------------- 3. verificacion
echo
info "Verificando la instalacion..."

check() {
    if [[ -e "$HOME/$1" ]]; then ok "$2"; else warn "FALTA: ~/$2"; fi
}
for app in hypr waybar swaync wofi kitty alacritty wal; do
    check ".config/$app" ".config/$app"
done
for f in .zshrc .bashrc .gitconfig; do check "$f" "$f"; done
check ".local/bin" ".local/bin ($(ls "$HOME"/.local/bin 2>/dev/null | wc -l) scripts)"
check ".local/share/fonts" ".local/share/fonts ($(ls "$HOME"/.local/share/fonts 2>/dev/null | wc -l) familias)"
check "scripts" "scripts ($(ls "$HOME"/scripts 2>/dev/null | wc -l) ficheros)"
check "bin" "bin ($(ls "$HOME"/bin 2>/dev/null | wc -l) ficheros)"
check ".config/wal/colorschemes/dark/3024.json" "paleta teal"

# Ningun __HOME__ debe haber sobrevivido
pendientes=$( { grep -rIl '__HOME__' "$HOME/.config" "$HOME/.local/bin" \
    "$HOME/scripts" "$HOME/bin" 2>/dev/null || true; } | wc -l)
if [[ "$pendientes" -eq 0 ]]; then
    ok "rutas resueltas correctamente (sin tokens __HOME__)"
else
    warn "$pendientes fichero(s) con __HOME__ sin resolver"
fi

# Binarios criticos: faltar uno = escritorio roto o sin estilo
echo
info "Comprobando dependencias criticas..."
for b in hyprctl waybar wofi awww swaync gsettings; do
    if command -v "$b" >/dev/null 2>&1; then ok "$b"; else warn "$b no instalado"; fi
done

for t in /usr/share/themes/TokyoNight-zk /usr/share/icons/TokyoNight-SE /usr/share/icons/Qogirr-Dark; do
    [[ -e "$t" ]] && ok "$(basename "$t")" || warn "FALTA el tema $(basename "$t") — revisa el repo gh0stzk-dotfiles"
done

# awww, hypridle y swaync NO tienen servicios systemd que habilitar: los arranca
# hyprland.lua al iniciar sesion. Si esas lineas desaparecieran, el escritorio
# entraria sin fondo y sin notificaciones y no habria aviso.
echo
info "Comprobando que la sesion arrancara los demonios..."
lua="$HOME/.config/hypr/hyprland.lua"
if [[ -f "$lua" ]]; then
    for d in awww-daemon hypridle swaync; do
        grep -q "$d" "$lua" 2>/dev/null \
            && ok "$d se arranca desde hyprland.lua" \
            || warn "hyprland.lua no arranca '$d' — el escritorio entrara sin el"
    done
else
    warn "no encuentro $lua — no puedo verificar el arranque de los demonios"
fi

# El fondo elegido en el cache debe existir de verdad
if [[ -f "$HOME/.cache/current_wallpaper" ]]; then
    w=$(cat "$HOME/.cache/current_wallpaper" 2>/dev/null)
    if [[ -f "$w" ]]; then
        ok "fondo: $(basename "$w")"
    else
        warn "el fondo guardado no existe ($w) — se pondra el logo de Arch al reiniciar"
    fi
fi

echo
info "Listo. Ahora:"
echo "  1. Cierra sesion y vuelve a entrar (no vale reiniciar el compositor)"
echo "  2. Si quieres zsh por defecto:  chsh -s \"\$(command -v zsh)\""
echo "  3. Ajusta el teclado si tu laptop no es 'by-tech-gaming-keyboard'"
echo "     -> edita los bloques device{} en ~/.config/hypr/hyprland.conf"
echo "  4. Genera los colores:  wal -i ~/Pictures/wallpapers/arch-main.png"
echo "  5. Tus claves van aparte, en ~/.secrets/keys.env (NO esta en este repo)"
echo
[[ $DRY_RUN -eq 1 ]] && info "(simulacion: no se escribio nada)"
info "Backup de lo anterior: $BACKUP"