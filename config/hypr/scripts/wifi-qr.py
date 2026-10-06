#!/usr/bin/env python3
# =============================================================
#  wifi-qr — visor GTK del QR de la red WiFi.
#  Muestra la imagen del QR con el SSID arriba y una ✕ arriba a
#  la derecha para cerrar (también Esc). Colores de pywal.
#  app_id "qrwifi" → lo captura la windowrule de Hyprland (flotar).
#  Uso:  wifi-qr.py /ruta/al/qr.png "SSID"
# =============================================================
import os
import sys
import json
import gi
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, Gdk, GdkPixbuf, GLib

GLib.set_prgname("qrwifi")  # app_id para la regla de flotar/centrar

png = sys.argv[1] if len(sys.argv) > 1 else ""
ssid = sys.argv[2] if len(sys.argv) > 2 else "QR WiFi"


def load_palette():
    bg, fg, accent = "#181818", "#c5c5c5", "#437E81"
    try:
        with open(os.path.expanduser("~/.cache/wal/colors.json")) as f:
            d = json.load(f)
        bg = d["special"]["background"]
        fg = d["special"]["foreground"]
        accent = d["colors"]["color9"]
    except Exception:
        pass
    return bg, fg, accent


bg, fg, accent = load_palette()

CSS = f"""
window {{ background-color: {bg}; }}
.qr-title {{ color: {fg}; font-family: "JetBrainsMono Nerd Font", monospace;
             font-size: 15px; font-weight: bold; }}
.qr-close {{ background-color: transparent; color: {fg};
             border: 2px solid {accent}; border-radius: 50%;
             min-width: 38px; min-height: 38px; padding: 0px;
             font-size: 18px; box-shadow: none; }}
.qr-close:hover {{ background-color: {accent}; color: {bg};
                   border: 2px solid {accent}; }}
.qr-frame {{ background-color: #ffffff; border-radius: 10px; }}
"""


class QRWindow(Gtk.Window):
    def __init__(self):
        super().__init__()
        self.set_title("QR-WiFi")
        self.set_default_size(420, 470)
        self.set_resizable(False)
        self.set_position(Gtk.WindowPosition.CENTER)
        self.connect("destroy", Gtk.main_quit)
        self.connect("key-press-event", self.on_key)

        outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        outer.set_margin_top(10)
        outer.set_margin_bottom(16)
        outer.set_margin_start(16)
        outer.set_margin_end(16)
        self.add(outer)

        # Barra superior: SSID a la izquierda, ✕ arriba a la derecha
        top = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        title = Gtk.Label(label=f"📶  {ssid}")
        title.get_style_context().add_class("qr-title")
        title.set_halign(Gtk.Align.START)
        top.pack_start(title, True, True, 0)
        close = Gtk.Button(label="✕")
        close.get_style_context().add_class("qr-close")
        close.set_halign(Gtk.Align.END)
        close.connect("clicked", lambda *_: self.destroy())
        top.pack_end(close, False, False, 0)
        outer.pack_start(top, False, False, 0)

        # Imagen del QR sobre un marco blanco (para que se escanee bien)
        frame = Gtk.Box()
        frame.get_style_context().add_class("qr-frame")
        frame.set_margin_top(12)
        try:
            pix = GdkPixbuf.Pixbuf.new_from_file_at_scale(png, 360, 360, True)
            img = Gtk.Image.new_from_pixbuf(pix)
        except Exception:
            img = Gtk.Label(label="No se pudo cargar el QR")
        img.set_margin_top(16)
        img.set_margin_bottom(16)
        img.set_margin_start(16)
        img.set_margin_end(16)
        frame.set_center_widget(img)
        outer.pack_start(frame, True, True, 0)

    def on_key(self, _w, event):
        if event.keyval == Gdk.KEY_Escape:
            self.destroy()


prov = Gtk.CssProvider()
prov.load_from_data(CSS.encode())
Gtk.StyleContext.add_provider_for_screen(
    Gdk.Screen.get_default(), prov, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
)

win = QRWindow()
win.show_all()
Gtk.main()
