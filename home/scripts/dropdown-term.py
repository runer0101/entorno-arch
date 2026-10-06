#!/usr/bin/env python3
# =============================================================
#  dropdown-term.py — Terminal desplegable estilo wlogout
#
#  Abre una ventana con gtk-layer-shell en la capa "overlay"
#  (encima de todo, como wlogout), con foco de teclado exclusivo.
#  Se cierra al perder el foco (click fuera, Alt+Tab, etc.),
#  exactamente igual que el menú de power del waybar.
#
#  Inspirado en:
#    - wlogout -b 5 -c 0 -p layer-shell   (menú power del waybar)
#    - foot --server (modo daemon)
#
#  Dependencias (todas ya instaladas):
#    gtk3, gtk-layer-shell, vte3, python-gobject
#
#  Uso:
#    dropdown-term.py                 → terminal normal (login shell)
#    dropdown-term.py --command bash  → comando concreto
#    dropdown-term.py --height 50     → alto en % de pantalla (default 45)
#    dropdown-term.py --width 70      → ancho en % de pantalla (default 80)
# =============================================================

import argparse
import os
import signal
import sys

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
gi.require_version("Vte", "2.91")
gi.require_version("Gio", "2.0")

from gi.repository import Gtk, GObject, GtkLayerShell, Vte, GLib, Pango, Gdk, Gio  # noqa: E402

# ── Argumentos ────────────────────────────────────────────────
ap = argparse.ArgumentParser(description="Dropdown terminal al estilo wlogout")
ap.add_argument("--command", "-e", default=os.environ.get("SHELL", "bash"),
                help="Comando a ejecutar (default: $SHELL)")
ap.add_argument("--title", "-T", default="Dropdown Terminal",
                help="Título de la ventana")
ap.add_argument("--height", type=int, default=45,
                help="Alto en porcentaje de la pantalla (default: 45)")
ap.add_argument("--width", type=int, default=80,
                help="Ancho en porcentaje de la pantalla (default: 80)")
ap.add_argument("--margin-top", type=int, default=56,
                help="Margen superior en px (debajo de la waybar=48 + margen=6)")
args = ap.parse_args()

# ── Estado global para el callback de focus-out ───────────────
HOLD_REF = {"keep": True, "ready": False}  # ready: ignora focus-out iniciales


def focus_out(window, _event):
    """Se ejecuta cuando la ventana pierde el foco (click fuera, Alt+Tab…)."""
    if not HOLD_REF["ready"]:
        return False  # foco aún no asentado, ignora
    # Damos un margen de 80 ms para que un click dentro no la cierre antes
    # de procesarse (p. ej. cuando el botón de waybar hace click→spawn→focus in).
    GLib.timeout_add(80, _delayed_quit, window)
    return False


def _delayed_quit(window):
    """Cierra la ventana en el siguiente tick del main loop."""
    if not HOLD_REF["keep"]:
        return False
    HOLD_REF["keep"] = False
    window.destroy()
    Gtk.main_quit()
    return False


def vte_child_exited(_vte, exit_status, _user):
    """Cuando el shell sale, cerramos la ventana."""
    GLib.idle_add(_delayed_quit, _terminal_window())


_terminal_window_ref = {"win": None}


def _terminal_window():
    return _terminal_window_ref["win"]


# ── Crear ventana ─────────────────────────────────────────────
win = Gtk.Window()
_terminal_window_ref["win"] = win
win.set_title(args.title)
# wmclass en GTK3+ Wayland: usamos Gtk.Wayland API o simplemente skip,
# la class ya la pone el compositor según el WM_CLASS por defecto.
# No usamos set_wmclass (deprecated). En su lugar forzamos vía WM_CLASS más
# abajo con Gdk.set_program_class para que Hyprland matchee "DropdownTerm".
Gdk.set_program_class("DropdownTerm")
win.set_resizable(True)
win.set_decorated(False)
win.set_app_paintable(True)

# ── VTE (el terminal real) ───────────────────────────────────
vte = Vte.Terminal()
vte.set_cursor_blink_mode(Vte.CursorBlinkMode.ON)
vte.set_audible_bell(False)
vte.set_scrollback_lines(10000)
vte.set_font(Pango.FontDescription.from_string("JetBrainsMono Nerd Font 12"))
# Tamaño mínimo razonable: si gtk-layer-shell no fija uno (p. ej., porque
# está anclado solo a TOP/LEFT/RIGHT), GTK colapsa a 0×24. Forzamos un mínimo.
vte.set_size_request(800, 400)

# Fork del proceso hijo (fork+execve, como hace una PTY real)
# Usamos Vte.Terminal.spawn_async para PTY + señales correctas.
def _spawn_shell():
    # En gi 0.84 / VTE 2.91 hay un bug con spawn_async + argumentos posicionales
    # ("Argument 9 does not allow None as a value") cuando el callback es None.
    # Workaround: keyword args. Y VTE ya gestiona DO_NOT_REAP_CHILD por su
    # cuenta, así que NO lo pasamos (warning explícito en runtime).
    holder = []
    vte.spawn_async(
        pty_flags=Vte.PtyFlags.DEFAULT,
        working_directory=os.environ.get("HOME"),
        argv=[args.command],
        envv=None,                          # heredar
        child_setup=None,
        timeout=-1,
        spawn_flags=GLib.SpawnFlags(0),     # VTE gestiona reaping solo
        cancellable=None,
        callback=lambda *_a: holder.append(None),
        user_data=holder,
    )
    return False


GLib.idle_add(_spawn_shell)

vte.connect("child-exited", lambda v, status: GLib.idle_add(_delayed_quit, win))

# ── CSS (estilo coherente con tu pywal + barra) ──────────────
# Tomamos color de fondo del CSS de pywal si existe, si no un fallback.
bg = "#1e1e1e"
fg = "#ffffff"
accent = "#80cbc4"
wal_css = os.path.expanduser("~/.cache/wal/colors-waybar.css")
if os.path.exists(wal_css):
    try:
        css_text = open(wal_css).read()
        import re
        m = re.search(r"@define-color\s+background\s+(#[0-9a-fA-F]{6,8})", css_text)
        if m:
            bg = m.group(1)
        m = re.search(r"@define-color\s+foreground\s+(#[0-9a-fA-F]{6,8})", css_text)
        if m:
            fg = m.group(1)
        m = re.search(r"@define-color\s+color9\s+(#[0-9a-fA-F]{6,8})", css_text)
        if m:
            accent = m.group(1)
    except Exception:
        pass

css = Gtk.CssProvider()
css.load_from_data(f"""
    window {{
        background-color: alpha({bg}, 0.96);
        border: 2px solid {accent};
        border-radius: 14px;
    }}
    terminal {{
        background-color: alpha({bg}, 0.96);
        color: {fg};
    }}
    terminal:focus {{
        background-color: alpha({bg}, 0.96);
    }}
""".encode())
Gtk.StyleContext.add_provider_for_screen(
    Gdk.Screen.get_default(),
    css,
    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 1,
)

# ── Layout ────────────────────────────────────────────────────
frame_w = Gtk.Frame()
frame_w.set_shadow_type(Gtk.ShadowType.NONE)
frame_w.add(vte)
win.add(frame_w)

# ── Layer shell: la magia ─────────────────────────────────────
GtkLayerShell.init_for_window(win)
GtkLayerShell.set_layer(win, GtkLayerShell.Layer.OVERLAY)
GtkLayerShell.set_anchor(win, GtkLayerShell.Edge.TOP, True)
GtkLayerShell.set_anchor(win, GtkLayerShell.Edge.LEFT, True)
GtkLayerShell.set_anchor(win, GtkLayerShell.Edge.RIGHT, True)
GtkLayerShell.set_anchor(win, GtkLayerShell.Edge.BOTTOM, False)

# Exclusivo en eje X (ancho pedido), no exclusivo en Y (alto variable)
GtkLayerShell.set_exclusive_zone(win, 0)
GtkLayerShell.set_margin(win, GtkLayerShell.Edge.TOP, args.margin_top)

# Tamaño solicitado (GtkLayerShell auto-calcula desde set_default_size cuando
# los anchors están fijados, pero pedimos el tamaño explícito para forzar).
display = Gdk.Display.get_default()
if display is not None:
    mon = display.get_monitor(0)
    if mon is not None:
        geom = mon.get_geometry()
        screen_w = geom.width
        screen_h = geom.height
        win_w = int(screen_w * args.width / 100)
        win_h = int(screen_h * args.height / 100)
        win.set_default_size(win_w, win_h)

# Foco de teclado: ON_DEMAND agarra teclado cuando el puntero está sobre
# la ventana y lo libera cuando sale. Así, un click FUERA hace que el
# compositor quite el foco → focus-out-event se dispara → cerramos.
# (EXCLUSIVE mantendría foco para siempre; NONE nunca lo agarra y deja
# a la VTE sin input inmediatamente. ON_DEMAND es el punto justo.)
GtkLayerShell.set_keyboard_mode(win, GtkLayerShell.KeyboardMode.ON_DEMAND)

# ── Eventos ─────────────────────────────────────────────────────
win.connect("focus-out-event", focus_out)

# Ctrl+Shift+Q también lo cierra (atajo de escape)
key_ctrl = Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.SHIFT_MASK
q_key = Gdk.keyval_from_name("q")
win.connect("key-press-event", lambda w, e: (
    w.destroy() is not None and Gtk.main_quit()
    if (e.state & key_ctrl) == key_ctrl and e.keyval == q_key
    else False
))

# ── Listener de Hyprland IPC ─────────────────────────────────────
# El layer-shell NO participa en el modelo normal de foco (no emite
# focus-out cuando clicas en otra ventana), así que observamos directamente
# los eventos del compositor. Cuando el foco cambia a una ventana distinta
# a la nuestra, o se mueve a un workspace que NO contiene nuestro "ddt",
# cerramos — igual que wlogout cuando clicas fuera.
def on_hypr_event(_src, _cond, sock):
    try:
        line = sock.readline(2048).decode("utf-8", errors="replace")
        if not line:
            return True
        # Formato: "EVENT>>payload"
        if ">>" not in line:
            return True
        event, payload = line.split(">>", 1)
        event = event.strip()
        # Cualquier cambio de foco, workspace o ventana nueva → cerrar
        if event in ("activewindow", "workspace", "focusedmon"):
            # pequeño margen para no cerrarnos con eventos transitorios
            GLib.timeout_add(60, _delayed_quit, win)
    except Exception as exc:
        sys.stderr.write(f"[ddt] hypr ipc err: {exc}\n")
    return True  # seguir escuchando


try:
    runtime = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    inst = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    sock_path = f"{runtime}/hypr/{inst}/.socket2.sock"
    address = Gio.UnixSocketAddress.new(sock_path)
    client = Gio.SocketClient.new()
    conn = client.connect(address, None)
    if conn is not None:
        fstream = Gio.DataInputStream.new(conn.get_input_stream())
        fd = conn.get_socket().get_fd()
        # Esta versión de PyGObject no expone unix_fd_add; creamos un
        # IOChannel desde el fd (vía la API UnixPipe) y usamos io_add_watch.
        channel = GLib.IOChannel.unix_new(fd)
        channel.set_encoding(None)
        channel.set_buffer_size(0)
        GLib.io_add_watch(
            channel,
            GLib.IO_IN | GLib.IO_HUP,
            lambda ch, cond, fs=fstream: on_hypr_event(ch, cond, fs),
        )
        sys.stderr.write(f"[ddt] hypr ipc ok (fd={fd})\n")
except Exception as exc:
    import traceback
    sys.stderr.write(f"[ddt] hypr ipc failed ({type(exc).__name__}): {exc}\n")
    traceback.print_exc()
    sys.stderr.flush()

# SIGTERM/SIGINT limpios
def shutdown(*_):
    HOLD_REF["keep"] = False
    win.destroy()
    Gtk.main_quit()
    return False


signal.signal(signal.SIGTERM, lambda *_: shutdown())
signal.signal(signal.SIGINT, lambda *_: shutdown())

# ── Mostrar y entrar al main loop ─────────────────────────────
win.show_all()
win.present_with_time(GLib.get_monotonic_time() // 1000)

# Pasamos a "ready" 200 ms después de mostrar: así ignoramos los focus-out
# que ocurren durante el spawn del shell (antes de que tenga PTY).
def mark_ready():
    HOLD_REF["ready"] = True
    return False


GLib.timeout_add(200, mark_ready)
Gtk.main()