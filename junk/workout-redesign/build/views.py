"""Every player view, drawn with the user's real attachment clips looping inside the cards."""
import json
import math
import os

from svgkit import *

HERE = os.path.dirname(os.path.abspath(__file__))
CL = json.load(open(os.path.join(HERE, "clips.json")))
CX = W / 2
ANIM = True
SIZES = {"hero": (360, 360), "now": (300, 352), "next": (140, 370), "sheet": (360, 214)}

ICONS["wave"] = lambda c, i: "".join(f'<rect x="{x}" y="{12 - h / 2}" width="2.6" height="{h}" rx="1.3" fill="{c}"/>' for x, h in ((4, 6), (8.4, 12), (12.8, 17), (17.2, 10), (21.4 - 0.4, 5)))
ICONS["mute"] = lambda c, i: (f'<path d="M3.6 9.6h3.6L12 5.6v12.8l-4.8-4H3.6z" fill="{c}"/><path d="M15.4 9.4l5 5.2M20.4 9.4l-5 5.2" fill="none" stroke="{c}" stroke-width="1.9" stroke-linecap="round"/>')
ICONS["cooldown"] = lambda c, i: (f'<circle cx="12" cy="5" r="2.3" fill="{c}"/><path d="M12 8.2v5.2M12 13.4l-3.6 6.2M12 13.4l3.6 6.2M5.6 11.6l6.4-1.4 6.4 1.4" fill="none" stroke="{c}" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/>')

# real data -------------------------------------------------------------------------------------------------------
S0 = [("dive", "Dive bomber push-ups x10", "0:40", 10), ("walkout", "Hand walkouts x10", "1:15", 10), ("kick", "Kick-throughs 30 s", "0:30", None)]
S6 = [("bridge", "Wrestler's bridge with hands 25 s", "0:25", None), ("neckrock", "Neck rocks on hands and knees 40 s", "0:40", None),
      ("neckext", "Lying neck extensions 40 s", "0:40", None)]
SPRAWL = ("sprawl", "Sprawls 4x7, hips straight down, pop up", "0:33", 7)
REST_EX = {"couch": ("Couch Stretch", 30), "cobra": ("Cobra Side-to-Side Shift", 30), "straddle": ("Seated Straddle Reach to Toes", 30)}
WORKOUT = "W2 Tue PM · Wrestling 1 (solo technique)"


# primitives ------------------------------------------------------------------------------------------------------
def liquid_filter(d, tone):
    key = f"liq-{tone}"
    p = {"dark": ("#08080a", 0.34, "#ffffff", 0.10, 0.62, 0.8), "orange": ("#3a1400", 0.30, "#FF6A00", 0.92, 0.55, 0.55),
         "white": ("#ffffff", 0.0, "#ffffff", 0.97, 0.0, 0.45), "clear": ("#08080a", 0.10, "#ffffff", 0.07, 0.55, 0.7),
         "red": ("#2a0806", 0.30, "#FF453A", 0.88, 0.5, 0.5)}[tone]
    under, ua, fill, fa, rim, spec = p
    d.define(key, f'''<filter id="{key}" x="-30%" y="-70%" width="160%" height="240%" color-interpolation-filters="sRGB">
<feGaussianBlur in="SourceAlpha" stdDeviation="5" result="b"/>
<feColorMatrix in="b" type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 20 -8.5" result="goo"/>
<feFlood flood-color="{under}" flood-opacity="{ua}" result="dk"/><feComposite in="dk" in2="goo" operator="in" result="under"/>
<feFlood flood-color="{fill}" flood-opacity="{fa}" result="wf"/><feComposite in="wf" in2="goo" operator="in" result="fill"/>
<feMorphology in="goo" operator="erode" radius="1.2" result="er"/><feComposite in="goo" in2="er" operator="out" result="edge"/>
<feFlood flood-color="#fff" flood-opacity="{rim}" result="rf"/><feComposite in="rf" in2="edge" operator="in" result="rim"/>
<feGaussianBlur in="goo" stdDeviation="2.6" result="h"/>
<feSpecularLighting in="h" surfaceScale="4.5" specularConstant="1" specularExponent="24" lighting-color="#fff" result="spec"><feDistantLight azimuth="228" elevation="46"/></feSpecularLighting>
<feComposite in="spec" in2="goo" operator="in" result="specIn"/>
<feColorMatrix in="specIn" type="matrix" values="1 0 0 0 0  0 1 0 0 0  0 0 1 0 0  0 0 0 {spec} 0" result="spec2"/>
<feMerge><feMergeNode in="under"/><feMergeNode in="fill"/><feMergeNode in="spec2"/><feMergeNode in="rim"/></feMerge></filter>''')
    return key


def liquid(d, shapes, tone="dark", shadow=True):
    """Gooey glass: shapes close together merge with liquid necks. shapes: ('c', cx, cy, r) | ('p', x, y, w, h, r)."""
    key = liquid_filter(d, tone)
    body = []
    for s in shapes:
        if s[0] == "c":
            body.append(f'<circle cx="{f(s[1])}" cy="{f(s[2])}" r="{f(s[3])}" fill="#000"/>')
        else:
            body.append(f'<rect x="{f(s[1])}" y="{f(s[2])}" width="{f(s[3])}" height="{f(s[4])}" rx="{f(s[5])}" fill="#000"/>')
    sh = ""
    if shadow:
        blur = d.blur(7)
        sh = f'<g opacity="{0.42 if tone != "orange" else 0.4}" transform="translate(0 6)" filter="url(#{blur})" fill="{"#000" if tone != "orange" else ORANGE}">{"".join(b.replace("#000", "currentColor") for b in body)}</g>'
        sh = sh.replace("currentColor", "#000" if tone != "orange" else ORANGE)
    return sh + f'<g filter="url(#{key})">{"".join(body)}</g>'


def thumb(d, key, x, y, w, h, r, big=False, op=1.0):
    field = "thumb_big" if big else "thumb"
    side = 220 if big else 128
    d.image(f"{key}-{field}", CL[key][field], side, side)
    sc = max(w, h) / side
    clip = d.clip_rr(x, y, w, h, r)
    o = f' opacity="{f(op)}"' if op != 1 else ""
    return f'<g clip-path="url(#{clip})"{o}><use href="#img-{key}-{field}" transform="translate({f(x + (w - side * sc) / 2)} {f(y + (h - side * sc) / 2)}) scale({sc:.4f})"/></g>'


def clip_loop(d, key, role, x, y, w, h, r=0):
    """The real clip as a looping flipbook (SMIL), pre-cropped to the card's shape."""
    frames = CL[key][role]
    fw, fh = SIZES[role]
    n = len(frames) if ANIM else 1
    dur = len(frames) / CL[key][role + "_fps"]
    sc = max(w / fw, h / fh)
    ox, oy = x + (w - fw * sc) / 2, y + (h - fh * sc) / 2
    clip = d.clip_rr(x, y, w, h, r)
    out = []
    for i in range(n):
        d.define(f"cf-{key}-{role}-{i}", f'<image id="cf-{key}-{role}-{i}" href="{frames[i]}" width="{fw}" height="{fh}"/>')
        anim = ""
        if ANIM and n > 1:
            if i == 0:
                vals, kts = "visible;hidden", f"0;{1 / n:.4f}"
            elif i == n - 1:
                vals, kts = "hidden;visible", f"0;{i / n:.4f}"
            else:
                vals, kts = "hidden;visible;hidden", f"0;{i / n:.4f};{(i + 1) / n:.4f}"
            anim = f'<animate attributeName="visibility" calcMode="discrete" values="{vals}" keyTimes="{kts}" dur="{dur:.3f}s" repeatCount="indefinite"/>'
        out.append(f'<g visibility="{"visible" if i == 0 else "hidden"}"><use href="#cf-{key}-{role}-{i}" transform="translate({f(ox)} {f(oy)}) scale({sc:.4f})"/>{anim}</g>')
    return f'<g clip-path="url(#{clip})">{"".join(out)}</g>'


def backdrop_clip(d, key, strength=0.5):
    d.image(f"{key}-thumb_big", CL[key]["thumb_big"], 220, 220)
    blur = d.blur(34, region=40)
    side = 900
    return (rr(0, 0, W, H, 0, fill="#000")
            + f'<g opacity="{f(strength)}" filter="url(#{blur})"><use href="#img-{key}-thumb_big" transform="translate({f(CX - side / 2)} {f(H / 2 - side / 2 + 30)}) scale({side / 220:.3f})"/></g>'
            + rr(0, 0, W, H, 0, fill=d.linear("bd-fade", [(0, "#000", 0.50), (0.4, "#000", 0.28), (1, "#000", 0.80)])))


def lines(s, size, maxw, face_key="black", maxlines=2):
    words, out, cur = s.split(), [], ""
    for wd in words:
        t = f"{cur} {wd}".strip()
        if measure(t, size, face_key) > maxw and cur:
            out.append(cur)
            cur = wd
        else:
            cur = t
    out.append(cur)
    if len(out) > maxlines:
        out = out[:maxlines]
        while measure(out[-1] + "…", size, face_key) > maxw:
            out[-1] = out[-1][:-1]
        out[-1] += "…"
    return out


def facts(d, x, y, dur=None, reps=None, untimed=False, size=12, op=0.85, anchor="start"):
    items = []
    if untimed:
        items.append(("hand", "Until Done"))
    elif dur:
        items.append(("stopwatch", dur))
    if reps:
        items.append(("repeat", str(reps)))
    widths = [size + 4 + measure(t, size, "black", tnum=True) for _, t in items]
    total = sum(widths) + 10 * max(0, len(items) - 1)
    cur = x - total / 2 if anchor == "middle" else x
    out = []
    for (name, t), wd in zip(items, widths):
        out.append(icon(name, cur + size / 2, y - size * 0.36, size + 1, "#fff", op=op))
        out.append(text(d, t, cur + size + 4, y, size, "black", "#fff", tnum=True, opacity=op))
        cur += wd + 10
    return "".join(out)


def callout(n, x, y, r=11):
    return (circ(x, y, r, fill="#0b0b0d", stroke=ORANGE, sw=2)
            + f'<text x="{f(x)}" y="{f(y + 4.2)}" font-family="{UI_FONT}" font-size="12" font-weight="800" fill="#fff" text-anchor="middle">{n}</text>')


# controls --------------------------------------------------------------------------------------------------------
def lobe_button(d, cx, cy, r, ic, size=20, color="#fff", tone="dark"):
    return liquid(d, [("c", cx, cy, r)], tone) + icon(ic, cx, cy, size, color, op=0.97)


def top_bar(d, items=("clipboard", "music"), badge="1 / 3", voice="on", close=True, cy=92):
    out = []
    if close:
        out.append(lobe_button(d, 42, cy, 22, "xmark", 17))
    right_edge = 382
    if badge:
        bw = 62
        out.append(liquid(d, [("p", right_edge - bw, cy - 22, bw, 44, 22)]))
        out.append(text_c(d, badge, right_edge - bw / 2, cy, 15, face_key="black", fill="#fff", tnum=True))
        right_edge -= bw + 14
    names = list(items) + (["wave" if voice == "on" else "mute"] if voice else [])
    shapes, icons = [], []
    for i, nm in enumerate(reversed(names)):
        x = right_edge - 22 - 46 * i
        shapes.append(("c", x, cy, 22))
        icons.append(icon(nm, x, cy, 20, ORANGE if nm == "wave" and voice == "on" else "#fff", op=0.97))
    out.append(liquid(d, shapes))
    out.extend(icons)
    return "".join(out)


def voice_toast(d, cy, label, speaking=True):
    tw = measure(label, 14, "black")
    w = min(342, tw + 62)
    x = CX - w / 2
    shown = label if tw + 62 <= 342 else lines(label, 14, 280, maxlines=1)[0]
    return (liquid(d, [("p", x, cy - 17, w, 34, 17)], "clear") + icon("wave", x + 22, cy, 17, ORANGE)
            + text(d, shown, x + 40, cy + 5.2, 14, "black", "#fff"))


def caption(d, s, y, cx=CX, op=0.5):
    return text(d, s, cx, y, 12, "black", "#fff", anchor="middle", tracking=5, opacity=op)


def clock(d, s, base, size=112, op=1.0):
    return text(d, s, CX, base, size, "black", "#fff", anchor="middle", tnum=True, opacity=op)


def dots(d, cx, cy, n, cur, wcur=26, h=8, gap=7):
    wid = [wcur if i == cur else h for i in range(n)]
    x = cx - (sum(wid) + gap * (n - 1)) / 2
    out = []
    for i in range(n):
        col, a = ("#fff", 1) if i == cur else (("#fff", 0.55) if i < cur else ("#fff", 0.22))
        out.append(rr(x, cy - h / 2, wid[i], h, h / 2, fill=col, op=a))
        x += wid[i] + gap
    return "".join(out)


def pill(d, cx, cy, w, h, label, tone="white", size=17, ic=None, color=None):
    color = color or ("#0a0a0a" if tone == "white" else "#fff")
    out = [liquid(d, [("p", cx - w / 2, cy - h / 2, w, h, h / 2)], tone)]
    if ic:
        tw = measure(label, size, "black")
        x0 = cx - (size + 8 + tw) / 2
        out.append(icon(ic, x0 + size / 2, cy, size + 2, color))
        out.append(text(d, label, x0 + size + 8, cy + size * 0.364, size, "black", color))
    else:
        out.append(text_c(d, label, cx, cy, size, face_key="black", fill=color))
    return "".join(out)


def pause_disc(d, cx, cy, paused=False, progress=0.4):
    """White disc inside its glass lobe, the phase progress as a ring between disc and rim."""
    R = 38.6
    c = 2 * math.pi * R
    out = [circ(cx, cy, R, stroke="#fff", sw=2.6, op=0.2)]
    if progress > 0:
        out.append(f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(R)}" fill="none" stroke="#fff" stroke-width="2.6" stroke-linecap="round" '
                   f'stroke-dasharray="{f(c * progress)} {f(c)}" transform="rotate(-90 {f(cx)} {f(cy)})"/>')
    out.append(circ(cx, cy, 33, fill=d.linear("disc", [(0, "#ffffff", 1), (1, "#e2e2e6", 1)])))
    out.append(icon("play" if paused else "pause", cx + (2 if paused else 0), cy, 27, "#0a0a0a"))
    return "".join(out)


def transport(d, cy, paused=False, progress=0.4, back_ok=True):
    shapes = [("c", 125, cy, 28), ("c", CX, cy, 42), ("c", 277, cy, 28)]
    out = [liquid(d, shapes)]
    out.append(icon("back", 125, cy, 22, "#fff", op=0.97 if back_ok else 0.4))
    out.append(icon("next", 277, cy, 22, "#fff", op=0.97))
    out.append(pause_disc(d, CX, cy, paused, progress))
    return "".join(out)


def single_pause(d, cy, paused=False, progress=0.4):
    return liquid(d, [("c", CX, cy, 42)]) + pause_disc(d, CX, cy, paused, progress)


def up_next_card(d, y, key, name, dur="0:40", reps=None, untimed=False, label="UP NEXT", w=346, h=96, book=True):
    x = (W - w) / 2
    out = [rr(x, y, w, h, 30, fill=d.linear("un-card", [(0, "#fff", 0.115), (1, "#fff", 0.06)])), rr(x + 0.5, y + 0.5, w - 1, h - 1, 29.5, stroke="#fff", sw=1, op=0.14)]
    out.append(thumb(d, key, x + 10, y + 10, 76, 76, 20, big=True))
    out.append(rr(x + 14, y + 14, 26, 21, 10.5, fill="#fff") + icon("forward", x + 27, y + 24.5, 12, "#000"))
    tx = x + 100
    nm = lines(name, 17, w - 100 - 46, maxlines=2)
    two = len(nm) == 2
    out.append(text(d, label, tx, y + (24 if two else 29), 10, "black", "#fff", tracking=3, opacity=0.5))
    for i, ln in enumerate(nm):
        out.append(text(d, ln, tx, y + (44 if two else 50) + i * 19, 17, "black", "#fff"))
    out.append(facts(d, tx, y + (84 if two else 74), dur=dur, reps=reps, untimed=untimed, size=12))
    if book:
        out.append(icon("book", x + w - 28, y + h / 2, 18, "#fff", op=0.5))
    return "".join(out)


def up_next_pill(d, y, key, name, h=48):
    nm = lines(name, 15, 250, maxlines=1)[0]
    w = measure(nm, 15, "black") + 52 + 44
    x = CX - w / 2
    return (liquid(d, [("p", x, y, w, h, h / 2)]) + thumb(d, key, x + 6, y + 6, 36, 36, 11) + text(d, nm, x + 52, y + h / 2 + 5.5, 15, "black", "#fff")
            + icon("forward", x + w - 24, y + h / 2, 14, "#fff", op=0.8))


def rest_exercise(d, cy, picks, selected=0):
    """The suggested rest exercise set on the workout: small real icon(s) in the rest indicator."""
    out = []
    if len(picks) == 1:
        key = picks[0]
        name, sec = REST_EX[key]
        nm = lines(name, 14, 190, maxlines=1)[0]
        tw = measure(nm, 14, "black")
        w = 12 + 38 + 10 + max(tw, 74) + 14 + 40
        x = CX - w / 2
        out.append(liquid(d, [("p", x, cy - 24, w, 48, 24)]))
        out.append(thumb(d, key, x + 8, cy - 19, 38, 38, 12, op=1))
        out.append(circ(x + 8 + 38 - 3, cy + 19 - 3, 9.5, fill="#0b0b0d", stroke="#fff", sw=1, op=1))
        out.append(icon("cooldown", x + 8 + 38 - 3, cy + 19 - 3, 12, "#fff"))
        out.append(text(d, "REST EXERCISE", x + 58, cy - 5, 9, "black", "#fff", tracking=2, opacity=0.5))
        out.append(text(d, nm, x + 58, cy + 13, 14, "black", "#fff"))
        out.append(text(d, f"{sec} s", x + w - 14, cy + 5, 13, "black", "#fff", anchor="end", tnum=True, opacity=0.75))
    else:
        n = len(picks)
        gap = 10
        w = n * 44 + (n - 1) * gap + 24
        x = CX - w / 2
        out.append(liquid(d, [("p", x, cy - 28, w, 56, 28)]))
        for i, key in enumerate(picks):
            tx = x + 12 + i * (44 + gap)
            out.append(thumb(d, key, tx, cy - 22, 44, 44, 14, op=1 if i == selected else 0.5))
            if i == selected:
                out.append(rr(tx - 2.5, cy - 24.5, 49, 49, 16.5, stroke=ORANGE, sw=2.5))
            out.append(circ(tx + 41, cy + 19, 9, fill="#0b0b0d", stroke="#fff", sw=1))
            out.append(icon("cooldown", tx + 41, cy + 19, 11.5, "#fff"))
        name, sec = REST_EX[picks[selected]]
        out.append(text(d, f"{name} · {sec} s", CX, cy + 48, 12, "black", "#fff", anchor="middle", opacity=0.7))
    return "".join(out)


def queue_strip(d, y, keys, cur, breaks=(), shuffle=False, cell=56, gap=8):
    positions, x = [], 0.0
    for i in range(len(keys)):
        if i in breaks and i > 0:
            x += 10
        positions.append(x)
        x += cell + gap
    base = CX - cell / 2 - positions[cur]
    cells = []
    for i, k in enumerate(keys):
        px = base + positions[i]
        if i in breaks and i > 0:
            cells.append(rr(px - 11.5, y + cell / 2 - cell * 0.3, 3, cell * 0.6, 1.5, fill="#fff", op=0.22))
        if i == cur:
            sc = 1.08
            sx, sy = px - cell * (sc - 1) / 2, y - cell * (sc - 1) / 2
            cells.append(thumb(d, k, sx, sy, cell * sc, cell * sc, cell * 0.3))
            cells.append(rr(sx, sy, cell * sc, cell * sc, cell * 0.3, stroke="#fff", sw=3))
        else:
            done = i < cur
            cells.append(thumb(d, k, px, y, cell, cell, cell * 0.28, op=0.42 if done else 1))
            cells.append(rr(px + 0.5, y + 0.5, cell - 1, cell - 1, cell * 0.28, stroke="#fff", sw=1, op=0.10))
            if done:
                cells.append(icon("checkcircle", px + cell / 2, y + cell / 2, cell * 0.4, "#fff", inner="#1a1a1a"))
    m = d.uid("m")
    grad = d.linear("qs-fade", [(0, "#000", 0), (0.09, "#fff", 1), (0.91, "#fff", 1), (1, "#000", 0)], x1=0, y1=0, x2=1, y2=0)
    d.define(m, f'<mask id="{m}" maskUnits="userSpaceOnUse" x="0" y="{f(y - 12)}" width="{W}" height="{cell + 24}"><rect x="0" y="{f(y - 12)}" width="{W}" height="{cell + 24}" fill="{grad}"/></mask>')
    out = f'<g mask="url(#{m})">{"".join(cells)}</g>'
    if shuffle:
        out += icon("shuffle", 28, y + cell / 2, 15, "#fff", op=0.7)
    return out


def card_overlay(d, x, y, w, h, r, name, dur, reps, size, role):
    clip = d.clip_rr(x, y, w, h, r)
    g = d.linear(f"cardgrad-{role}", [(0.42, "#000", 0), (1, "#000", 0.9)])
    out = [f'<g clip-path="url(#{clip})"><rect x="{f(x)}" y="{f(y)}" width="{f(w)}" height="{f(h)}" fill="{g}"/></g>']
    ls = lines(name, size, w - 28, maxlines=2)
    base = y + h - 26 - 26 * 0 - (len(ls) - 1) * (size + 3) - 22
    for i, ln in enumerate(ls):
        out.append(text(d, ln, x + 14, base + i * (size + 3), size, "black", "#fff"))
    out.append(facts(d, x + 14, y + h - 16, dur=dur, reps=reps, size=12 if role == "now" else 11))
    return "".join(out)


def now_card(d, key, x, y, w, h, name, dur, reps=None, r=36):
    out = [rr(x + 6, y + 22, w - 12, h - 14, r, fill="#000", op=0.5, extra=f' filter="url(#{d.blur(16)})"')]
    out.append(clip_loop(d, key, "now", x, y, w, h, r))
    out.append(card_overlay(d, x, y, w, h, r, name, dur, reps, 24, "now"))
    out.append(rr(x + 12, y + 12, 38, 30, 15, fill="#fff") + icon("play", x + 31.5, y + 27, 13, "#000"))
    out.append(rr(x + 1, y + 1, w - 2, h - 2, r - 1, stroke="#fff", sw=2, op=0.92))
    return "".join(out)


def next_tile(d, key, x, y, w, h, name, dur, reps=None, r=28):
    out = [clip_loop(d, key, "next", x, y, w, h, r), card_overlay(d, x, y, w, h, r, name, dur, reps, 14, "next")]
    out.append(rr(x + 10, y + 10, 32, 26, 13, fill="#fff") + icon("forward", x + 26, y + 23, 13, "#000"))
    out.append(rr(x + 0.5, y + 0.5, w - 1, h - 1, r - 0.5, stroke="#fff", sw=1, op=0.2))
    return "".join(out)


def hero(d, key, x, y, w, h, r=44, counter=None, paused=False):
    out = [rr(x + 8, y + 26, w - 16, h - 20, r, fill="#000", op=0.55, extra=f' filter="url(#{d.blur(18)})"')]
    out.append(clip_loop(d, key, "hero", x, y, w, h, r))
    out.append(rr(x + 0.5, y + 0.5, w - 1, h - 1, r - 0.5, stroke="#fff", sw=1, op=0.14))
    if counter:
        cw = measure(counter, 12, "black", tnum=True) + 22
        out.append(rr(x + w - cw - 14, y + 14, cw, 26, 13, fill="#000", op=0.55) + text_c(d, counter, x + w - cw / 2 - 14, y + 27, 12, face_key="black", fill="#fff", tnum=True))
    if paused:
        out.append(liquid(d, [("p", CX - 52, y + h - 40, 104, 34, 17)], "clear") + icon("pause", CX - 28, y + h - 23, 14, "#fff") + text(d, "Paused", CX - 14, y + h - 17.5, 14, "black", "#fff"))
    return "".join(out)


def meta_row(d, y, sets, cur, reps):
    rt = f"{reps} reps" if reps else ""
    dw = 26 + 15 * (sets - 1)
    tw = measure(rt, 15, "bold") + 16 if rt else 0
    gx = CX - (dw + tw) / 2
    out = [dots(d, gx + dw / 2, y, sets, cur)]
    if rt:
        out.append(text(d, rt, gx + dw + 16, y + 5.5, 15, "bold", "#fff", opacity=0.62))
    return "".join(out)


def title_block(d, name, base2, size=26, maxw=290):
    ls = lines(name, size, maxw, maxlines=2)
    out = []
    for i, ln in enumerate(reversed(ls)):
        y = base2 - i * (size + 4)
        out.append(text(d, ln, CX, y, size, "black", "#fff", anchor="middle"))
    last = ls[-1]
    bx = CX + measure(last, size, "black") / 2 + 20
    out.append(icon("book", bx, base2 - size * 0.34, 17, "#fff", op=0.55))
    return "".join(out)


# views -----------------------------------------------------------------------------------------------------------
def work_single(d, paused=False, last=False, untimed=False, clock_text="21", progress=0.36, toast=True):
    key, name, dur, reps = SPRAWL
    b = [backdrop_clip(d, key), top_bar(d, badge="2 / 3")]
    if not untimed:
        b.append(hero(d, key, 43, 126, 316, 316, 44, paused=paused))
        b.append(title_block(d, name, 516))
        b.append(meta_row(d, 546, 4, 1, reps))
        b.append(clock(d, clock_text, 650, 104, op=0.4 if paused else 1))
        b.append(transport(d, 722, paused, progress))
        b.append(flag_chip(d, 805) if last else up_next_pill(d, 782, "sprawl", "Sprawls 4x7, hips straight down, pop up"))
    else:
        b.append(hero(d, key, 74, 124, 254, 254, 40))
        b.append(title_block(d, name, 424, size=22, maxw=300))
        b.append(meta_row(d, 450, 4, 1, None) + text(d, "7 reps", CX + 62, 455.5, 14, "bold", "#fff", opacity=0.62))
        b.append(text(d, "7", CX, 548, 88, "black", "#fff", anchor="middle", tnum=True) + caption(d, "REPS", 578))
        b.append(liquid(d, [("p", CX - 52, 596, 104, 34, 17)]) + icon("stopwatch", CX - 28, 613, 15, "#fff") + text(d, "0:23", CX - 12, 618.5, 15, "black", "#fff", tnum=True))
        b.append(pill(d, CX, 676, 346, 62, "Done", "orange", 21, "check"))
        b.append(liquid(d, [("c", 128, 758, 25), ("c", CX, 758, 30), ("c", 274, 758, 25)]) + icon("back", 128, 758, 20) + icon("next", 274, 758, 20) + icon("pause", CX, 758, 24, "#fff"))
    if toast:
        b.append(voice_toast(d, 126, "Sprawls 4x7, hips straight down, pop up"))
    return "".join(b)


def flag_chip(d, cx):
    return liquid(d, [("p", cx - 34, 782, 68, 48, 24)]) + icon("flag", cx, 806, 22, "#fff", op=0.9)


def work_bundle(d, cur=4, toast=True):
    keys = [k for k, *_ in S6] * 3
    names = {k: (n, du, r) for k, n, du, r in S6}
    key = keys[cur]
    nxt = keys[cur + 1]
    b = [backdrop_clip(d, key), top_bar(d, items=("clipboard", "music", "slider"), badge="2 / 3")]
    b.append(now_card(d, key, 18, 126, 244, 286, names[key][0], names[key][1], names[key][2]))
    b.append(next_tile(d, nxt, 276, 126, 108, 286, names[nxt][0], names[nxt][1], names[nxt][2]))
    b.append(queue_strip(d, 432, keys, cur, breaks={3, 6}))
    b.append(icon("repeat", CX - 60, 520, 15, "#fff", op=0.7) + dots(d, CX + 6, 520, 3, 1))
    b.append(clock(d, "27", 642, 100))
    b.append(transport(d, 724, progress=0.33))
    if toast:
        b.append(voice_toast(d, 126, names[key][0]))
    return "".join(b)


def phase_common(d, key, cap, clock_text, base, pause_cy, progress, caption_y):
    return [backdrop_clip(d, key), top_bar(d), caption(d, cap, caption_y), clock(d, clock_text, base, 116), single_pause(d, pause_cy, False, progress)]


def warm(d):
    b = phase_common(d, "dive", "WARM UP", "38", 408, 492, 0.37, 262)
    b[1] = top_bar(d, badge=None)
    b.append(pill(d, CX, 566, 214, 52, "Skip Warm Up", "white", 17))
    b.append(up_next_card(d, 628, "dive", S0[0][1], S0[0][2], S0[0][3]))
    b.append(voice_toast(d, 142, "Warm up"))
    return "".join(b)


def prep_bundle(d):
    b = phase_common(d, "dive", "PREPARATION", "03", 408, 492, 0.25, 262)
    b.append(pill(d, CX, 566, 238, 52, "Skip Preparation", "white", 17))
    b.append(up_next_card(d, 628, "dive", S0[0][1], S0[0][2], S0[0][3], label="GET READY"))
    b.append(queue_strip(d, 744, [k for k, *_ in S0], 0, cell=44, gap=7))
    b.append(voice_toast(d, 142, "Preparation"))
    return "".join(b)


def rest_layout(d, key, cap, clock_text, progress, sets=None, cur=0, picks=("couch",), selected=0, row="rest", toast="Rest"):
    b = [backdrop_clip(d, key), top_bar(d), caption(d, cap, 262)]
    if sets:
        b.append(dots(d, CX, 292, sets, cur))
    b.append(rest_exercise(d, (342 if sets else 316) if len(picks) == 1 else 304, picks, selected))
    b.append(clock(d, clock_text, 462, 116))
    b.append(single_pause(d, 538, False, progress))
    cy = 610
    b.append(liquid(d, [("p", 49, cy - 25, 84, 50, 25), ("p", 138, cy - 25, 84, 50, 25)], "orange"))
    b.append(text_c(d, "+15s", 91, cy, 16, face_key="black", fill="#fff", tnum=True) + text_c(d, "+30s", 180, cy, 16, face_key="black", fill="#fff", tnum=True))
    b.append(pill(d, 303, cy, 134, 50, "Skip Rest", "white", 16))
    if toast:
        b.append(voice_toast(d, 142, toast))
    return b


def rest_exercises(d):
    k, n, du, r = S0[1]
    b = rest_layout(d, k, "REST BETWEEN SETS", "11", 0.27, picks=("couch",))
    b.append(up_next_card(d, 660, k, n, du, r))
    b.append(queue_strip(d, 774, [x[0] for x in S0], 1, cell=44, gap=7))
    return "".join(b)


def rest_sets(d):
    k, n, du, r = SPRAWL
    b = rest_layout(d, k, "REST BETWEEN SETS", "1:02", 0.31, sets=4, cur=1, picks=("straddle",))
    b[2] = caption(d, "REST BETWEEN SETS", 252)
    b.append(up_next_card(d, 664, k, n, du, r))
    return "".join(b)


def rest_sections(d):
    k, n, du, r = S6[0]
    b = rest_layout(d, k, "REST", "14", 0.3, picks=("couch", "cobra"), selected=0)
    b[0] = backdrop_clip(d, k)
    b.append(up_next_card(d, 660, k, n, du, r))
    b.append(queue_strip(d, 774, [x[0] for x in S6] * 3, 0, breaks={3, 6}, cell=44, gap=7))
    return "".join(b)


def warm_pick(d, selected=2):
    b = [rr(0, 0, W, H, 0, fill="#000")]
    glow = d.radial("wu-glow", [(0, ORANGE, 0.22), (1, ORANGE, 0)])
    b.append(f'<ellipse cx="{CX}" cy="830" rx="330" ry="210" fill="{glow}"/>')
    b.append(top_bar(d, items=(), badge=None, voice=None))
    b.append(text(d, "Warm Up", CX, 300, 72, "ribbon", "#fff", anchor="middle"))
    labels = ["Skip", "0:30", "1:00", "1:30", "2:00", "3:00"]
    cw, ch, gap = 104, 66, 12
    x0 = (W - (3 * cw + 2 * gap)) / 2
    for i, lab in enumerate(labels):
        px, py = x0 + (i % 3) * (cw + gap), 366 + (i // 3) * (ch + gap)
        if i == selected:
            b.append(liquid(d, [("p", px, py, cw, ch, 26)], "white") + text_c(d, lab, px + cw / 2, py + ch / 2, 20, face_key="black", fill="#0a0a0a", tnum=True))
        else:
            b.append(liquid(d, [("p", px, py, cw, ch, 26)]) + text_c(d, lab, px + cw / 2, py + ch / 2, 17, face_key="bold", fill="#fff", tnum=True, opacity=0.92))
    b.append(pill(d, CX, 574, 336, 62, "Start", "white", 20, "play"))
    return "".join(b)

def ribbon_title(d, s, cx, base, size):
    """Letters in the TimeMaster ribbon face; anything it has no glyph for (digits, punctuation) in Inter Black at the ribbon's cap height."""
    runs = []
    for ch in s:
        ok = ch == " " or (ch.isascii() and ch.isalpha())
        if runs and runs[-1][0] == ok:
            runs[-1][1] += ch
        else:
            runs.append([ok, ch])
    cap_r = face("ribbon").tt["OS/2"].sCapHeight / face("ribbon").upm or 0.7
    cap_i = face("black").tt["OS/2"].sCapHeight / face("black").upm or 0.727
    k = cap_r / cap_i
    sizes = [size if ok else size * k for ok, _ in runs]
    widths = [measure(t, sz, "ribbon" if ok else "black") for (ok, t), sz in zip(runs, sizes)]
    x = cx - sum(widths) / 2
    out = []
    for (ok, t), sz, wd in zip(runs, sizes, widths):
        out.append(text(d, t, x, base, sz, "ribbon" if ok else "black", "#fff"))
        x += wd
    return "".join(out)


def resume(d):
    key = "kick"
    b = [backdrop_clip(d, key, 0.6), top_bar(d, items=(), badge=None, voice=None)]
    b.append(caption(d, "WORKOUT PAUSED", 206))
    b.append(ribbon_title(d, "Wrestling 1", CX, 276, 60))
    b.append(text(d, "12:48", CX, 400, 92, "black", "#fff", anchor="middle", tnum=True))
    b.append(text(d, "into this workout · paused 2 h ago", CX, 436, 15, "bold", "#fff", anchor="middle", opacity=0.55))
    b.append(up_next_card(d, 478, key, "Kick-throughs 30 s", "0:30", None, label="PAUSED ON", book=False))
    b.append(pill(d, CX, 650, 346, 62, "Resume workout", "orange", 19, "play"))
    b.append(pill(d, CX, 722, 346, 54, "Finish and save", "dark", 17))
    b.append(text(d, "Discard session", CX, 800, 16, "black", "#ff6b5f", anchor="middle"))
    return "".join(b)


def completed(d):
    import random
    random.seed(7)
    b = [rr(0, 0, W, H, 0, fill="#000")]
    glow = d.radial("done-glow", [(0, "#fff", 0.2), (1, "#fff", 0)])
    b.append(f'<ellipse cx="{CX}" cy="300" rx="260" ry="260" fill="{glow}"/>')
    for _ in range(46):
        x, y = random.uniform(10, 392), random.uniform(70, 520)
        col = random.choice(["#fff", "#fff", ORANGE, "#9a9aa0", "#ffd2b0"])
        w, h, rot = random.uniform(5, 9), random.uniform(9, 15), random.uniform(0, 180)
        b.append(f'<rect x="{f(x)}" y="{f(y)}" width="{f(w)}" height="{f(h)}" rx="1.5" fill="{col}" opacity="{f(random.uniform(.55, .95))}" transform="rotate({f(rot)} {f(x + w / 2)} {f(y + h / 2)})"/>')
    b.append(circ(CX, 300, 56, fill="#fff") + icon("check", CX, 300, 62, "#000"))
    b.append(text(d, "Workout Complete", CX, 426, 36, "black", "#fff", anchor="middle"))
    b.append(text(d, "Great job finishing Wrestling 1.", CX, 464, 17, "bold", "#fff", anchor="middle", opacity=0.6))
    items = [("28:41", "timer"), ("14 sets", "repeat"), ("3 sections", "flag")]
    ws = [measure(t, 15, "black", tnum=True) + 21 + 28 for t, _ in items]
    x = CX - (sum(ws) + 10 * (len(ws) - 1)) / 2
    for (t, ic), wd in zip(items, ws):
        b.append(liquid(d, [("p", x, 500, wd, 40, 20)]) + icon(ic, x + 14 + 7.5, 520, 17, "#fff") + text(d, t, x + 14 + 21, 525.5, 15, "black", "#fff", tnum=True))
        x += wd + 10
    b.append(pill(d, CX, 780, 346, 62, "Done", "orange", 20))
    return "".join(b)


def early_done(d, kind):
    b = [backdrop_clip(d, "sprawl", 0.2), rr(0, 0, W, H, 0, fill="#000", op=0.82)]
    glow = d.radial("orb-glow", [(0, ORANGE, 0.6), (1, ORANGE, 0)])
    b.append(f'<circle cx="{CX}" cy="300" r="150" fill="{glow}"/>')
    b.append(circ(CX, 300, 64, fill=ORANGE, extra=f' filter="url(#{d.blur(14)})"', op=0.5) + circ(CX, 300, 64, fill=ORANGE))
    b.append(icon("bolt" if kind == "superhuman" else "hourglass", CX, 300, 58, "#000"))
    if kind == "superhuman":
        b.append(text(d, "Are you a superhuman?", CX, 426, 30, "black", "#fff", anchor="middle"))
        b.append(text(d, "No way you finished by that time.", CX, 462, 17, "bold", "#fff", anchor="middle", opacity=0.7))
        b.append(pill(d, CX, 560, 346, 56, "Yes", "orange", 18))
    else:
        b.append(text(d, "Are you sure you're done?", CX, 426, 30, "black", "#fff", anchor="middle"))
        b.append(text(d, "Only 0:06 into this set.", CX, 462, 17, "bold", "#fff", anchor="middle", opacity=0.7))
        b.append(pill(d, 108, 560, 160, 56, "Not yet", "dark", 18))
        b.append(pill(d, 290, 560, 186, 56, "Yes, I'm done", "orange", 18))
    return "".join(b)


def stop_alert(d):
    key, name, dur, reps = SPRAWL
    b = [work_single(d, toast=False), rr(0, 0, W, H, 0, fill="#000", op=0.5)]
    x, y, w, h = 56, 340, 290, 188
    b.append(liquid(d, [("p", x, y, w, h, 36)], "dark"))
    b.append(rr(x, y, w, h, 36, fill="#101012", op=0.55))
    b.append(text(d, "Stop Workout?", CX, y + 50, 19, "black", "#fff", anchor="middle"))
    b.append(text(d, "Your progress will be lost.", CX, y + 76, 14, "bold", "#fff", anchor="middle", opacity=0.65))
    b.append(pill(d, x + 78, y + 142, 128, 48, "Continue", "dark", 16) + pill(d, x + 214, y + 142, 128, 48, "Stop", "red", 16))
    return "".join(b)


def preview_sheet(d):
    key, name, dur, reps = S0[1]
    b = [work_single(d, toast=False), rr(0, 0, W, 360, 0, fill="#000", op=0.35)]
    top = 360
    b.append(rr(0, top, W, H - top, 38, fill="#161618"))
    b.append(rr(0, top, W, H - top, 38, stroke="#fff", sw=1, op=0.1))
    b.append(rr(CX - 18, top + 8, 36, 5, 2.5, fill="#fff", op=0.35))
    b.append(liquid(d, [("p", 24, top + 30, 354, 52, 26)], "dark"))
    b.append(icon("stopwatch", 54, top + 56, 18, "#fff", op=0.8) + text(d, "Wrestling 1", 78, top + 52, 13, "black", "#fff") + text(d, "0:21", 78, top + 70, 12, "bold", "#fff", tnum=True, opacity=0.6))
    b.append(circ(330, top + 56, 18, fill="#fff") + icon("pause", 330, top + 56, 16, "#000"))
    b.append(clip_loop(d, key, "sheet", 24, top + 100, 354, 211, 26))
    b.append(text(d, "Hand Walkout", 24, top + 350, 30, "black", "#fff"))
    b.append(text(d, "Up next · 1:15 · 10 reps", 24, top + 376, 15, "bold", "#fff", opacity=0.55))
    for i, w in enumerate((300, 260, 280)):
        b.append(rr(24, top + 404 + i * 22, w, 9, 4.5, fill="#fff", op=0.12))
    return "".join(b)


def music_sheet(d):
    b = [work_bundle(d, toast=False), rr(0, 0, W, H, 0, fill="#000", op=0.55)]
    top = 150
    b.append(rr(0, top, W, H - top, 38, fill="#111113") + rr(0, top, W, H - top, 38, stroke="#fff", sw=1, op=0.1))
    b.append(text(d, "Live Music", CX, top + 64, 40, "ribbon", "#fff", anchor="middle"))
    b.append(lobe_button(d, 40, top + 52, 22, "xmark", 16))
    b.append(pill(d, 340, top + 52, 84, 44, "Done", "dark", 15))
    for i, (nm, st, wd) in enumerate((("Flow", 0, 150), ("Pulse", 160, 120), ("Recovery", 290, 90))):
        yy = top + 120 + i * 58
        b.append(rr(24, yy, 354, 46, 14, fill="#fff", op=0.06))
        b.append(rr(24 + st * 0.9, yy + 4, wd, 38, 10, fill=ORANGE, op=0.8 if i == 1 else 0.35))
        b.append(text(d, nm, 36 + st * 0.9, yy + 28, 14, "black", "#fff"))
    b.append(rr(24 + 150, top + 108, 3, 190, 1.5, fill="#fff"))
    b.append(liquid(d, [("p", 20, top + 330, 362, 70, 30)]))
    b.append(thumb(d, "couch", 34, top + 342, 46, 46, 23) + text(d, "Pulse", 92, top + 362, 17, "black", "#fff") + text(d, "0:42", 92, top + 382, 13, "bold", "#fff", tnum=True, opacity=0.6))
    b.append(icon("pause", 330, top + 365, 20, "#fff") + icon("next", 360, top + 365, 18, "#fff"))
    b.append(liquid(d, [("p", 24, top + 424, 354, 12, 6)], "clear") + rr(24, top + 424, 210, 12, 6, fill="#fff", op=0.85))
    return "".join(b)
