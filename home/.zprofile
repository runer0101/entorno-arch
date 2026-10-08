# ~/.zprofile — se carga en shells de login.
#
# El SDK real está en ~/android-sdk; /etc/profile.d apunta a /opt/android-sdk
# (no existe) y deja ANDROID_HOME roto. Sobreescribir aquí después de profile.d.
export ANDROID_HOME="$HOME/android-sdk"
export ANDROID_SDK_ROOT="$HOME/android-sdk"
export PATH="$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
#
# SDDM lanza la sesión Wayland a través de /usr/share/sddm/scripts/wayland-session,
# que primero re-ejecuta el shell del usuario con --login (zsh) y solo después hace
# `exec start-hyprland`. Es decir: esto corre ANTES de que Hyprland lea hyprland.conf.
#
# Ese es el único punto donde se puede reparar gpu-profile.conf a tiempo. Si el
# AQ_DRM_DEVICES guardado apunta a un nodo DRM que ya no es la AMD, Hyprland aborta
# en initServer y SDDM te devuelve al greeter como si la contraseña estuviera mal.
# Ver ~/scripts/gpu-perfil.sh (sanear).
#
# Y el export tiene que salir de aquí por el mismo motivo: `env = AQ_DRM_DEVICES` en
# hyprland.conf NO funciona. Hyprland aplica los `env` al parsear el config, que es
# DESPUÉS de que aquamarine cree el backend DRM, así que la variable llega tarde y el
# perfil "movil" nunca se aplicaba (el log decía `Found 2 GPUs` y registraba las dos).
if [ -x "$HOME/scripts/gpu-perfil.sh" ]; then
  "$HOME/scripts/gpu-perfil.sh" sanear >>"$HOME/.cache/gpu-perfil-sanear.log" 2>&1 || true
  eval "$("$HOME/scripts/gpu-perfil.sh" entorno 2>>"$HOME/.cache/gpu-perfil-sanear.log")" || true
fi
