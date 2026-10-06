<div align="center">

# entorno-arch

**Mi escritorio en Arch Linux — Hyprland + Waybar + wofi, con 18 rices intercambiables.**

Copia real de la máquina, pensada para reconstruir el mismo aspecto
en otra laptop con Arch.

[![Arch](https://img.shields.io/badge/arch-linux-1793d1?logo=archlinux&logoColor=white)](https://archlinux.org)
[![Hyprland](https://img.shields.io/badge/Hyprland-%3E%3D0.56-5b9bd5?logo=hyprland&logoColor=white)](https://hypr.land)
[![Licencia](https://img.shields.io/badge/licencia-GPL--3.0-blue.svg)](LICENSE)

</div>

---

## Instalación

Un comando. Pide `sudo` para instalar dependencias.

```bash
git clone https://github.com/runer0101/entorno-arch.git && \
  cd entorno-arch && ./install.sh --packages
```

Luego **cierra sesión y vuelve a entrar** (no vale reiniciar el compositor).

<details>
<summary>Más opciones</summary>

```bash
./install.sh --dry-run     # simula: no escribe nada
./install.sh               # solo configs, sin instalar paquetes
./install.sh --help        # ayuda
```

</details>

### Qué hace

1. Añade el repo externo `gh0stzk-dotfiles` a `/etc/pacman.conf` (con copia de seguridad)
2. Instala las dependencias de `packages.txt` (58 paquetes) con `pacman`
3. Instala **pywal** con `pipx` — no existe en los repos de Arch
4. Guarda una copia de tu `~/.config` actual en `~/.config-backups/<fecha>/`
5. Copia las configs a `~/.config/`, el shell a `~`, `scripts/`+`bin/` a tu home,
   `localbin/` a `~/.local/bin/` y `fonts/` a `~/.local/share/fonts/`
6. Sustituye el token `__HOME__` por tu ruta real
7. **Verifica** la instalación: cada config, los binarios críticos (`hyprctl`,
   `waybar`, `wofi`, `awww`, `swaync`, `gsettings`), los tres temas, que la sesión
   arrancará `awww-daemon`/`hypridle`/`swaync`, y que no quede ningún `__HOME__` suelto

> No lo ejecutes con `sudo`: instalaría las configs en `/root`.

---

## Requisitos

| | |
|---|---|
| **Sistema** | Arch Linux (derivados funcionan) |
| **Hyprland** | **0.56 o superior** — la config está escrita en Lua |
| **Shell** | zsh |

Hyprland no viene en los repos estables de todas las distros; si no lo tienes,
mira su [wiki de instalación](https://wiki.hypr.land/Getting-Started/Installation/).

---

## Qué incluye

Solo la parte visual. Es un `dotfiles` del escritorio, no de todo el sistema.

| Ruta | Qué es |
|---|---|
| `config/hypr/` | Hyprland (config en **Lua**), 18 rices, scripts, shaders, hyprlock |
| `config/waybar/` | Barra superior: `config.jsonc`, `common.jsonc`, estilos, iconos |
| `config/swaync/` | Notificaciones e iconos |
| `config/swayosd/` | OSD de volumen y brillo |
| `config/wofi/` | Lanzadores y menús (temas de pywal) |
| `config/wlogout/` | Menú de cierre de sesión |
| `config/menus/` | Menús propios |
| `config/kitty/` | Terminal kitty |
| `config/alacritty/` | Terminal alacritty |
| `config/gtk-3.0/` | Tema GTK |
| `config/kanshi/` | Perfiles de pantalla |
| `config/cava/` | Visualizador de audio |
| `config/wal/` | Paleta teal personalizada (`3024` retocado) |
| `home/` | `.zshrc`, `.bashrc`, `.gitconfig`, `.fzf.bash`, `.fzf.zsh` |
| `scripts/` | 16 scripts propios → `~/scripts/` |
| `bin/` | 6 ejecutables → `~/bin/` |
| `localbin/` | 10 scripts que las configs invocan **por nombre** → `~/.local/bin/` |
| `fonts/` | 12 fuentes instaladas a mano → `~/.local/share/fonts/` |
| `wallpaper/` | El logo de Arch (1920x1080) → `~/Pictures/wallpapers/` |

### Por qué `localbin/` es imprescindible

Tu barra **no usa módulos de waybar**: invoca binarios con nombre propio.

```jsonc
"exec": "waybar-cpu"      // no es un módulo, es tu script
"exec": "waybar-ram"
"exec": "waybar-htb"
```

Viven en `~/.local/bin/`. Sin ellos, waybar arranca y la barra sale **vacía**.
Por eso `install.sh` los instala ahí y verifica que estén.

### Temas: repo externo

El tema no está en Arch. Viene de `gh0stzk-dotfiles`:

| Tema | Paquete | Qué es |
|---|---|---|
| `TokyoNight-zk` | `gh0stzk-gtk-themes` | Tema GTK |
| `TokyoNight-SE` | `gh0stzk-icons-tokyo-night` | Iconos |
| `Qogirr-Dark` | `gh0stzk-cursor-qogirr` | Cursor |

`install.sh --packages` añade ese repo a `/etc/pacman.conf` (guardando copia) antes
de instalar. Sin él, `apply-gtk.sh` no encuentra los ficheros y el escritorio
arranca **sin estilo**.

### Qué NO incluye

- **Claves o tokens** — van aparte en `~/.secrets/keys.env`, nunca en el repo
- **Waydroid como app** — solo los scripts que lo lanzan
- **Neovim** — era un clon sin modificar de [NvChad/starter][nvchad], no configuración propia
- **Apps y agentes de IA** — `claude`, `copilot`, `opencode`, `pnpm`, `zed`,
  `telegram`… van por su cuenta (pipx, npm o AUR)
- **Android SDK**, herramientas de desarrollo, cachés ni datos de aplicaciones

[nvchad]: https://github.com/NvChad/starter

---

## Cómo se hace portable

Las rutas absolutas están normalizadas con el token `__HOME__`, no con mi nombre
de usuario:

```bash
# en el repo
"include": ["__HOME__/.config/waybar/common.jsonc"]

# en tu máquina, tras instalar
"include": ["/home/tunombre/.config/waybar/common.jsonc"]
```

`install.sh` hace la sustitución. Por eso **copia** los ficheros en vez de crear
symlinks: hay que reescribir las rutas *dentro* de ellos.

> `.gitconfig` viene **sin identidad** a propósito: es específico de cada máquina.
> Configúralo una vez con `git config --global user.email "tu@correo.com"`.

---

## Los rices

`config/hypr/rices/` contiene 18 rices. Estructura típica:

```
rices/emilia/
├── config.ini          # configuración del rice
├── theme-config.bash   # colores y tema
├── Bar.bash            # layout de la barra
├── modules.ini         # módulos de waybar
├── preview.webp        # vista previa
└── walls/              # 12 wallpapers
```

> `andrea` y `z0mbi3` no llevan `config.ini` ni `modules.ini`; usan el
> comportamiento por defecto.

Los 18: `aline` · `andrea` · `brenda` · `cristina` · `cynthia` · `daniela` ·
`emilia` · `h4ck3r` · `isabel` · `jan` · `karla` · `marisol` · `melissa` ·
`pamela` · `silvia` · `varinka` · `yael` · `z0mbi3`

El actual es **emilia**, migrado desde bspwm. La versión anterior en formato
hyprlang está en `config/hypr/hyprland.conf.pre-lua` por si la necesitas.

`config/hypr/hyprland.lua` es la config principal, escrita en **Lua** y con
`os.getenv("HOME")`, así que ya es portable por sí misma.

---

## Ajustes manuales

**Shell** — el repo te pone el `.zshrc` pero no cambia tu shell por defecto.
Si quieres zsh:

```bash
chsh -s "$(command -v zsh)"   # cierra sesión y vuelve a entrar
```

**Teclado** — `config/hypr/hyprland.conf` tiene bloques `device{}` para el
`by-tech-gaming-keyboard` con layout `es`. En otra laptop, edítalos o bórralos
(Hyprland los ignora si el dispositivo no existe, pero es más limpio quitarlos).

**Colores** — los estilos de wofi y waybar importan `~/.cache/wal/colors-*.css`,
que genera pywal. Sin ejecutar `wal` al menos una vez, los menús salen sin color.

La paleta teal es un `3024` retocado y va en `config/wal/colorschemes/dark/3024.json`.
`install.sh` lo copia a `~/.config/wal/`, así que se aplica solo al regenerar:

```bash
wal -i ~/Pictures/wallpapers/arch-main.png    # usa la paleta del repo
wal --theme                                   # lista los temas disponibles
```

> Ojo con la sintaxis: el tema se asigna con `-p`, no con `-n` ni con `-t`
> (esos son flags). Y no existe un tema llamado `ocean`.

**Wallpaper** — el fondo por defecto es el **logo de Arch** (`wallpaper/arch-main.png`).
`install.sh` lo pone en `~/Pictures/wallpapers/` y lo marca como fondo elegido.

Si más adelante quieres otra imagen, cámbiala con tu gestor de fondos; `wallpaper.sh`
guarda la elección en `~/.cache/current_wallpaper` y a partir de ahí la respeta.
Al cambiar de rice **no** se toca el fondo: si quieres el wallpaper de un rice, ponlo a mano.

El fondo lo aplica **`awww`**, no hyprpaper.

No hay que hacer nada: `hyprland.lua` arranca el demonio solo al iniciar sesión
(`hl.exec_cmd("awww-daemon")`), igual que `hypridle` y `swaync`. No existen
servicios systemd que habilitar. `install.sh` lo verifica al terminar.

> Aviso: esto se corrigió tras comprobar que **no existe** ningún
> `awww-daemon.service`. Las instrucciones antiguas que decían
> `systemctl --user enable --now awww-daemon.service` eran falsas.

**Waydroid** — los binds de `hyprland.conf` asumen el contenedor ya instalado.
Ver [`waydroid-config`](https://github.com/runer0101/waydroid-config).

**Secretos** — crea `~/.secrets/keys.env` con tus claves. Tu `.zshrc` lo carga
sola si existe (línea 323), pero **ese fichero no está en el repo**.

---

## Repos relacionados

| Repo | Qué es |
|---|---|
| [`rice-backup`](https://github.com/runer0101/rice-backup) | Backup más antiguo y completo, incluye apps que aquí no están |
| [`waydroid-config`](https://github.com/runer0101/waydroid-config) | Waydroid: GPU AMD + `fake_touch` para Saint Seiya |
| [`dotfiles`](https://github.com/runer0101/dotfiles) | Dotfiles de junio, ya superados por este |

---

## Estructura

```
entorno-arch/
├── install.sh          # instalador
├── packages.txt        # 58 dependencias
├── config/             # -> ~/.config/
├── home/               # -> ~/
├── scripts/            # -> ~/scripts/
├── bin/                # -> ~/bin/
├── localbin/           # -> ~/.local/bin/   (scripts que waybar invoca por nombre)
├── fonts/              # -> ~/.local/share/fonts/
└── wallpaper/          # -> ~/Pictures/wallpapers/  (logo de Arch)
```

## Créditos y licencia

Este repositorio es **GPL-3.0**, no MIT.

Buena parte de lo que hay aquí viene de **[gh0stzk/dotfiles](https://github.com/gh0stzk/dotfiles)**
(Copyright © 2021-2026 gh0stzk), que también es GPL-3.0. Al ser obra derivada, la
GPL obliga a distribuirla bajo los mismos términos. Los ficheros originales llevan
su cabecera de copyright y no se han eliminado.

| Origen | Qué |
|---|---|
| **gh0stzk/dotfiles** (GPL-3.0) | `home/.zshrc`, `config/alacritty/alacritty.toml`, `config/hypr/rices/` (58 ficheros), parte de `config/hypr/scripts/`, `localbin/colorscript` |
| **gh0stzk-dotfiles** (repo de paquetes) | Temas `TokyoNight-zk`, `TokyoNight-SE`, `Qogirr-Dark` |
| **Mío** | `install.sh`, `packages.txt`, `wallpaper/`, `fonts/`, `scripts/`, `bin/`, `localbin/` propio y las personalizaciones sobre lo anterior |

Si algún día quieres quitar lo de terceros, el núcleo del escritorio son los rices,
el `.zshrc` y el `alacritty.toml`. Sin ellos queda el armazón pero no el aspecto.

Ver [LICENSE](LICENSE) para el texto completo. Los wallpapers y assets que no vienen
de gh0stzk son míos.