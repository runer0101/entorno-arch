<div align="center">

# entorno-arch

**Mi escritorio en Arch Linux — Hyprland + Waybar + wofi, con 18 rices intercambiables.**

Copia real de la máquina, pensada para reconstruir el mismo aspecto
en otra laptop con Arch.

[![Arch](https://img.shields.io/badge/arch-linux-1793d1?logo=archlinux&logoColor=white)](https://archlinux.org)
[![Hyprland](https://img.shields.io/badge/Hyprland-%3E%3D0.56-5b9bd5?logo=hyprland&logoColor=white)](https://hypr.land)
[![Licencia](https://img.shields.io/badge/licencia-MIT-blue.svg)](LICENSE)

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

1. Instala las dependencias de `packages.txt` (57 paquetes) con `pacman`
2. Instala **pywal** con `pipx` — no existe en los repos de Arch
3. Guarda una copia de tu `~/.config` actual en `~/.config-backups/<fecha>/`
4. Copia las configs a `~/.config/`, el shell a `~`, y `scripts/` + `bin/` a tu home
5. Sustituye el token `__HOME__` por tu ruta real
6. **Verifica** la instalación y avisa si algo falta

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
| `home/` | `.zshrc`, `.bashrc`, `.gitconfig`, `.fzf.bash`, `.fzf.zsh` |
| `scripts/` | 16 scripts propios |
| `bin/` | 6 ejecutables (Waydroid, Minecraft) |

### Qué NO incluye

- **Claves o tokens** — van aparte en `~/.secrets/keys.env`, nunca en el repo
- **Waydroid como app** — solo los scripts que lo lanzan
- **Neovim** — era un clon sin modificar de [NvChad/starter][nvchad], no configuración propia
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

**Teclado** — `config/hypr/hyprland.conf` tiene bloques `device{}` para el
`by-tech-gaming-keyboard` con layout `es`. En otra laptop, edítalos o bórralos
(Hyprland los ignora si el dispositivo no existe, pero es más limpio quitarlos).

**Colores** — los estilos de wofi importan `~/.cache/wal/colors-*.css`, que
genera pywal. Sin ejecutar `wal` al menos una vez, los menús salen sin color:

```bash
wal -n ocean -i ~/Pictures/fondo.png
```

**Secretos** — crea `~/.secrets/keys.env` con tus claves. Tu `.zshrc` lo carga
sola si existe (línea 323), pero **ese fichero no está en el repo**.

**Waydroid** — los binds de `hyprland.conf` asumen el contenedor ya instalado.
Ver [`waydroid-config`](https://github.com/runer0101/waydroid-config).

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
├── packages.txt        # 57 dependencias
├── config/             # -> ~/.config/
├── home/               # -> ~/
├── scripts/            # -> ~/scripts/
└── bin/                # -> ~/bin/
```

## Licencia

MIT — ver [LICENSE](LICENSE). Los wallpapers y assets son míos salvo mención.