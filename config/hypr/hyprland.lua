-- =============================================================
--  ██╗  ██╗██╗   ██╗██████╗ ██╗      █████╗ ███╗   ██╗██████╗
--  ██║  ██║╚██╗ ██╔╝██╔══██╗██║     ██╔══██╗████╗  ██║██╔══██╗
--  ███████║ ╚████╔╝ ██████╔╝██║     ███████║██╔██╗ ██║██║  ██║
--  ██╔══██║  ╚██╔╝  ██╔═══╝ ██║     ██╔══██║██║╚██╗██║██║  ██║
--  ██║  ██║   ██║   ██║     ██║     ██║  ██║██║ ╚████║██████╔╝
--  ╚═╝  ╚═╝   ╚═╝   ╚═╝     ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═══╝╚═════╝
-- Hyprland 0.56.1 — emilia rice (migración desde bspwm)
-- Config en Lua. La versión hyprlang quedó en hyprland.conf.pre-lua.
-- =============================================================

local HOME = os.getenv("HOME")

-- ---------------------------------------------------------------
-- Helpers para seguir consumiendo los .conf que generan los scripts
-- ---------------------------------------------------------------
-- pywal y gpu-perfil.sh siguen escribiendo en formato hyprlang. En vez de
-- tocar esos scripts (los usa media rice, y gpu-perfil.sh además lo lee
-- .zprofile), se parsean aquí. Así la migración a Lua no arrastra a nadie.

-- Lee ~/.cache/wal/colors-hyprland.conf → { color1 = "rgba(...)", ... }
local function leer_colores_wal()
    local colores = {}
    local f = io.open(HOME .. "/.cache/wal/colors-hyprland.conf", "r")
    if not f then return colores end
    for linea in f:lines() do
        local clave, valor = linea:match("^%s*%$([%w_]+)%s*=%s*(.-)%s*$")
        if clave and valor then colores[clave] = valor end
    end
    f:close()
    return colores
end

-- Lee un .conf con líneas `env = CLAVE,VALOR` y las aplica.
-- OJO: AQ_DRM_DEVICES aquí NO surte efecto (aquamarine ya abrió el backend);
-- de eso se encarga ~/.zprofile antes de lanzar la sesión. Se aplica igual
-- para no perder ninguna otra variable que meta el script.
local function aplicar_env_de_conf(ruta)
    local f = io.open(ruta, "r")
    if not f then return end
    for linea in f:lines() do
        local clave, valor = linea:match("^%s*env%s*=%s*([%w_]+)%s*,%s*(.-)%s*$")
        if clave and valor then hl.env(clave, valor) end
    end
    f:close()
end

local wal = leer_colores_wal()
-- Fallback si pywal todavía no ha generado nada (primer arranque, cache borrada)
local color1 = wal.color1 or "rgba(67,126,129,1.0)"
local color5 = wal.color5 or "rgba(40,40,40,1.0)"

-- ---- Monitor ----
hl.monitor({ output = "",          mode = "preferred",     position = "auto",       scale = 1 })
hl.monitor({ output = "HDMI-A-1",  mode = "1920x1080@60",  position = "auto-right", scale = 1 })

-- ---- Env (NVIDIA hybrid + Qt/Wayland + cursors) ----
-- Perfil de GPU (hibrido = AMD+NVIDIA · movil = solo AMD para que la dGPU duerma).
-- Lo genera ~/scripts/gpu-perfil.sh; va lo primero por coherencia con el orden
-- que tenía el config viejo.
aplicar_env_de_conf(HOME .. "/.config/hypr/gpu-profile.conf")

hl.env("WLR_NO_HARDWARE_CURSORS", "1")
hl.env("WLR_DRM_NO_ATOMIC", "1")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("GDK_BACKEND", "wayland,x11")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("_JAVA_AWT_WM_NONREPARENTING", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "wayland")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("XCURSOR_THEME", "Qogirr-Dark")
hl.env("XCURSOR_SIZE", "24")
-- PATH con scripts de Hyprland primero (migración bspwm → hypr).
-- En Lua se expande $HOME de verdad, no se deja a que lo resuelva el config.
hl.env("PATH", HOME .. "/.config/hypr/scripts:" .. HOME .. "/.local/bin:" ..
                HOME .. "/bin:/usr/local/bin:/usr/bin:/bin")

-- ---- Autostart (orden: dbus → wallpaper daemon → UI) ----
hl.on("hyprland.start", function()
    -- Sincroniza variables de dbus con systemd user (necesario para gsettings en apply-gtk.sh)
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("nm-applet --indicator")
    hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets,ssh")
    hl.exec_cmd("awww-daemon")
    -- Notificaciones
    -- Vía systemd, no directo: la unidad trae Restart=on-failure, así que si swaync
    -- segfaultea (pasó el 26 jul en un callback de PulseAudio) vuelve solo en ~2s.
    -- Lanzado a pelo, systemd no lo posee y el módulo de waybar se queda muerto.
    hl.exec_cmd("systemctl --user start swaync.service")
    hl.exec_cmd("clipcatd")
    hl.exec_cmd("GDK_BACKEND=wayland swayosd-server")
    -- OSD de la lupa: se ancla al cursor (swayosd se sale de la vista al ampliar)
    hl.exec_cmd(HOME .. "/.config/hypr/scripts/zoom-osd.py")
    -- Idle/lock: hypridle + hyprlock (estilo LeyzS)
    hl.exec_cmd("hypridle")
    hl.exec_cmd(HOME .. "/.config/hypr/scripts/wallpaper.sh 2>/dev/null")
    hl.exec_cmd(HOME .. "/.config/hypr/scripts/apply-gtk.sh 2>/dev/null")
    -- Adapta el perfil de GPU al enchufar/quitar la pantalla externa: deja escrito
    -- el que tocará al próximo inicio y avisa solo cuando el cambio te afecta.
    hl.exec_cmd("sleep 5 && " .. HOME .. "/scripts/gpu-perfil-watch.sh")
    -- Refuerza el layout español del CompX: el receptor inalambrico a veces
    -- tarda en aparecer y el hl.device normal no le llega a tiempo al arrancar.
    hl.exec_cmd("sleep 3 && hyprctl eval 'hl.device({ name = \"compx-2.4g-wireless-receiver\", kb_layout = \"es\" })'")
    -- Aviso si el perfil guardado no encaja con lo enchufado. La reparación de
    -- gpu-profile.conf NO va aquí: para eso ya es tarde (Hyprland ya arrancó), la
    -- hace ~/.zprofile antes de lanzar la sesión.
    hl.exec_cmd("sleep 6 && " .. HOME .. "/scripts/gpu-perfil.sh notificar")
    -- El cable manda: enciende el HDMI al enchufarlo (aunque una regla vieja lo
    -- dejara en "disable") y reenciende el portátil si quitas el cable estando en
    -- modo "solo monitor". Ver ~/scripts/pantalla-watch.sh.
    hl.exec_cmd("sleep 4 && " .. HOME .. "/scripts/pantalla-watch.sh")

    -- Waybar estilo polybar emilia (gris, brackets, módulos custom)
    hl.exec_cmd("waybar -c " .. HOME .. "/.config/waybar/config.jsonc -s " ..
                HOME .. "/.config/waybar/style.css")
    -- Repinta los workspaces de la barra al vuelo. Los módulos custom/wsN llevan
    -- "interval": "once", así que sin esto se quedarían congelados: el listener
    -- oye el socket2 de Hyprland y le manda SIGRTMIN+8 a waybar cuando cambia el
    -- workspace activo o se abre/cierra una ventana.
    hl.exec_cmd(HOME .. "/.local/bin/waybar-ws-listener")
    -- El contador de updates lo refresca ArchUpdates.timer (cada 15 min, enabled y
    -- Persistent=true). Antes había además `Updates --daemon`, que hacía EXACTAMENTE
    -- lo mismo en un `while true; sleep 900`: duplicaba las consultas de
    -- `checkupdates` y `paru -Qua` (esta última va por red a la RPC del AUR) y ambos
    -- escribían Updates.txt sin bloqueo. El timer gana porque sobrevive a reinicios
    -- de Hyprland y recupera las pasadas perdidas.
end)

-- ---- Inputs ----
hl.config({
    input = {
        kb_layout    = "us",
        follow_mouse = 1,
        sensitivity  = 0,
        accel_profile = "flat",
        touchpad = {
            natural_scroll       = true,
            tap_to_click         = true,
            disable_while_typing = true,
        },
    },
})

-- ---- Teclado externo CompX en español ----
hl.device({
    name = "compx-2.4g-wireless-receiver-1",
    kb_layout = "es",
})
hl.device({
    name = "compx-2.4g-wireless-receiver-keyboard",
    kb_layout = "es",
})
hl.device({
    name = "compx-2.4g-wireless-receiver-keyboard-2",
    kb_layout = "es",
})

-- ---- Teclado externo BYTECH en español ----
hl.device({
    name = "by-tech-gaming-keyboard",
    kb_layout = "es",
})

-- ---- General (estilo By-LeyzS: bordes degradados desde el wallpaper) ----
hl.config({
    general = {
        gaps_in     = 5,
        gaps_out    = 20,
        border_size = 2,
        col = {
            active_border   = { colors = { color1, color5, color1 }, angle = 0 },
            inactive_border = "rgba(414868aa)",
        },
        resize_on_border = true,
        layout           = "dwindle",
        allow_tearing    = false,
    },
})

-- ---- Decoration (estilo By-LeyzS) ----
hl.config({
    decoration = {
        rounding         = 10,
        active_opacity   = 1.0,
        inactive_opacity = 1.0,
        blur = {
            enabled           = true,
            size              = 3,
            passes            = 2,
            new_optimizations = true,
            ignore_opacity    = true,
            vibrancy          = 0.1696,
        },
        shadow = {
            enabled      = true,
            range        = 10,
            render_power = 3,
            color        = "rgba(1a1a1aee)",
        },
        dim_inactive = false,
    },
})

-- ---- Animations (estilo By-LeyzS) ----
hl.config({ animations = { enabled = true } })

hl.curve("firlat",       { type = "bezier", points = { {0.25, 1},   {0.5,  1}    } })
hl.curve("wind",         { type = "bezier", points = { {0.05, 0.9}, {0.1,  1.0}  } })
hl.curve("winIn",        { type = "bezier", points = { {0.05, 0.9}, {0.1,  1.01} } })
hl.curve("winOut",       { type = "bezier", points = { {0.7,  0},   {0.1,  1.0}  } })
hl.curve("liner",        { type = "bezier", points = { {1,    1},   {1,    1}    } })
hl.curve("almostLinear", { type = "bezier", points = { {0.5,  0.5}, {0.75, 1.0}  } })

hl.animation({ leaf = "windows",     enabled = true, speed = 10,   bezier = "wind",         style = "slide"        })
hl.animation({ leaf = "windowsIn",   enabled = true, speed = 10,   bezier = "winIn",        style = "popin 80%"    })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 4,    bezier = "wind",         style = "slide"        })
hl.animation({ leaf = "layersIn",    enabled = true, speed = 5,    bezier = "firlat",       style = "slide bottom" })
hl.animation({ leaf = "layersOut",   enabled = true, speed = 4,    bezier = "firlat",       style = "slide bottom" })
hl.animation({ leaf = "border",      enabled = true, speed = 1,    bezier = "liner"        })
hl.animation({ leaf = "workspaces",  enabled = true, speed = 5,    bezier = "wind",         style = "slide"        })
hl.animation({ leaf = "fadeIn",      enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",     enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",        enabled = true, speed = 3.03, bezier = "almostLinear" })

-- ---- Dwindle (bspwm-like splits; pseudotile removido en 0.55) ----
hl.config({ dwindle = { preserve_split = true } })

-- =====================================================
--  KEYBINDINGS (migrados desde sxhkdrc + bspwmrc)
--  En Lua los modificadores se unen con '+', no con espacios.
-- =====================================================

local mainMod = "SUPER"
local altMod  = "ALT"

-- Mouse: Super + click izq arrastra la ventana, Super + click der la redimensiona
hl.bind(mainMod .. "+mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. "+mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Perfil de GPU: alterna móvil (dGPU dormida) / híbrido (HDMI). Abre una
-- terminal porque el cambio pide reiniciar Hyprland y hay que confirmarlo.
hl.bind(mainMod .. "+SHIFT+G", hl.dsp.exec_cmd("kitty -e " .. HOME .. "/scripts/gpu-perfil.sh menu"))

hl.bind(mainMod .. "+Return",       hl.dsp.exec_cmd("OpenApps --terminal"))
hl.bind(mainMod .. "+ALT+Return",   hl.dsp.exec_cmd("OpenApps --floating"))
hl.bind(mainMod .. "+B",            hl.dsp.exec_cmd('wofi --show drun --allow-images --width 720 --height 460 --prompt "  buscar..."'))
hl.bind(mainMod .. "+Space",        hl.dsp.exec_cmd("OpenApps --menu"))
hl.bind(altMod  .. "+space",        hl.dsp.exec_cmd("OpenApps --rice"))
hl.bind(mainMod .. "+E",            hl.dsp.exec_cmd("OpenApps --editor"))
hl.bind(mainMod .. "+F",            hl.dsp.exec_cmd("OpenApps --filemanager"))
hl.bind(mainMod .. "+Y",            hl.dsp.exec_cmd("OpenApps --yazi"))
hl.bind(mainMod .. "+V",            hl.dsp.exec_cmd("OpenApps --nvim"))
hl.bind(mainMod .. "+M",            hl.dsp.window.fullscreen(0))
hl.bind(mainMod .. "+P",            hl.dsp.exec_cmd("OpenApps --soundcontrol"))
hl.bind(mainMod .. "+T",            hl.dsp.exec_cmd("OpenApps --telegram"))
hl.bind(mainMod .. "+R",            hl.dsp.exec_cmd("OpenApps --riceedit"))

-- ---- Rofi applets ----
hl.bind(mainMod .. "+ALT+T", hl.dsp.exec_cmd("Term --selecterm"))
hl.bind(mainMod .. "+ALT+W", hl.dsp.exec_cmd("OpenApps --wallpaper"))
hl.bind(mainMod .. "+ALT+A", hl.dsp.exec_cmd("OpenApps --android"))
hl.bind(mainMod .. "+ALT+N", hl.dsp.exec_cmd("OpenApps --netmanager"))
-- OJO: SUPER+SHIFT+B estaba declarado dos veces en el config viejo (--browser
-- arriba y --bluetooth aquí). Se conserva tal cual; ver nota en el informe.
hl.bind(mainMod .. "+SHIFT+B", hl.dsp.exec_cmd("OpenApps --browser"))
hl.bind(mainMod .. "+ALT+C", hl.dsp.exec_cmd("OpenApps --clipboard"))
hl.bind(mainMod .. "+ALT+S", hl.dsp.exec_cmd("OpenApps --screenshot"))
hl.bind(mainMod .. "+ALT+P", hl.dsp.exec_cmd("OpenApps --powermenu"))
hl.bind(mainMod .. "+ALT+K", hl.dsp.exec_cmd("OpenApps --keyboard"))
hl.bind(mainMod .. "+ALT+X", hl.dsp.exec_cmd("OpenApps --pass"))

-- ---- Screenshots ----
-- PrtSc congela la pantalla y abre menú clickeable (ScreenShoTer): guarda en
-- ~/Pictures/Screenshots y copia al portapapeles. Al congelar antes de dibujar
-- el menú, los tooltips y popups abiertos sobreviven a la captura.
hl.bind("Print",       hl.dsp.exec_cmd("OpenApps --screenshot"))
-- SHIFT+PrtSc va directo a seleccionar región sobre la pantalla congelada
hl.bind("SHIFT+Print", hl.dsp.exec_cmd(HOME .. "/.config/hypr/scripts/ScreenShoTer --region"))

-- ---- Window management ----
hl.bind(mainMod .. "+Q",       hl.dsp.window.close())
-- super+alt+f = maximizar (alias de alt+f, por si el pulgar toca Super)
hl.bind(mainMod .. "+ALT+F",   hl.dsp.window.fullscreen(1))
hl.bind(mainMod .. "+SHIFT+F", hl.dsp.window.float({ action = "toggle" }))

-- ---- Cambiar de workspace (flechas + a/d) | foco: super+alt ----
hl.bind(mainMod .. "+left",  hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. "+right", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. "+up",    hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. "+down",  hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. "+a",     hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. "+d",     hl.dsp.focus({ workspace = "e+1" }))

hl.bind(mainMod .. "+ALT+left",  hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. "+ALT+right", hl.dsp.focus({ direction = "r" }))
hl.bind(mainMod .. "+ALT+up",    hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. "+ALT+down",  hl.dsp.focus({ direction = "d" }))
hl.bind(mainMod .. "+ALT+a",     hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. "+ALT+s",     hl.dsp.focus({ direction = "d" }))
hl.bind(mainMod .. "+ALT+w",     hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. "+ALT+d",     hl.dsp.focus({ direction = "r" }))

-- ---- Swap windows ----
hl.bind("CTRL+ALT+left",  hl.dsp.window.swap({ direction = "l" }))
hl.bind("CTRL+ALT+right", hl.dsp.window.swap({ direction = "r" }))
hl.bind("CTRL+ALT+up",    hl.dsp.window.swap({ direction = "u" }))
hl.bind("CTRL+ALT+down",  hl.dsp.window.swap({ direction = "d" }))
hl.bind("CTRL+ALT+a",     hl.dsp.window.swap({ direction = "l" }))
hl.bind("CTRL+ALT+s",     hl.dsp.window.swap({ direction = "d" }))
hl.bind("CTRL+ALT+w",     hl.dsp.window.swap({ direction = "u" }))
hl.bind("CTRL+ALT+d",     hl.dsp.window.swap({ direction = "r" }))

-- ---- Move/resize (mouse-like) ----
local rep = { repeating = true }
hl.bind(mainMod .. "+SHIFT+up",    hl.dsp.window.resize({ x =   0, y = -20, relative = true }), rep)
hl.bind(mainMod .. "+SHIFT+down",  hl.dsp.window.resize({ x =   0, y =  20, relative = true }), rep)
hl.bind(mainMod .. "+SHIFT+left",  hl.dsp.window.resize({ x = -20, y =   0, relative = true }), rep)
hl.bind(mainMod .. "+SHIFT+right", hl.dsp.window.resize({ x =  20, y =   0, relative = true }), rep)

hl.bind(mainMod .. "+SHIFT+w", hl.dsp.window.resize({ x =   0, y = -20, relative = true }), rep)
hl.bind(mainMod .. "+SHIFT+s", hl.dsp.window.resize({ x =   0, y =  20, relative = true }), rep)
hl.bind(mainMod .. "+SHIFT+a", hl.dsp.window.resize({ x = -20, y =   0, relative = true }), rep)
hl.bind(mainMod .. "+SHIFT+d", hl.dsp.window.resize({ x =  20, y =   0, relative = true }), rep)

-- ---- Move window (sin resize) ----
hl.bind(mainMod .. "+SHIFT+CTRL+left",  hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. "+SHIFT+CTRL+right", hl.dsp.window.move({ direction = "r" }))
hl.bind(mainMod .. "+SHIFT+CTRL+up",    hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. "+SHIFT+CTRL+down",  hl.dsp.window.move({ direction = "d" }))

-- ---- Mover ventana (teclado, ±20px; flota primero si esta tiled) ----
local mv = HOME .. "/.config/hypr/scripts/move-window.sh"
hl.bind(altMod .. "+left",  hl.dsp.exec_cmd(mv .. " -20 0"), rep)
hl.bind(altMod .. "+right", hl.dsp.exec_cmd(mv .. " 20 0"), rep)
hl.bind(altMod .. "+up",    hl.dsp.exec_cmd(mv .. " 0 -20"), rep)
hl.bind(altMod .. "+down",  hl.dsp.exec_cmd(mv .. " 0 20"), rep)
hl.bind(altMod .. "+a", hl.dsp.exec_cmd(mv .. " -20 0"), rep)
hl.bind(altMod .. "+d", hl.dsp.exec_cmd(mv .. " 20 0"), rep)
hl.bind(altMod .. "+w", hl.dsp.exec_cmd(mv .. " 0 -20"), rep)
hl.bind(altMod .. "+s", hl.dsp.exec_cmd(mv .. " 0 20"), rep)

-- ---- Workspaces ----
for i = 1, 10 do
    local tecla = i % 10 -- el 10 va en la tecla 0
    hl.bind(mainMod .. "+" .. tecla,          hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. "+SHIFT+" .. tecla,    hl.dsp.window.move({ workspace = i }))
end

-- ---- Special ----
hl.bind(mainMod .. "+CTRL+B",    hl.dsp.exec_cmd(HOME .. "/.config/hypr/scripts/reload.sh"))
hl.bind(mainMod .. "+ALT+Escape", hl.dsp.window.cycle_next({ prev = true }))
hl.bind(altMod  .. "+F4",        hl.dsp.window.cycle_next({ prev = true }))
hl.bind(mainMod .. "+ALT+L",     hl.dsp.exec_cmd(HOME .. "/.config/hypr/scripts/lock.sh"))
hl.bind("CTRL+ALT+L",            hl.dsp.exec_cmd(HOME .. "/.config/hypr/scripts/lock.sh"))

-- ---- Wallpapers estilo By-LeyzS (pywal sincroniza toda la UI) ----
-- super+w = selector de wallpaper estático (wofi)
hl.bind(mainMod .. "+W",      hl.dsp.exec_cmd(HOME .. "/.config/hypr/scripts/wallpapers/set-wallpaper.sh"))
-- super+ctrl+w = wallpaper aleatorio
hl.bind(mainMod .. "+CTRL+W", hl.dsp.exec_cmd(HOME .. "/.config/hypr/scripts/wallpapers/random-wallpaper.sh"))
-- super+k = wallpaper animado (.mp4 en ~/Videos/LiveWallpapers, requiere mpvpaper)
hl.bind(mainMod .. "+K",      hl.dsp.exec_cmd(HOME .. "/.config/hypr/scripts/wallpapers/live-wallpaper.sh"))
-- super+ctrl+k = cortar vídeo y volver a estático
hl.bind(mainMod .. "+CTRL+K", hl.dsp.exec_cmd(HOME .. "/.config/hypr/scripts/back-to-static.sh"))
-- super+ctrl+v = toggle shader vibrance
hl.bind(mainMod .. "+CTRL+V", hl.dsp.exec_cmd(HOME .. "/.config/hypr/shaders/switch_shader.sh"))

-- ---- Audio (swayosd-client → OSD como notificación, no ventana) ----
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("swayosd-client --output-volume raise"),        rep)
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("swayosd-client --output-volume lower"),        rep)
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("swayosd-client --output-volume mute-toggle"))
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("swayosd-client --input-volume mute-toggle"),   rep)
hl.bind("XF86AudioPlay",        hl.dsp.exec_cmd("swayosd-client --playerctl play-pause"),       rep)
hl.bind("XF86AudioNext",        hl.dsp.exec_cmd("swayosd-client --playerctl next"),             rep)
hl.bind("XF86AudioPrev",        hl.dsp.exec_cmd("swayosd-client --playerctl previous"),         rep)

-- ---- Brightness (swayosd-client → OSD como notificación) ----
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("swayosd-client --brightness raise"), rep)
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("swayosd-client --brightness lower"), rep)

-- =====================================================
--  BINDS EXTRA (migrados del sxhkdrc de bspwm)
-- =====================================================

-- ---- Close / Kill (X11 bspwm) ----
-- super + x = cerrar ventana enfocada (era el principal en bspwm)
hl.bind(mainMod .. "+X",       hl.dsp.exec_cmd(HOME .. "/.config/hypr/scripts/close-window.sh"))
-- super + shift + x = forzar cierre
hl.bind(mainMod .. "+SHIFT+X", hl.dsp.exec_cmd(HOME .. "/.config/hypr/scripts/close-window.sh"))
-- super + ctrl + x = cerrar TODO el workspace actual
hl.bind(mainMod .. "+CTRL+X",  hl.dsp.exec_cmd(HOME .. "/.config/hypr/scripts/close-workspace.sh"))

-- ---- Acorde super+N seguido de tecla (bspwm: super + n + ...) ----
-- Los acordes con ';' de hyprlang no existen en Lua: se hacen con submaps.
-- "reset" hace que cualquier tecla no vinculada devuelva al mapa normal.
hl.define_submap("nmode", "reset", function()
    -- super + n + x = cerrar todas las demás (mantiene la enfocada)
    hl.bind("X", hl.dsp.exec_cmd(HOME .. "/.config/hypr/scripts/close-others.sh"))
    -- super + n + k = matar (force) todas las demás
    hl.bind("K", hl.dsp.exec_cmd(HOME .. "/.config/hypr/scripts/kill-others.sh"))
    -- super + n + m = no migrable (bspwm "marked" no existe en Hyprland)
    -- super + n + {1-9} = traer todo de workspace N al actual
    for i = 1, 9 do
        hl.bind(tostring(i), hl.dsp.exec_cmd(HOME .. "/.config/hypr/scripts/grab-ws.sh " .. i))
    end
    hl.bind("escape", hl.dsp.submap("reset"))
end)
hl.bind(mainMod .. "+N", hl.dsp.submap("nmode"))

-- ---- Node states (bspwm alt+t/a/f/etc) ----
-- alt + t = toggle floating (activa/desactiva; luego mover con alt+flechas)
hl.bind(altMod .. "+T", hl.dsp.window.float({ action = "toggle" }))
-- alt + f = maximizar (resize al area util, respeta waybar)
-- waybar es overlay => no reserva espacio; fullscreen(0) la tapa.
-- Script: float + resize exact + move al area util. Ver maximize-respect-waybar.sh
hl.bind(altMod .. "+F", hl.dsp.exec_cmd(HOME .. "/.config/hypr/scripts/maximize-respect-waybar.sh"))
-- alt + shift + f = true fullscreen (tapa waybar)
hl.bind(altMod .. "+SHIFT+F", hl.dsp.window.fullscreen(1))
-- alt + space no, eso es el rice selector

-- ---- Pin / Sticky (bspwm alt+s) ----
hl.bind(altMod .. "+S",       hl.dsp.window.pin())
-- Toggle pin
hl.bind(altMod .. "+SHIFT+S", hl.dsp.window.pin())

-- ---- Window switcher (alt+Tab en bspwm) ----
hl.bind(altMod .. "+Tab", hl.dsp.exec_cmd(HOME .. "/.config/hypr/scripts/window-switcher.sh"))

-- ---- Toggle split / rotate (ctrl+Tab en bspwm) ----
hl.bind("CTRL+Tab", hl.dsp.exec_cmd(HOME .. "/.config/hypr/scripts/rotate.sh"))

-- ---- Move floating window (super+ctrl+plus/minus en bspwm) ----
-- Ya hay resize con super+shift+aswd; estos eran zoom para floating
hl.bind(mainMod .. "+CTRL+equal", hl.dsp.window.resize({ x =  50, y =  25, relative = true }), rep)
hl.bind(mainMod .. "+CTRL+minus", hl.dsp.window.resize({ x = -50, y = -25, relative = true }), rep)

-- ---- Scratchpad (super+alt+o en bspwm) ----
hl.bind(mainMod .. "+ALT+O",   hl.dsp.exec_cmd(HOME .. "/.config/hypr/scripts/scratchpad.sh"))
hl.bind(mainMod .. "+SHIFT+O", hl.dsp.workspace.toggle_special())

-- ---- System power (ctrl+super+alt+{p,r,q,l,k,s} en bspwm) ----
hl.bind(mainMod .. "+CTRL+ALT+P", hl.dsp.exec_cmd("systemctl poweroff"))
hl.bind(mainMod .. "+CTRL+ALT+R", hl.dsp.exec_cmd("systemctl reboot"))
hl.bind(mainMod .. "+CTRL+ALT+Q", hl.dsp.exit())
hl.bind(mainMod .. "+CTRL+ALT+K", hl.dsp.window.close())
hl.bind(mainMod .. "+CTRL+ALT+S", hl.dsp.exec_cmd(HOME .. "/.config/hypr/scripts/soft-reload.sh"))

-- ---- Soft reload (super+Escape en bspwm = pkill -USR1 sxhkd) ----
hl.bind(mainMod .. "+Escape", hl.dsp.exec_cmd(HOME .. "/.config/hypr/scripts/soft-reload.sh"))

-- ---- Opacity (ctrl+alt+{plus,minus,t} en bspwm: picom-trans) ----
-- En Hyprland no aplica directamente, el blur/opacity son nativos
hl.bind("CTRL+ALT+plus",  hl.dsp.exec_cmd(HOME .. "/.config/hypr/scripts/opacity.sh +"))
hl.bind("CTRL+ALT+equal", hl.dsp.exec_cmd(HOME .. "/.config/hypr/scripts/opacity.sh +"))
hl.bind("CTRL+ALT+minus", hl.dsp.exec_cmd(HOME .. "/.config/hypr/scripts/opacity.sh -"))
hl.bind("CTRL+ALT+T",     hl.dsp.exec_cmd(HOME .. "/.config/hypr/scripts/opacity.sh d"))

-- ---- Lupa / zoom de pantalla (equivalente a la lupa de Windows) ----
-- Zoom nativo de Hyprland, sigue al cursor. Pasos de 0.25, tope x5
-- Bindeado por KEYCODE, no por keysym: es independiente de la distribucion
-- y evita el lio de latam (la tecla + da "plus", y con SHIFT el - da
-- "underscore"). code:35 = tecla + (AD12) | code:61 = tecla - (AB10)
local zoom = HOME .. "/.config/hypr/scripts/zoom.sh "
hl.bind(mainMod .. "+code:35",       hl.dsp.exec_cmd(zoom .. "+"),     rep)
hl.bind(mainMod .. "+code:61",       hl.dsp.exec_cmd(zoom .. "-"),     rep)
hl.bind(mainMod .. "+SHIFT+code:61", hl.dsp.exec_cmd(zoom .. "reset"))
-- Mismo par en el teclado numerico (code:86 = KP+ | code:82 = KP-)
hl.bind(mainMod .. "+code:86", hl.dsp.exec_cmd(zoom .. "+"), rep)
hl.bind(mainMod .. "+code:82", hl.dsp.exec_cmd(zoom .. "-"), rep)

-- Mismo par con CTRL+SHIFT, a juego con la rueda. CTRL a secas se descarto:
-- lo captura el compositor y el navegador se queda sin su CTRL + +.
-- OJO: aqui SI hay que anadir SHIFT al keycode del +, pero el keycode es el
-- mismo se pulse o no SHIFT, asi que basta con declarar el modificador.
hl.bind("CTRL+SHIFT+code:35", hl.dsp.exec_cmd(zoom .. "+"), rep)
hl.bind("CTRL+SHIFT+code:61", hl.dsp.exec_cmd(zoom .. "-"), rep)
hl.bind("CTRL+SHIFT+code:86", hl.dsp.exec_cmd(zoom .. "+"), rep)
hl.bind("CTRL+SHIFT+code:82", hl.dsp.exec_cmd(zoom .. "-"), rep)
hl.bind("CTRL+SHIFT+code:19", hl.dsp.exec_cmd(zoom .. "reset"))

-- ---- Lupa con la rueda del raton: CTRL+SHIFT + scroll ----
-- No depende del keysym ni de la distribucion del teclado.
-- Con SHIFT ademas de CTRL para no pisar el zoom del navegador, que usa
-- CTRL+rueda: antes el compositor se comia el scroll y la pagina no ampliaba.
hl.bind("CTRL+SHIFT+mouse_up",   hl.dsp.exec_cmd(zoom .. "+"))
hl.bind("CTRL+SHIFT+mouse_down", hl.dsp.exec_cmd(zoom .. "-"))
hl.bind("CTRL+SHIFT+mouse:274",  hl.dsp.exec_cmd(zoom .. "reset"))

-- ---- Help (alt+F1 en bspwm: OpenApps --KeyHelp) ----
-- Eww no funciona en Wayland → muestra el cheatsheet via wofi
hl.bind(altMod .. "+F1", hl.dsp.exec_cmd('kitty --hold -e "less ' .. HOME .. '/notes/keybindings.md"'))

-- ---- Bring all to current workspace direction (bspwm: super+ctrl+{Left,Right}) ----
hl.bind(mainMod .. "+CTRL+left",  hl.dsp.window.move({ workspace = "e-1" }))
hl.bind(mainMod .. "+CTRL+right", hl.dsp.window.move({ workspace = "e+1" }))

-- ---- Send to next/prev workspace (bspwm: super+ctrl+aswd) ----
hl.bind(mainMod .. "+CTRL+A", hl.dsp.window.move({ workspace = "e-1" }))
hl.bind(mainMod .. "+CTRL+D", hl.dsp.window.move({ workspace = "e+1" }))

-- ---- Preselect (bspwm: super+ctrl+h/v/q) — no migrado (no aplica en dwindle) ----

-- ---- Workspace back/forward (bspwm: super+Tab+aswd) ----
-- Otro acorde: super+Tab y luego dirección.
hl.define_submap("tabmode", "reset", function()
    hl.bind("left",   hl.dsp.focus({ workspace = "e-1" }))
    hl.bind("right",  hl.dsp.focus({ workspace = "e+1" }))
    hl.bind("A",      hl.dsp.focus({ workspace = "e-1" }))
    hl.bind("D",      hl.dsp.focus({ workspace = "e+1" }))
    hl.bind("escape", hl.dsp.submap("reset"))
end)
hl.bind(mainMod .. "+Tab", hl.dsp.submap("tabmode"))

-- ---- Focus last node/desktop (bspwm: ctrl+shift+comma/period) ----
-- Hyprland no tiene "last" exactamente; usa cyclenext
hl.bind("CTRL+SHIFT+comma",  hl.dsp.window.cycle_next({ prev = true }))
hl.bind("CTRL+SHIFT+period", hl.dsp.window.cycle_next())

-- =====================================================
--  WINDOW RULES
-- =====================================================

-- Floating por defecto para herramientas puntuales
for _, clase in ipairs({ "pavucontrol", "blueman-manager", "nm-connection-editor",
                         "pamac-manager", "qt5ct", "qt6ct", "thunar", "nm-applet" }) do
    hl.window_rule({
        name  = "float-" .. clase,
        match = { class = "^(" .. clase .. ")$" },
        float = true,
    })
end

-- Waybar oculto de Alt+Tab (ws 99 + silent)
-- (eww removido: no funciona en Wayland nativo)
hl.window_rule({
    name      = "waybar-ws99",
    match     = { class = "^(waybar)$" },
    workspace = "99 silent",
})

-- Opacidad 1 en terminales nativos
-- Estas dos estaban desactivadas en el config viejo porque la sintaxis de
-- opacity pedía config en Lua. Ya se puede, pero 1.0 es el valor por defecto
-- así que no cambiarían nada; se dejan comentadas a propósito.
-- hl.window_rule({ name = "op-kitty",     match = { class = "^(kitty)$" },     opacity = 1.0 })
-- hl.window_rule({ name = "op-alacritty", match = { class = "^(Alacritty)$" }, opacity = 1.0 })

-- Tamaño + centrado inicial
hl.window_rule({ name = "size-thunar", match = { class = "^(Thunar)$" },      size = "800 600" })

-- Dropdown terminal (estilo wlogout): es un cliente layer-shell, pero Hyprland
-- igual puede intentar gestionarlo si no lo neutralizamos. Forzamos a:
--   - no tiling (flota en el centro por defecto del compositor),
--   - sin foco automático al abrir (su propio gtk-layer-shell ya gestiona foco),
--   - no animación de entrada (sale "de golpe" como wlogout).
--   - workspace silent 99 para que no aparezca en la barra de espacios.
--   - pin: la capa overlay ya está por encima de todo; pin evita que Hyprland
--     la mueva si por error se enfocara otra ventana.
--   - keep aspect ratio desactivado, lo gestiona gtk-layer-shell.
hl.window_rule({
    name     = "ddt",
    match    = { class = "^(DropdownTerm)$" },
    float    = true,
    no_focus = false,    -- sí puede tomar foco; lo soltará al click fuera
    no_anim  = true,
    pin      = true,
    workspace = "99 silent",
})
hl.layer_rule({
    name  = "ddt-blur",
    match = { namespace = "^(dropdown-term)$" },
    blur  = false,        -- blur con NVIDIA parpadea, igual que waybar
})
hl.window_rule({ name = "size-pavu",   match = { class = "^(pavucontrol)$" }, size = "30% 60%" })
hl.window_rule({ name = "center-pavu", match = { class = "^(pavucontrol)$" }, center = true })

-- QR de WiFi (feh --class qrwifi): flotante, cuadrada y centrada, no en mosaico.
hl.window_rule({ name = "float-qrwifi",  match = { class = "^(qrwifi)$" }, float  = true })
hl.window_rule({ name = "size-qrwifi",   match = { class = "^(qrwifi)$" }, size   = "420 470" })
hl.window_rule({ name = "center-qrwifi", match = { class = "^(qrwifi)$" }, center = true })

-- Wofi en modo VENTANA (--normal-window): flotante y centrada, para poder
-- arrastrarlo con SUPER+ratón. El menú de red (NetManagerDM) también va en
-- este modo, a propósito: en layer-shell la superficie agarra el teclado en
-- exclusiva y bloquea el escritorio entero mientras está abierta. El cierre
-- con clic fuera lo resuelve un bind del compositor (netmenu-clic.sh), no
-- estas reglas. Los wofi layer-shell (el launcher) no son clientes y no
-- casan con esta regla.
hl.window_rule({ name = "float-wofi",  match = { class = "^(wofi)$" }, float  = true })
hl.window_rule({ name = "center-wofi", match = { class = "^(wofi)$" }, center = true })

-- =====================================================
--  LAYER RULES
-- =====================================================

-- blur en waybar desactivado: parpadeo con NVIDIA
-- Blur de swaync DESACTIVADO: dejaba ver el escritorio borroso por los márgenes
-- del panel y detrás de las notificaciones. Se quiere todo limpio y sólido.
hl.layer_rule({ name = "blur-swaync-cc",  match = { namespace = "swaync-control-center" },    blur = false })
hl.layer_rule({ name = "blur-swaync-not", match = { namespace = "swaync-notification-window" }, blur = false })

-- =====================================================
--  WORKSPACE RULES
--  Asignación dinámica: 1-5 al primario, 6-10 al secundario
--  (si no hay segundo monitor, caen al primario automáticamente)
-- =====================================================

for i = 1, 5 do
    hl.workspace_rule({
        workspace  = tostring(i),
        monitor    = "eDP-1",
        persistent = true,
        default    = (i == 1) or nil,
    })
end
for i = 6, 10 do
    hl.workspace_rule({
        workspace  = tostring(i),
        monitor    = "HDMI-A-1",
        persistent = true,
    })
end




