"""Tiny SVG kit for the Tmax workout player redesign views.

Everything is generated: text is outlined from the app's real font files (Inter Black / Inter Bold / TimeMaster ribbon)
through HarfBuzz, covers come from the app's own exercise art, so a view looks the same in Safari, Chrome and Quick Look.
"""
import base64
import io
import math
import os

import uharfbuzz as hb
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.ttLib import TTFont
from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
FONTS = os.path.join(ROOT, "TimeMaster", "Resources", "Fonts")
ART = os.path.join(ROOT, "TimeMaster", "Resources", "Assets.xcassets")

W, H = 402, 874
ORANGE = "#FF6A00"
UI_FONT = "Inter, -apple-system, 'SF Pro Text', 'Helvetica Neue', Helvetica, Arial, sans-serif"


def f(v):
    s = f"{v:.2f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace('"', "&quot;")


# --------------------------------------------------------------------------------------------------------------------
# Fonts
# --------------------------------------------------------------------------------------------------------------------
FACE_FILES = {
    "black": "Inter-Black.ttf",
    "bold": "Inter-Bold.ttf",
    "regular": "Inter-Regular.ttf",
    "ribbon": "TimeMaster-Regular.ttf",
}


class Face:
    def __init__(self, key):
        path = os.path.join(FONTS, FACE_FILES[key])
        self.key = key
        self.tt = TTFont(path)
        self.glyphs = self.tt.getGlyphSet()
        self.order = self.tt.getGlyphOrder()
        self.upm = self.tt["head"].unitsPerEm
        with open(path, "rb") as fh:
            data = fh.read()
        self.hb_font = hb.Font(hb.Face(data))
        self.paths = {}

    def shape(self, text, tnum):
        buf = hb.Buffer()
        buf.add_str(text)
        buf.guess_segment_properties()
        hb.shape(self.hb_font, buf, {"kern": True, "tnum": bool(tnum), "liga": False})
        return buf.glyph_infos, buf.glyph_positions

    def path(self, name):
        if name not in self.paths:
            pen = SVGPathPen(self.glyphs, ntos=lambda v: f"{v:.0f}")
            self.glyphs[name].draw(pen)
            self.paths[name] = pen.getCommands()
        return self.paths[name]


_FACES = {}


def face(key):
    if key not in _FACES:
        _FACES[key] = Face(key)
    return _FACES[key]


# --------------------------------------------------------------------------------------------------------------------
# Document: shared defs
# --------------------------------------------------------------------------------------------------------------------
class Doc:
    def __init__(self):
        self.defs = {}
        self.counter = 0
        self.images = {}

    def uid(self, prefix="u"):
        self.counter += 1
        return f"{prefix}{self.counter}"

    def define(self, key, xml):
        if key not in self.defs:
            self.defs[key] = xml
        return key

    def blur(self, std, region=60):
        key = f"blur{str(std).replace('.', '_')}"
        self.define(key, f'<filter id="{key}" x="-{region}%" y="-{region}%" width="{100 + 2 * region}%" '
                         f'height="{100 + 2 * region}%" color-interpolation-filters="sRGB"><feGaussianBlur stdDeviation="{std}"/></filter>')
        return key

    def linear(self, key, stops, x1=0, y1=0, x2=0, y2=1):
        body = "".join(f'<stop offset="{o}" stop-color="{c}" stop-opacity="{a}"/>' for o, c, a in stops)
        self.define(key, f'<linearGradient id="{key}" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">{body}</linearGradient>')
        return f"url(#{key})"

    def radial(self, key, stops, cx=0.5, cy=0.5, r=0.5):
        body = "".join(f'<stop offset="{o}" stop-color="{c}" stop-opacity="{a}"/>' for o, c, a in stops)
        self.define(key, f'<radialGradient id="{key}" cx="{cx}" cy="{cy}" r="{r}">{body}</radialGradient>')
        return f"url(#{key})"

    def clip_rr(self, x, y, w, h, r):
        key = self.uid("clip")
        self.define(key, f'<clipPath id="{key}"><rect x="{f(x)}" y="{f(y)}" width="{f(w)}" height="{f(h)}" rx="{f(r)}"/></clipPath>')
        return key

    def image(self, key, data_uri, w, h):
        self.define(f"img-{key}", f'<image id="img-{key}" href="{data_uri}" width="{w}" height="{h}"/>')
        self.images[key] = (w, h)
        return f"img-{key}"

    def glyph(self, face_key, name):
        gid = f"g-{face_key}-{name}".replace(".", "_")
        self.define(gid, f'<path id="{gid}" d="{face(face_key).path(name)}"/>')
        return gid

    def render(self, width, height, body, bg=None, title=None):
        defs = "".join(self.defs.values())
        bgrect = f'<rect width="{width}" height="{height}" fill="{bg}"/>' if bg else ""
        t = f"<title>{esc(title)}</title>" if title else ""
        return (f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
                f'viewBox="0 0 {f(width)} {f(height)}" width="{f(width)}" height="{f(height)}">{t}<defs>{defs}</defs>{bgrect}{body}</svg>')


# --------------------------------------------------------------------------------------------------------------------
# Text (outlined)
# --------------------------------------------------------------------------------------------------------------------
def measure(text, size, face_key="black", tracking=0.0, tnum=False):
    fc = face(face_key)
    _, pos = fc.shape(text, tnum)
    units = sum(p.x_advance for p in pos) + tracking * fc.upm / size * len(pos)
    return units * size / fc.upm - (tracking if pos else 0)


def text(d, s, x, y, size, face_key="black", fill="#fff", anchor="start", tracking=0.0, tnum=False, opacity=1.0, extra=""):
    """Outlined text on a baseline at (x, y)."""
    fc = face(face_key)
    infos, pos = fc.shape(s, tnum)
    k = size / fc.upm
    track_u = tracking / k
    cursor = 0.0
    uses = []
    for info, p in zip(infos, pos):
        name = fc.order[info.codepoint]
        if name != "space" and fc.path(name):
            gid = d.glyph(face_key, name)
            uses.append(f'<use href="#{gid}" x="{f(cursor + p.x_offset)}"' + (f' y="{f(p.y_offset)}"' if p.y_offset else "") + "/>")
        cursor += p.x_advance + track_u
    width = (cursor - (track_u if pos else 0)) * k
    ox = x if anchor == "start" else (x - width / 2 if anchor == "middle" else x - width)
    op = f' opacity="{f(opacity)}"' if opacity != 1 else ""
    return (f'<g fill="{fill}"{op} transform="translate({f(ox)} {f(y)}) scale({k:.6f} -{k:.6f})"{extra}>'
            + "".join(uses) + "</g>")


def text_c(d, s, cx, cy, size, **kw):
    """Text centred on its cap height around cy."""
    return text(d, s, cx, cy + size * 0.364, size, anchor="middle", **kw)


def note(s, x, y, size=13, fill="#c7c7cc", weight=500, anchor="start", opacity=1, family=UI_FONT, extra=""):
    op = f' opacity="{f(opacity)}"' if opacity != 1 else ""
    return (f'<text x="{f(x)}" y="{f(y)}" font-family="{family}" font-size="{f(size)}" font-weight="{weight}" '
            f'fill="{fill}" text-anchor="{anchor}"{op}{extra}>{esc(s)}</text>')


def wrap(s, width_px, size):
    per = max(8, int(width_px / (size * 0.53)))
    words, lines, cur = s.split(), [], ""
    for w in words:
        if len(cur) + len(w) + (1 if cur else 0) > per:
            lines.append(cur)
            cur = w
        else:
            cur = f"{cur} {w}".strip()
    if cur:
        lines.append(cur)
    return lines


# --------------------------------------------------------------------------------------------------------------------
# Covers from the app's own exercise art
# --------------------------------------------------------------------------------------------------------------------
COVER_ART = {
    "pushup": "Ranked_standardPushUp",
    "widepushup": "Ranked_widePushUp",
    "squat": "Ranked_standardSquat",
    "widesquat": "Ranked_wideSquat",
    "plank": "Ranked_highPlank",
    "sideplank": "Ranked_leftSidePlank",
    "forearm": "Ranked_forearmPlank",
    "knee": "Ranked_kneePushUp",
}
COVER_NAMES = {
    "pushup": "Push-Up", "widepushup": "Wide Push-Up", "squat": "Squat", "widesquat": "Wide Squat",
    "plank": "High Plank", "sideplank": "Side Plank", "forearm": "Forearm Plank", "knee": "Knee Push-Up",
}
COVER_PX = 560
_COVER_CACHE = {}


def _find_art(imageset):
    folder = os.path.join(ART, imageset + ".imageset")
    for name in sorted(os.listdir(folder)):
        if name.endswith(".png"):
            return os.path.join(folder, name)
    raise FileNotFoundError(imageset)


def cover_data(key):
    if key in _COVER_CACHE:
        return _COVER_CACHE[key]
    art = Image.open(_find_art(COVER_ART[key])).convert("RGBA")
    box = art.getbbox()
    art = art.crop(box)
    s = COVER_PX
    base = Image.new("RGB", (s, s), (14, 14, 15))
    px = base.load()
    for yy in range(s):
        t = yy / (s - 1)
        c = int(36 - 24 * t)
        for xx in range(s):
            px[xx, yy] = (c, c, c + 1)
    glow = Image.new("RGB", (s, s), (0, 0, 0))
    gd = ImageDraw.Draw(glow)
    fw = s * 0.9
    gd.ellipse([s * 0.5 - fw / 2, s * 0.70, s * 0.5 + fw / 2, s * 0.86], fill=(255, 98, 0))
    glow = glow.filter(ImageFilter.GaussianBlur(s * 0.06))
    glow = Image.eval(glow, lambda v: int(v * 0.52))
    base = ImageChops.add(base, glow)
    max_w, max_h = s * 0.90, s * 0.74
    scale = min(max_w / art.width, max_h / art.height)
    fig = art.resize((max(1, int(art.width * scale)), max(1, int(art.height * scale))), Image.LANCZOS)
    fx = (s - fig.width) // 2
    fy = int(s * 0.80) - fig.height
    base.paste(fig, (fx, fy), fig)
    buf = io.BytesIO()
    base.save(buf, "JPEG", quality=80, optimize=True)
    uri = "data:image/jpeg;base64," + base64.b64encode(buf.getvalue()).decode()
    _COVER_CACHE[key] = uri
    return uri


def use_cover(d, key, x, y, w, h, r=0, extra=""):
    """Cover filling the (x, y, w, h) box with rounded corners (fill mode, centred crop)."""
    d.image(key, cover_data(key), COVER_PX, COVER_PX)
    side = max(w, h)
    sc = side / COVER_PX
    ox = x + (w - COVER_PX * sc) / 2
    oy = y + (h - COVER_PX * sc) / 2
    clip = d.clip_rr(x, y, w, h, r)
    return (f'<g clip-path="url(#{clip})"{extra}><use href="#img-{key}" transform="translate({f(ox)} {f(oy)}) scale({sc:.5f})"/></g>')


# --------------------------------------------------------------------------------------------------------------------
# Shapes and glass
# --------------------------------------------------------------------------------------------------------------------
def rr(x, y, w, h, r, fill="none", stroke=None, sw=1, op=None, extra=""):
    s = f' stroke="{stroke}" stroke-width="{f(sw)}"' if stroke else ""
    o = f' opacity="{f(op)}"' if op is not None else ""
    return f'<rect x="{f(x)}" y="{f(y)}" width="{f(w)}" height="{f(h)}" rx="{f(r)}" fill="{fill}"{s}{o}{extra}/>'


def circ(cx, cy, r, fill="none", stroke=None, sw=1, op=None, extra=""):
    s = f' stroke="{stroke}" stroke-width="{f(sw)}"' if stroke else ""
    o = f' opacity="{f(op)}"' if op is not None else ""
    return f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(r)}" fill="{fill}"{s}{o}{extra}/>'


def glass(d, x, y, w, h, r=None, tone="regular", shadow=True, lift=0.0, op=1.0):
    """A Liquid Glass slab. Tones: regular, clear, white, orange, red, card."""
    r = h / 2 if r is None else r
    out = []
    k = tone
    sh = d.blur(7)
    if shadow:
        col = "#000" if k not in ("orange",) else ORANGE
        a = 0.40 if k not in ("orange",) else 0.34
        out.append(rr(x + 1, y + 6 - lift, w - 2, h, r, fill=col, op=a, extra=f' filter="url(#{sh})"'))
    if k == "regular":
        out.append(rr(x, y, w, h, r, fill="#0b0b0d", op=0.42))
        out.append(rr(x, y, w, h, r, fill=d.linear("gl-reg", [(0, "#fff", 0.20), (1, "#fff", 0.075)])))
    elif k == "clear":
        out.append(rr(x, y, w, h, r, fill="#0b0b0d", op=0.18))
        out.append(rr(x, y, w, h, r, fill=d.linear("gl-clr", [(0, "#fff", 0.12), (1, "#fff", 0.04)])))
    elif k == "white":
        out.append(rr(x, y, w, h, r, fill=d.linear("gl-wht", [(0, "#ffffff", 1), (0.55, "#f4f4f6", 1), (1, "#dcdce1", 1)])))
    elif k == "orange":
        out.append(rr(x, y, w, h, r, fill="#7a2a00", op=0.5))
        out.append(rr(x, y, w, h, r, fill=d.linear("gl-org", [(0, "#ff8a2a", 0.96), (1, "#ff5a00", 0.96)])))
    elif k == "red":
        out.append(rr(x, y, w, h, r, fill="#400d0a", op=0.5))
        out.append(rr(x, y, w, h, r, fill=d.linear("gl-red", [(0, "#ff5a4d", 0.85), (1, "#e8352b", 0.85)])))
    elif k == "card":
        out.append(rr(x, y, w, h, r, fill=d.linear("gl-card", [(0, "#fff", 0.115), (1, "#fff", 0.06)])))
    if k != "card":
        spec = d.radial("gl-spec", [(0, "#fff", 0.55 if k in ("white", "orange") else 0.34), (1, "#fff", 0)], cx=0.5, cy=0.5, r=0.5)
        clip = d.clip_rr(x, y, w, h, r)
        out.append(f'<g clip-path="url(#{clip})"><ellipse cx="{f(x + w / 2)}" cy="{f(y + h * 0.12)}" rx="{f(w * 0.46)}" ry="{f(h * 0.34)}" fill="{spec}"/></g>')
        rim_top = 0.85 if k in ("white", "orange") else 0.62
        rim = d.linear(f"gl-rim-{k}", [(0, "#fff", rim_top), (0.32, "#fff", 0.16), (0.62, "#fff", 0.07), (1, "#fff", 0.42)], x1=0, y1=0, x2=0.7, y2=1)
        out.append(rr(x + 0.6, y + 0.6, w - 1.2, h - 1.2, max(0, r - 0.6), stroke=rim, sw=1.2))
    else:
        out.append(rr(x + 0.5, y + 0.5, w - 1, h - 1, max(0, r - 0.5), stroke="#fff", sw=1, op=0.13))
    if op != 1.0:
        return f'<g opacity="{f(op)}">' + "".join(out) + "</g>"
    return "".join(out)


def glass_circle(d, cx, cy, r, **kw):
    return glass(d, cx - r, cy - r, 2 * r, 2 * r, r, **kw)


# --------------------------------------------------------------------------------------------------------------------
# Icons (24-unit grid, stroke style close to SF Symbols)
# --------------------------------------------------------------------------------------------------------------------
def _st(c, sw=2.0, extra=""):
    return f'fill="none" stroke="{c}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round"{extra}'
_FAINT = ' opacity="0.55"'


ICONS = {
    "xmark": lambda c, i: f'<path d="M6.8 6.8L17.2 17.2M17.2 6.8L6.8 17.2" {_st(c, 2.6)}/>',
    "pause": lambda c, i: f'<rect x="6.2" y="4.6" width="4.2" height="14.8" rx="1.5" fill="{c}"/><rect x="13.6" y="4.6" width="4.2" height="14.8" rx="1.5" fill="{c}"/>',
    "play": lambda c, i: f'<path d="M8.4 5.6L19 12L8.4 18.4Z" fill="{c}" stroke="{c}" stroke-width="2.4" stroke-linejoin="round"/>',
    "back": lambda c, i: f'<path d="M5.6 5.8V18.2" {_st(c, 2.6)}/><path d="M19.2 6L9.4 12L19.2 18Z" fill="{c}" stroke="{c}" stroke-width="2.2" stroke-linejoin="round"/>',
    "next": lambda c, i: f'<path d="M18.4 5.8V18.2" {_st(c, 2.6)}/><path d="M4.8 6L14.6 12L4.8 18Z" fill="{c}" stroke="{c}" stroke-width="2.2" stroke-linejoin="round"/>',
    "forward": lambda c, i: f'<path d="M3.2 6.2L11.4 12L3.2 17.8Z" fill="{c}" stroke="{c}" stroke-width="1.8" stroke-linejoin="round"/><path d="M12.6 6.2L20.8 12L12.6 17.8Z" fill="{c}" stroke="{c}" stroke-width="1.8" stroke-linejoin="round"/>',
    "clipboard": lambda c, i: (f'<rect x="5" y="4.6" width="14" height="16.6" rx="3" {_st(c, 1.9)}/><rect x="8.6" y="2.6" width="6.8" height="3.8" rx="1.6" fill="{c}"/>'
                               f'<circle cx="8.8" cy="10.8" r="1" fill="{c}"/><circle cx="8.8" cy="14" r="1" fill="{c}"/><circle cx="8.8" cy="17.2" r="1" fill="{c}"/>'
                               f'<path d="M11.8 10.8H16M11.8 14H16M11.8 17.2H14.4" {_st(c, 1.6)}/>'),
    "music": lambda c, i: (f'<path d="M3.4 7.2H14.4M3.4 11.8H14.4M3.4 16.4H9.4" {_st(c, 2)}/><circle cx="17" cy="16.6" r="2.3" fill="{c}"/>'
                           f'<path d="M19.3 16.4V5.6L22.6 6.8" {_st(c, 1.9)}/>'),
    "slider": lambda c, i: (f'<path d="M4 6.6H20M4 12H20M4 17.4H20" {_st(c, 1.8)}/><circle cx="8.2" cy="6.6" r="2.5" fill="{c}"/>'
                            f'<circle cx="15.8" cy="12" r="2.5" fill="{c}"/><circle cx="10.4" cy="17.4" r="2.5" fill="{c}"/>'),
    "book": lambda c, i: (f'<path d="M5.2 4.6H15a3 3 0 0 1 3 3v12.6H8.2a3 3 0 0 1-3-3z" {_st(c, 1.8)}/><path d="M8.8 9.2h6M8.8 12.8h6" {_st(c, 1.6)}/>'),
    "flag": lambda c, i: ('<path d="M6 3.6V21" ' + _st(c, 2) + '/>' + "".join(
        f'<rect x="{7.4 + col * 3.15:.2f}" y="{4.4 + row * 3.1:.2f}" width="3.15" height="3.1" fill="{c}"/>'
        for row in range(3) for col in range(4) if (row + col) % 2 == 0)
        + f'<rect x="7.4" y="4.4" width="12.6" height="9.3" {_st(c, 1.3)}/>'),
    "shuffle": lambda c, i: (f'<path d="M3 7.2h3.4c2.4 0 3.8 1.3 5 3.4l1.5 2.9c1.2 2.1 2.6 3.4 5 3.4H21M3 16.8h3.4c1.8 0 3-.7 4-2M13 8.4c1-1.2 2.2-1.6 4-1.6H21" {_st(c, 1.9)}/>'
                             f'<path d="M18.4 4.4L21 6.8l-2.6 2.4M18.4 14.6L21 17l-2.6 2.4" {_st(c, 1.9)}/>'),
    "repeat": lambda c, i: (f'<path d="M4 11.2V9.6a3.1 3.1 0 0 1 3.1-3.1H19.4M16.8 3.6L19.8 6.5L16.8 9.4M20 12.8v1.6a3.1 3.1 0 0 1-3.1 3.1H4.6M7.2 14.6L4.2 17.5L7.2 20.4" {_st(c, 1.9)}/>'),
    "check": lambda c, i: f'<path d="M5.2 12.8L10 17.4L19 7" {_st(c, 2.8)}/>',
    "checkcircle": lambda c, i: f'<circle cx="12" cy="12" r="10" fill="{c}"/><path d="M7.2 12.4L10.6 15.8L16.8 8.8" fill="none" stroke="{i}" stroke-width="2.3" stroke-linecap="round" stroke-linejoin="round"/>',
    "stopwatch": lambda c, i: f'<circle cx="12" cy="13.6" r="7.4" {_st(c, 1.9)}/><path d="M9.8 3.2h4.4M12 3.2v3M12 13.6V9.8M12 13.6l2.6 1.7" {_st(c, 1.9)}/>',
    "timer": lambda c, i: f'<circle cx="12" cy="12" r="8.4" {_st(c, 1.9)}/><path d="M12 7.2V12l3.2 2" {_st(c, 1.9)}/>',
    "plus": lambda c, i: f'<path d="M12 5.4v13.2M5.4 12h13.2" {_st(c, 2.4)}/>',
    "chev_up": lambda c, i: f'<path d="M4.4 14.2L12 10l7.6 4.2" {_st(c, 2.2)}/>',
    "chev_right": lambda c, i: f'<path d="M9 5.4L15.6 12L9 18.6" {_st(c, 2.4)}/>',
    "chev_down": lambda c, i: f'<path d="M5.4 9L12 15.6L18.6 9" {_st(c, 2.4)}/>',
    "drop": lambda c, i: f'<path d="M7 7L17 17M17.4 9.4V17.4H9.4" {_st(c, 2.2)}/>',
    "trash": lambda c, i: f'<path d="M4.8 7h14.4M9.4 7V4.6h5.2V7M6.8 7l.8 12.6h8.8L17.2 7M10.2 10.6v6M13.8 10.6v6" {_st(c, 1.8)}/>',
    "clock": lambda c, i: f'<circle cx="12" cy="12" r="8.4" {_st(c, 1.9)}/><path d="M12 7v5.2l-3 1.8" {_st(c, 1.9)}/>',
    "warn": lambda c, i: f'<path d="M12 4.2L21 19.4H3Z" {_st(c, 1.9)}/><path d="M12 10v4.4" {_st(c, 2)}/><circle cx="12" cy="17" r="1.1" fill="{c}"/>',
    "bolt": lambda c, i: f'<path d="M13.6 2.6L5.2 13.4H11l-1 8L18.8 10.4H12.8z" fill="{c}" stroke="{c}" stroke-width="1" stroke-linejoin="round"/>',
    "hourglass": lambda c, i: f'<path d="M7.4 3.6h9.2v3.6L12 12l4.6 4.8v3.6H7.4v-3.6L12 12 7.4 7.2z" {_st(c, 1.9)}/>',
    "flame": lambda c, i: f'<path d="M12.4 2.6c.6 3.2-1.6 4.4-3 6.2-1.200 1.600-2.200 3.200-2.200 5.400A5.200 5.200 0 0 0 12.200 19.400a5.200 5.200 0 0 0 5-5.400c0-2-.9-3.300-2-4.500-.2 1.200-.8 2-1.600 2.400.5-3-.2-6-1.200-9.300z" fill="{c}"/>',
    "hand": lambda c, i: f'<circle cx="12" cy="9" r="3.4" {_st(c, 1.8)}/><circle cx="12" cy="9" r="7.4" {_st(c, 1.4, _FAINT)}/><path d="M12 12.6V21" {_st(c, 1.9)}/>',
    "note": lambda c, i: f'<path d="M9 18.2V6.4l9-2v11.6" {_st(c, 1.9)}/><circle cx="6.8" cy="18.2" r="2.4" fill="{c}"/><circle cx="15.8" cy="16" r="2.4" fill="{c}"/>',
    "sidebar": lambda c, i: f'<rect x="3.6" y="5" width="16.8" height="14" rx="3.2" {_st(c, 1.8)}/><path d="M14.4 5v14" {_st(c, 1.8)}/>',
    "volume": lambda c, i: f'<path d="M4 9.6h3.4L12 5.8v12.4l-4.6-3.8H4z" fill="{c}"/><path d="M15.4 8.8a4.6 4.6 0 0 1 0 6.4M18 6.4a8 8 0 0 1 0 11.2" {_st(c, 1.8)}/>',
    "doc": lambda c, i: f'<path d="M6.4 3.6h7.6L18.6 8.2v12.2H6.4z" {_st(c, 1.8)}/><path d="M14 3.8v4.6h4.4M9.2 12.4h6M9.2 15.6h6" {_st(c, 1.6)}/>',
}


def icon(name, cx, cy, size=22, color="#fff", op=1.0, inner="#000", extra=""):
    k = size / 24.0
    o = f' opacity="{f(op)}"' if op != 1 else ""
    return (f'<g transform="translate({f(cx - 12 * k)} {f(cy - 12 * k)}) scale({k:.4f})"{o}{extra}>'
            + ICONS[name](color, inner) + "</g>")


# --------------------------------------------------------------------------------------------------------------------
# Device chrome
# --------------------------------------------------------------------------------------------------------------------
def status_bar(d):
    out = [text(d, "9:41", 54, 38, 17, "bold", "#fff", anchor="middle", tnum=True)]
    bars = "".join(rr(318 + i * 5.2, 33 - (i + 1) * 2.7 + 2.7, 3.4, 2.7 * (i + 1), 1, fill="#fff") for i in range(4))
    wifi = ('<g fill="none" stroke="#fff" stroke-width="2.1" stroke-linecap="round">'
            '<path d="M342.200 28.900a8 8 0 0 1 11.600 0"/><path d="M344.700 32.500a4.600 4.600 0 0 1 6.600 0"/></g>'
            f'<circle cx="348" cy="36" r="1.5" fill="#fff"/>')
    batt = (rr(362.5, 25.5, 25, 12.5, 3.8, stroke="#fff", sw=1, op=0.45) + rr(364.5, 27.5, 21, 8.5, 2.3, fill="#fff")
            + rr(389, 29.5, 1.6, 4.5, 0.8, fill="#fff", op=0.5))
    return "".join(out) + bars + wifi + batt


def home_indicator():
    return rr(W / 2 - 67, H - 21, 134, 5, 2.5, fill="#fff", op=0.9)


def island():
    return rr(W / 2 - 63, 11, 126, 37, 18.5, fill="#000")


def device(d, inner, x=0, y=0, scale=1.0, chrome=True, outline="#2b2b2f", corner=56):
    clip = d.clip_rr(0, 0, W, H, corner)
    body = [f'<g transform="translate({f(x)} {f(y)}) scale({f(scale)})">',
            rr(0, 0, W, H, corner, fill="#000"),
            f'<g clip-path="url(#{clip})">', inner]
    if chrome:
        body += [status_bar(d), island(), home_indicator()]
    body += ["</g>", rr(0.5, 0.5, W - 1, H - 1, corner - 0.5, stroke=outline, sw=1.4 / scale if scale < 0.6 else 1.4), "</g>"]
    return "".join(body)


def backdrop(d, key="pushup", strength=0.42, y_shift=0):
    d.image(key, cover_data(key), COVER_PX, COVER_PX)
    blur = d.blur(34, region=40)
    scale = 2.3
    side = COVER_PX * scale * (402 / COVER_PX) * 1.0
    ox = (W - side) / 2
    oy = (H - side) / 2 + 20 + y_shift
    return (rr(0, 0, W, H, 0, fill="#000")
            + f'<g opacity="{f(strength)}" filter="url(#{blur})"><use href="#img-{key}" transform="translate({f(ox)} {f(oy)}) scale({f(side / COVER_PX)})"/></g>'
            + rr(0, 0, W, H, 0, fill=d.linear("bd-fade", [(0, "#000", 0.55), (0.35, "#000", 0.30), (1, "#000", 0.78)])))
