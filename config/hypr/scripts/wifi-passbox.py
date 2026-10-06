#!/usr/bin/env python3
# =============================================================
#  wifi-passbox — diálogo GTK para pedir la contraseña del WiFi.
#  Muestra a qué red te conectas, campo oculto y un icono de OJO
#  para mostrar/ocultar la clave. Colores tomados EN CALIENTE de
#  pywal (~/.cache/wal/colors.json), a juego con wofi/waybar.
#  Imprime la clave por stdout y sale 0 al aceptar; sale 1 (sin
#  imprimir) si cancelas.
#  Uso:  wifi-passbox.py "SSID"
# =============================================================
import os
import sys
import json
import gi
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, Gdk, GLib

ssid = sys.argv[1] if len(sys.argv) > 1 else "la red"


def load_palette():
    """(background, foreground, accent) desde pywal; con reserva si falta."""
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


def hex_to_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def apply_css(bg, fg, accent):
    r, g, b = hex_to_rgb(accent)
    tint = f"rgba({r},{g},{b},0.15)"       # relleno suave del campo
    tint_btn = f"rgba({r},{g},{b},0.12)"   # botón normal
    tint_hi = f"rgba({r},{g},{b},0.30)"    # hover
    border = f"rgba({r},{g},{b},0.45)"
    accent_hi = f"rgb({min(r+12,255)},{min(g+12,255)},{min(b+12,255)})"
    css = f"""
    window {{ background-color: {bg}; color: {fg};
              font-family: "JetBrainsMono Nerd Font", monospace; }}
    label {{ color: {fg}; }}
    entry {{ background-color: {tint}; color: {fg};
             border: 2px solid {accent}; border-radius: 12px;
             padding: 8px 12px; caret-color: {accent}; }}
    entry:focus {{ border: 2px solid {accent}; }}
    entry image {{ color: {accent}; }}
    button {{ border-radius: 12px; padding: 8px 14px;
              background-image: none; background-color: {tint_btn};
              color: {fg}; border: 1px solid {border}; }}
    button:hover {{ background-color: {tint_hi}; }}
    button.suggested-action {{ background-color: {accent}; color: {bg};
                               border: 1px solid {accent}; font-weight: bold; }}
    button.suggested-action:hover {{ background-color: {accent_hi};
                                     color: {bg}; }}
    """
    prov = Gtk.CssProvider()
    prov.load_from_data(css.encode())
    Gtk.StyleContext.add_provider_for_screen(
        Gdk.Screen.get_default(), prov,
        Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
    )


class PassBox(Gtk.Window):
    def __init__(self):
        super().__init__(title="Conectar a WiFi")
        self.password = None
        self.set_resizable(False)
        self.set_default_size(400, -1)
        self.set_position(Gtk.WindowPosition.CENTER)
        self.set_keep_above(True)
        self.set_border_width(20)
        self.connect("destroy", Gtk.main_quit)
        self.connect("key-press-event", self.on_key)

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)
        self.add(box)

        # Encabezado: a qué red te conectas
        head = Gtk.Label()
        head.set_markup(
            "<span size='large'>📶  Conectándote a</span>\n"
            f"<b><span size='x-large'>{GLib.markup_escape_text(ssid)}</span></b>"
        )
        head.set_justify(Gtk.Justification.CENTER)
        box.pack_start(head, False, False, 0)

        # Campo de contraseña con icono de ojo (mostrar/ocultar)
        self.entry = Gtk.Entry()
        self.entry.set_visibility(False)
        self.entry.set_placeholder_text("Contraseña")
        self.entry.set_activates_default(True)
        self.entry.connect("activate", self.on_ok)  # Enter en el campo = Conectar
        self.entry.set_icon_from_icon_name(
            Gtk.EntryIconPosition.SECONDARY, "view-reveal-symbolic"
        )
        self.entry.set_icon_tooltip_text(
            Gtk.EntryIconPosition.SECONDARY, "Mostrar/ocultar contraseña"
        )
        self.entry.connect("icon-press", self.on_eye)
        box.pack_start(self.entry, False, False, 0)

        # Botones
        btns = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        btns.set_homogeneous(True)
        cancel = Gtk.Button.new_with_label("Cancelar")
        cancel.connect("clicked", lambda *_: self.close())
        connect = Gtk.Button.new_with_label("Conectar")
        connect.get_style_context().add_class("suggested-action")
        connect.set_can_default(True)
        connect.connect("clicked", self.on_ok)
        btns.pack_start(cancel, True, True, 0)
        btns.pack_start(connect, True, True, 0)
        box.pack_start(btns, False, False, 0)

        self.set_default(connect)

    def on_eye(self, entry, pos, event):
        vis = not entry.get_visibility()
        entry.set_visibility(vis)
        entry.set_icon_from_icon_name(
            Gtk.EntryIconPosition.SECONDARY,
            "view-conceal-symbolic" if vis else "view-reveal-symbolic",
        )

    def on_ok(self, *_):
        self.password = self.entry.get_text()
        self.destroy()

    def on_key(self, _w, event):
        if event.keyval == Gdk.KEY_Escape:
            self.close()


apply_css(*load_palette())
win = PassBox()
win.show_all()
Gtk.main()

if win.password:
    print(win.password)
    sys.exit(0)
sys.exit(1)
