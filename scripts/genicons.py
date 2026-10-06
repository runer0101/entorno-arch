import gi, math
gi.require_version('PangoCairo','1.0')
gi.require_version('Pango','1.0')
from gi.repository import Pango, PangoCairo
import cairo, os

OUT = os.path.expanduser("~/.config/swaync/icons")
SIZE = 64          # lienzo generoso; el CSS lo escala a 20px
FONT = "JetBrainsMono Nerd Font 34"

ICONS = {
    "bt-on":    "\U000f00af",  # 󰂯
    "bt-off":   "\U000f00b2",  # 󰂲
    "wifi-on":  "\U000f05a9",  # 󰖩
    "wifi-off": "\U000f05aa",  # 󰖪
    "vol-on":   "\U000f057e",  # 󰕾
    "vol-off":  "\U000f075f",  # 󰝟
}

def render(glyph, path, rgba):
    surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, SIZE, SIZE)
    ctx = cairo.Context(surf)
    layout = PangoCairo.create_layout(ctx)
    layout.set_font_description(Pango.FontDescription(FONT))
    layout.set_text(glyph, -1)
    w, h = layout.get_pixel_size()
    ctx.set_source_rgba(*rgba)
    ctx.move_to((SIZE - w) / 2, (SIZE - h) / 2)
    PangoCairo.show_layout(ctx, layout)
    surf.write_to_png(path)
    return w, h

os.makedirs(OUT, exist_ok=True)
for name, glyph in ICONS.items():
    # ENCENDIDO: blanco pleno. APAGADO: blanco al 35%, el mismo valor que ya
    # usaba el CSS para el estado apagado.
    rgba = (1, 1, 1, 1) if name.endswith("-on") else (1, 1, 1, 0.35)
    p = os.path.join(OUT, "toggle-%s.png" % name)
    w, h = render(glyph, p, rgba)
    print("%-22s glifo %dx%d px -> %s" % (name, w, h, os.path.basename(p)))
