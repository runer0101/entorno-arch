# entorno-arch

Mi escritorio en Arch Linux: Hyprland + Waybar + wofi, con un sistema de
**18 rices** intercambiables. Este repo existe para reconstruir el mismo
entorno visual en otra laptop con Arch.

No es un `dotfiles` genérico. Es una copia real de la máquina, no un `dotfiles` genérico. Solo incluye la
parte visual.

---

## Qué incluye y qué no

**Incluye** — solo el escritorio y lo que se ve:

| Carpeta | Qué es |
|---|---|
| `config/hypr/` | Hyprland (config en **Lua**) + 18 rices + scripts + shaders + hyprlock |
| `config/waybar/` | Barra superior (config, common.jsonc, estilos, iconos) |
| `config/swaync/` | Notificaciones + iconos |
| `config/swayosd/` | OSD de volumen/brillo |
| `config/wofi/` | Lanzadores y menús (con temas de pywal) |
| `config/menus/` | Menús propios |
| `config/wlogout/` | Menú de cierre de sesión |
| `config/kitty/` | Terminal kitty |
| `config/alacritty/` | Terminal alacritty |
| `config/gtk-3.0/` | Tema GTK |
| `config/kanshi/` | Perfiles de pantalla |
| `config/cava/` | Visualizador de audio |
| `home/` | `.zshrc`, `.bashrc`, `.gitconfig`, `.fzf.*` |
| `scripts/` | 16 scripts propios |
| `bin/` | 6 ejecutables (Waydroid, minecraft) |

**NO incluye** (a propósito):

- Claves, tokens o credenciales — van aparte en `~/.secrets/keys.env`
- Waydroid como app (solo los scripts que lo lanzan)
- Neovim: era un clon sin modificar de [NvChad/starter](https://github.com/NvChad/starter), no configuración propia
- Android SDK, herramientas de desarrollo, cachés ni datos de apps

---

## Instalar

```bash
git clone https://github.com/runer0101/entorno-arch.git
cd entorno-arch

./install.sh --dry-run    # ver qué haría, sin tocar nada
./install.sh --packages   # instalar todo, incluidos los paquetes
```

Opciones:

- `--dry-run` — simula. No escribe nada en disco.
- `--packages` — además corre `pacman -S` con `packages.txt` (pide sudo).

El instalador:

1. Guarda una copia de lo que ya tengas en `~/.config` en `~/.config-backups/<fecha>/`
2. Copia `config/*` a `~/.config/`
3. Copia `home/*` a tu `~`
4. Copia `scripts/` a `~/scripts/` y `bin/` a `~/bin/`
5. Sustituye el token `__HOME__` por tu ruta real de home

Después: cierra sesión y vuelve a entrar.

**No lo ejecutes con `sudo`** — instalaría las configs en `/root`.

---

## Cómo funciona la portabilidad

Las rutas absolutas están normalizadas con un token `__HOME__` en lugar del
nombre de usuario original. `install.sh` lo reemplaza por `$HOME` en la
máquina destino.

```bash
# en el repo
"include": ["__HOME__/.config/waybar/common.jsonc"]

# después de instalar
"include": ["/home/tunombre/.config/waybar/common.jsonc"]
```

Por eso el repo **copia** los ficheros en vez de hacer symlinks: hay que
reescribir las rutas dentro.

---

## Los rices

`config/hypr/rices/` contiene 18 rices. Cada uno es autocontenido:

```
rices/emilia/
├── config.ini          # configuración del rice
├── theme-config.bash   # colores y tema
├── Bar.bash            # layout de la barra
├── modules.ini         # módulos de waybar
├── preview.webp        # vista previa
└── walls/              # wallpapers
```

- `aline`, `andrea`, `brenda`, `cristina`, `cynthia`, `daniela`, `emilia`,
  `h4ck3r`, `isabel`, `jan`, `karla`, `marisol`, `melissa`, `pamela`,
  `silvia`, `varinka`, `yael`, `z0mbi3`

El actual es **emilia** (migrado desde bspwm; `hyprland.conf.pre-lua` guarda la
versión anterior en hyprlang por si la necesitas).

La config principal `config/hypr/hyprland.lua` está escrita en **Lua** y usa
`os.getenv("HOME")`, así que ya es portable por sí sola.

---

## Requisitos y ajustes manuales

**Hyprland 0.56.1** o superior — la config en Lua necesita esa versión.

**Teclado**: `config/hypr/hyprland.conf` tiene bloques `device{}` para el
`by-tech-gaming-keyboard` con layout `es`. En otra laptop hay que editarlos o
borrarlos (Hyprland los ignora si el dispositivo no existe, pero es más limpio
quitarlos).

**pywal** genera `~/.cache/wal/colors-*.css` en tiempo de ejecución. Los estilos
de wofi lo importan; ejecuta `pywal` con algún tema para que existan.

**Secretos**: crea `~/.secrets/keys.env` con tus claves. El `.zshrc` lo carga
automáticamente si existe (línea 323), pero **el fichero no está en este repo**.

---

## Estructura

```
entorno-arch/
├── install.sh          # instalador
├── packages.txt        # dependencias
├── config/             # -> ~/.config/
├── home/               # -> ~/
├── scripts/            # -> ~/scripts/
└── bin/                # -> ~/bin/
```

---

## Otros repos relacionados

- [`rice-backup`](https://github.com/runer0101/rice-backup) — backup más
  antiguo y completo del rice (incluye apps que aquí no están)
- [`waydroid-config`](https://github.com/runer0101/waydroid-config) — la config
  de Waydroid (GPU AMD + `fake_touch` para Saint Seiya)
- [`dotfiles`](https://github.com/runer0101/dotfiles) — dotfiles de June, ya
  superados por este repo

---

## Licencia

Uso personal. Los wallpapers y assets de los rices son míos salvo mención.