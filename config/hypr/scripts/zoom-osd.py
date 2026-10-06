#!/usr/bin/env python3
# =============================================================
# OSD de la lupa que sigue al cursor
#
# El zoom de Hyprland amplia toda la salida, asi que un OSD en
# posicion fija (swayosd, hyprctl notify) se sale de la region
# visible en cuanto amplias. Como el zoom deja fijo el punto que
# hay bajo el cursor, este OSD se coloca junto al cursor.
#
# La transformacion mapea world -> screen ampliando alrededor del
# cursor: un offset d en world se ve como d*zoom en pantalla. Por
# eso posicion y tamano se dividen entre el zoom, y el cuadro sale
# siempre igual de grande sea cual sea la ampliacion.
#
# Daemon: lee factores de zoom (uno por linea) de un FIFO.
# =============================================================

import os
import gi

gi.require_version("Gtk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import Gtk, Gdk, GLib, GtkLayerShell  # noqa: E402

FIFO = "/tmp/zoom-osd.fifo"
OCULTAR_MS = 800

# Medidas en pixeles *visuales* (lo que se ve), no en world
ANCHO_BARRA = 170
ALTO_BARRA = 8
FUENTE = 15
ICONO = 16
PAD_V, PAD_H = 12, 16
SEP = 12
OFFSET = 28          # separacion respecto al cursor
MIN_ZOOM, MAX_ZOOM = 1.0, 5.0

# Todo se dibuja a escala 1/zoom para que el tamano aparente no cambie, pero
# por debajo de cierto punto el texto se renderiza a tan pocos pixeles que al
# ampliarlo sale ilegible. MIN_ESCALA frena esa reduccion: a partir de ahi el
# cuadro crece un poco en pantalla, pero se mantiene nitido Y proporcionado.
# Es un unico factor para TODO: aplicar suelos por elemento deformaba la caja.
# 0.7 => la fuente nunca baja de 11 px reales. Subelo si lo quieres mas grande.
MIN_ESCALA = 0.7

CSS = """
window {{ background: transparent; }}
#caja {{
    background-color: #1a1b26;
    border: 2px solid #7aa2f7;
    border-radius: {radio}px;
    padding: {pv}px {ph}px;
}}
#caja label, #caja image {{ color: #c0caf5; }}
#caja label {{ font-size: {fuente}px; font-weight: bold; }}
progressbar {{ min-height: {alto}px; }}
progressbar trough {{
    min-height: {alto}px;
    min-width: {ancho}px;
    border-radius: 999px;
    border: none;
    background-color: #414868;
}}
progressbar progress {{
    min-height: {alto}px;
    border-radius: 999px;
    border: none;
    background-color: #7aa2f7;
}}
"""


class ZoomOSD:
    def __init__(self):
        self.win = Gtk.Window(type=Gtk.WindowType.POPUP)
        GtkLayerShell.init_for_window(self.win)
        GtkLayerShell.set_layer(self.win, GtkLayerShell.Layer.OVERLAY)
        # NONE = no roba el foco, los binds del zoom siguen funcionando
        GtkLayerShell.set_keyboard_mode(self.win, GtkLayerShell.KeyboardMode.NONE)
        GtkLayerShell.set_anchor(self.win, GtkLayerShell.Edge.TOP, True)
        GtkLayerShell.set_anchor(self.win, GtkLayerShell.Edge.LEFT, True)
        # -1 = ignora las zonas exclusivas de otras capas. Sin esto el margen
        # superior se mide por debajo de waybar (48+6 px) y el OSD aparecia
        # 54 px mas abajo del cursor, desfase que el zoom multiplicaba.
        GtkLayerShell.set_exclusive_zone(self.win, -1)

        self.caja = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        self.caja.set_name("caja")
        self.icono = Gtk.Image.new_from_icon_name("edit-find", Gtk.IconSize.BUTTON)
        self.barra = Gtk.ProgressBar()
        self.barra.set_valign(Gtk.Align.CENTER)
        self.texto = Gtk.Label()
        for w in (self.icono, self.barra, self.texto):
            self.caja.pack_start(w, False, False, 0)
        self.win.add(self.caja)

        self.css = Gtk.CssProvider()
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(), self.css,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )
        self.timer = None
        self.escala_aplicada = None

    # --- posicion del cursor, en coordenadas world de Hyprland ---
    def cursor(self):
        try:
            with os.popen("hyprctl cursorpos") as p:
                x, y = p.read().strip().split(",")
            return int(x), int(y)
        except Exception:
            return 0, 0

    def escalar(self, zoom):
        """Divide cada medida entre el zoom: tamano aparente constante."""
        if self.escala_aplicada == zoom:
            return
        self.escala_aplicada = zoom
        s = max(MIN_ESCALA, 1.0 / zoom)
        f = lambda v: max(1, int(round(v * s)))  # noqa: E731
        self.css.load_from_data(CSS.format(
            radio=f(14), pv=f(PAD_V), ph=f(PAD_H),
            fuente=f(FUENTE), alto=f(ALTO_BARRA), ancho=f(ANCHO_BARRA),
        ).encode())
        self.caja.set_spacing(f(SEP))
        self.icono.set_pixel_size(f(ICONO))

    def mostrar(self, zoom):
        zoom = max(MIN_ZOOM, min(MAX_ZOOM, zoom))
        self.escalar(zoom)

        self.barra.set_fraction((zoom - MIN_ZOOM) / (MAX_ZOOM - MIN_ZOOM))
        self.texto.set_text(f"{round(zoom * 100)}%")

        # offset visual constante -> en world hay que dividirlo entre el zoom
        cx, cy = self.cursor()
        d = int(round(OFFSET / zoom))
        GtkLayerShell.set_margin(self.win, GtkLayerShell.Edge.LEFT, max(0, cx + d))
        GtkLayerShell.set_margin(self.win, GtkLayerShell.Edge.TOP, max(0, cy + d))

        self.win.show_all()
        if self.timer:
            GLib.source_remove(self.timer)
        self.timer = GLib.timeout_add(OCULTAR_MS, self.ocultar)

    def ocultar(self):
        self.win.hide()
        self.timer = None
        return False

    def on_fifo(self, fd, cond):
        try:
            datos = os.read(fd, 4096).decode()
        except BlockingIOError:
            return True
        # si llegan varios de golpe (scroll rapido) solo vale el ultimo
        lineas = [l for l in datos.strip().splitlines() if l.strip()]
        if lineas:
            try:
                self.mostrar(float(lineas[-1]))
            except ValueError:
                pass
        return True

    def run(self):
        if not os.path.exists(FIFO):
            os.mkfifo(FIFO, 0o600)
        # O_RDWR mantiene el FIFO abierto: sin esto daria EOF al cerrar
        # cada escritor y el watch se dispararia en bucle
        fd = os.open(FIFO, os.O_RDWR | os.O_NONBLOCK)
        GLib.io_add_watch(fd, GLib.IO_IN, self.on_fifo)
        Gtk.main()


if __name__ == "__main__":
    ZoomOSD().run()
