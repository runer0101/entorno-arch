#!/bin/sh
# =============================================================
# apply-gtk.sh — Aplica tema GTK al iniciar Hyprland
# Usa gsettings (no xsettingsd, que no funciona en Wayland)
# =============================================================

# Lee el tema del rice activo
# Path: ~/.config/hypr/ (primario) → ~/.config/bspwm/ (fallback migración)
if [ -f "$HOME/.config/hypr/.rice" ]; then
    RICE=$(cat "$HOME/.config/hypr/.rice" 2>/dev/null)
    THEME_FILE="$HOME/.config/hypr/rices/$RICE/theme-config.bash"
else
    RICE=$(cat "$HOME/.config/bspwm/.rice" 2>/dev/null)
    THEME_FILE="$HOME/.config/bspwm/rices/$RICE/theme-config.bash"
fi

if [ -f "$THEME_FILE" ]; then
    . "$THEME_FILE"
fi

# Defaults si no hay
gtk_theme="${gtk_theme:-TokyoNight-zk}"
gtk_icons="${gtk_icons:-TokyoNight-SE}"
gtk_cursor="${gtk_cursor:-Qogirr-Dark}"

# Envuelve el pack de iconos del rice en "Logos-Originales", que recupera el
# logo original de cada app (el pack temático los redibuja y quedan mal, p. ej.
# el de Steam). Si algo falla se sigue con el pack tal cual.
if [ -x "$HOME/.config/hypr/scripts/iconos-originales.sh" ]; then
    wrapped=$("$HOME/.config/hypr/scripts/iconos-originales.sh" "$gtk_icons" 2>/dev/null)
    [ -n "$wrapped" ] && gtk_icons="$wrapped"
fi

# gsettings requiere dbus y XDG_RUNTIME_DIR
if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface gtk-theme "$gtk_theme"
    gsettings set org.gnome.desktop.interface icon-theme "$gtk_icons"
    gsettings set org.gnome.desktop.interface cursor-theme "$gtk_cursor"
    gsettings set org.gnome.desktop.interface cursor-size 24
    gsettings set org.gnome.desktop.interface font-name "UbuntuMono Nerd Font 11"
fi

# Sync con .gtkrc-2.0 y settings.ini (para apps que no usan portal)
sed -i "s/^gtk-theme-name=.*/gtk-theme-name=\"$gtk_theme\"/" "$HOME/.gtkrc-2.0" 2>/dev/null
sed -i "s/^gtk-icon-theme-name=.*/gtk-icon-theme-name=\"$gtk_icons\"/" "$HOME/.gtkrc-2.0" 2>/dev/null
sed -i "s/^gtk-cursor-theme-name=.*/gtk-cursor-theme-name=\"$gtk_cursor\"/" "$HOME/.gtkrc-2.0" 2>/dev/null

mkdir -p "$HOME/.config/gtk-3.0"
cat > "$HOME/.config/gtk-3.0/settings.ini" <<EOF
[Settings]
gtk-theme-name=$gtk_theme
gtk-icon-theme-name=$gtk_icons
gtk-font-name=UbuntuMono Nerd Font 11
gtk-cursor-theme-name=$gtk_cursor
gtk-cursor-theme-size=24
gtk-application-prefer-dark-theme=1
EOF
