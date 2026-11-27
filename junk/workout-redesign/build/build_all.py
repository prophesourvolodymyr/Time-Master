"""Writes every view as its own SVG (phone + short notes) plus one overview sheet and the motion sheet."""
import math
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

import views as V
from svgkit import *

OUT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

N = {
    "loop": "The cards play your real attachment, muted, on repeat (a flipbook of the real clip, so it moves in any browser).",
    "voice": "Voice: the spoken name sits in a caption under the top bar and a waveform lobe in the top group. The voice belongs to the session, not the screen: it keeps speaking through slides, sheets and resume, and the lobe mutes it.",
    "gooey": "Gooey glass: lobes that are close merge with liquid necks; pressing lifts and stretches one toward the finger and it wobbles back (Telegram springs from EverBounce).",
}

VIEWS = [
    ("01-resume-full-screen", V.resume, "Resume: full screen", [
        "Opens full screen, never as a slide-over with a transparent top. Same backdrop, same buttons as the player.",
        "Start from the home-screen widget, the Home card or a link lands here only when something is really saved; otherwise it goes straight into the player.",
        "A finished workout is never offered: the checkpoint is deleted on finish and cannot be written again.",
        "Resume morphs into the player in place (no dismiss-then-present). Finish and save logs a partial workout. Discard asks first."]),
    ("02-warm-up-choice", V.warm_pick, "Warm-up choice", [
        "Title in the TimeMaster ribbon face. Six gooey glass chips; the chosen one turns white. Start is the white glass pill.",
        N["gooey"]]),
    ("03-warm-up", V.warm, "Warm-up", [
        "Caption, big clock in Inter Black (tabular, digits roll), pause with the phase ring inside its glass, Skip, Up Next card with the real first exercise.",
        N["voice"]]),
    ("04-get-ready-bundle", V.prep_bundle, "Get ready (bundle)", [
        "Same layout as warm-up. In a bundle the whole queue shows under the Up Next card as small real frames.",
        N["voice"]]),
    ("05-work-single", V.work_single, "Work: single exercise", [
        N["loop"],
        "Title wraps to two lines for long names; the book glyph opens the exercise page. Set dots and reps, clock, gooey transport trio, Up Next pill.",
        N["voice"], N["gooey"]]),
    ("06-work-single-paused", lambda d: V.work_single(d, paused=True, toast=False), "Work: paused", [
        "The clip freezes with the clock (it pauses in the hero), a glass Paused chip sits on the card, the clock dims and the disc turns to play."]),
    ("07-work-single-until-done", lambda d: V.work_single(d, untimed=True), "Work: until done", [
        "Reps big, a count-up stopwatch and one orange glass Done button. Too early a Done opens the two popups (view 15, 16)."]),
    ("08-work-single-last", lambda d: V.work_single(d, last=True, toast=False), "Work: last exercise", [
        "The Up Next pill becomes a chequered flag on the last exercise of the workout."]),
    ("09-work-bundle", V.work_bundle, "Work: bundle", [
        N["loop"],
        "Now card and Next tile both loop their real clip. The queue shows every exercise of every round with dividers between rounds; done ones are dimmed with a check, the current one has the white ring.",
        "Pressing Next slides the cards (see the motion sheet) with haptics, and the voice says the new name as the card lands.",
        N["voice"]]),
    ("10-rest-between-exercises", V.rest_exercises, "Rest: between exercises", [
        "REST INDICATOR: the small real icon of the rest exercise set on this workout sits right under the caption: thumbnail, a cooldown glyph badge, its name and seconds. Tap opens its page without stopping the clock.",
        "Orange glass +15s and +30s merge as one liquid pill; Skip Rest is white glass.",
        "Up Next card, then the queue as small real frames. " + N["voice"]]),
    ("11-rest-between-sets", V.rest_sets, "Rest: between sets", [
        "REST INDICATOR: set dots, then the rest exercise icon with its name and seconds, then the clock.",
        "Up Next shows the same exercise again (set 2 of 4). The library has no rest exercise set on any workout yet, so these mockups attach real pages (Couch Stretch, Seated Straddle) to show where it appears."]),
    ("12-rest-between-sections", V.rest_sections, "Rest: between sections", [
        "When the rest has several suggested exercises they show as a row of small icons; the first tap selects (orange ring), a second tap opens the page. The chosen name and seconds are written under the row.",
        "Up Next is the first exercise of the next section, with that section's queue."]),
    ("13-completed", V.completed, "Workout complete", [
        "White check, Inter Black title, three glass chips (time, sets, sections), confetti and the orange Done button. Haptic: success, then a heavy tap."]),
    ("14-stop-confirm", V.stop_alert, "Stop workout?", ["Glass alert over the dimmed player. Stop is red glass."]),
    ("15-early-done-1", lambda d: V.early_done(d, "superhuman"), "Early Done: first tap", ["Orange orb popup on the dimmed player. One answer: Yes."]),
    ("16-early-done-2", lambda d: V.early_done(d, "confirm"), "Early Done: second tap", ["Second early tap: Not yet keeps the set running, Yes, I'm done leaves it."]),
    ("17-exercise-preview-sheet", V.preview_sheet, "Up Next preview sheet", [
        "Tapping the Up Next card opens the exercise page as a real sheet that leaves the clock and pause visible above it; the mini controls bar stays on top. The clip loops here too.",
        "Sheets are for previews only; the player itself is always full screen."]),
    ("18-music-sheet", V.music_sheet, "Live Music sheet", ["Same sheet, new glass: timeline with the playhead, the now-playing row and the volume bar."]),
]


def panel(title, sub, bullets, x, y, w=348):
    out = [note(sub.upper(), x, y, 11, ORANGE, 800, extra=' letter-spacing="2"')]
    for i, tl in enumerate(wrap(title, w, 22)):
        out.append(note(tl, x, y + 30 + i * 28, 22, "#fff", 800))
    cy = y + 38 + 28 * len(wrap(title, w, 22)) + 18
    for b in bullets:
        ls = wrap(b, w, 13)
        out.append(circ(x + 3, cy - 4, 2.5, fill=ORANGE))
        for ln in ls:
            out.append(note(ln, x + 16, cy, 13, "#d1d1d6", 500))
            cy += 19
        cy += 9
    return "".join(out)


def build_page(idx, fn, title, bullets):
    d = Doc()
    inner = fn(d)
    body = device(d, inner, 40, 40) + panel(title, f"View {idx}", bullets, 40 + W + 40, 70)
    return d.render(40 + W + 40 + 348 + 40, H + 80, body, bg="#161619", title=title)


def spring_p(t, response=0.42, zeta=0.82):
    w = 2 * math.pi / response
    wd = w * math.sqrt(1 - zeta * zeta)
    return 1 - math.exp(-zeta * w * t) * (math.cos(wd * t) + zeta * w / wd * math.sin(wd * t))


def lerp(a, b, t):
    return a + (b - a) * t


def motion_sheet():
    d = Doc()
    V.ANIM = False
    b = []
    b.append(text(d, "Motion, gooey and haptics", 40, 70, 40, "black", "#fff"))
    b.append(note("How the cards slide, how a gooey button feels under the finger, and what you feel and hear when.", 40, 100, 15, "#a1a1a6"))
    # card slide filmstrip
    b.append(note("1 · BUNDLE: NEXT PRESSED, CARDS SLIDE (spring 0.42 s)", 40, 150, 12, ORANGE, 800, extra=' letter-spacing="2"'))
    times = [0, 0.09, 0.18, 0.27, 0.42]
    keys = ["neckrock", "neckext", "bridge"]
    fw, fh, sc = 402, 330, 0.5
    for i, t in enumerate(times):
        ox, oy = 40 + i * (fw * sc + 18), 170
        p = spring_p(t)
        g = []
        clip = d.clip_rr(0, 0, fw, fh, 26)
        g.append(rr(0, 0, fw, fh, 26, fill="#050506"))
        cards = [
            (keys[0], (18, 20, 244, 286), (-250, 20, 244, 286), (1, 0)),
            (keys[1], (276, 20, 108, 286), (18, 20, 244, 286), (1, 1)),
            (keys[2], (420, 20, 108, 286), (276, 20, 108, 286), (0, 1)),
        ]
        for k, a, bb, (o0, o1) in cards:
            x, y, w, h = [lerp(a[j], bb[j], p) for j in range(4)]
            o = max(0, min(1, lerp(o0, o1, min(1, p))))
            g.append(f'<g opacity="{f(o)}">' + V.thumb(d, k, x, y, max(8, w), h, 30 if w > 150 else 24, big=True) + rr(x, y, max(8, w), h, 30 if w > 150 else 24, stroke="#fff", sw=2 if w > 150 else 1, op=0.8 if w > 150 else 0.25) + "</g>")
        b.append(f'<g transform="translate({ox} {oy}) scale({sc})"><g clip-path="url(#{clip})">{"".join(g)}</g></g>')
        b.append(note(f"t = {t:.2f} s", ox, oy + fh * sc + 22, 13, "#fff", 700))
    hx, hy = 40, 170 + fh * sc + 50
    b.append(note("HAPTICS + VOICE ALONG THE SLIDE", hx, hy, 12, ORANGE, 800, extra=' letter-spacing="2"'))
    ax0, ax1, ay = 40, 40 + 5 * (fw * sc + 18) - 18, hy + 46
    b.append(rr(ax0, ay, ax1 - ax0, 3, 1.5, fill="#fff", op=0.2))
    for t, lab, sub, col in ((0, "soft", "slide starts", "#fff"), (0.24, "rigid", "card lands (first contact)", ORANGE), (0.42, "soft", "rebound settles", "#fff")):
        x = ax0 + (ax1 - ax0) * t / 0.5
        b.append(circ(x, ay + 1.5, 7, fill=col) + note(lab, x, ay - 16, 14, "#fff", 800, "middle") + note(sub, x, ay + 28, 12, "#a1a1a6", 500, "middle"))
    vx = ax0 + (ax1 - ax0) * 0.24 / 0.5
    b.append(V.liquid(d, [("p", vx, ay + 46, ax1 - vx, 34, 17)], "clear") + icon("wave", vx + 20, ay + 63, 16, ORANGE) + note("voice says the new name as the card lands, and keeps going; the slide never cuts it", vx + 38, ay + 68, 13, "#fff", 700))
    # gooey states
    gy = hy + 190
    b.append(note("2 · GOOEY BUTTON UNDER THE FINGER (EverBounce: lift on 0.31 s / 0.72, release 0.42 s / 0.38)", 40, gy, 12, ORANGE, 800, extra=' letter-spacing="2"'))
    states = [("rest", "Lobes 7 pt apart merge.", (28, 42, 28), (0, 0), 1.0),
              ("press", "Lifts 23 %, medium tap.", (28, 42, 34), (0, 0), 1.0),
              ("drag", "Stretches toward the finger.", (28, 42, 28), (18, 0), 1.0),
              ("release", "Overshoots, wobbles, settles.", (28, 42, 25.5), (0, 0), 1.0)]
    for i, (nm, desc, rs, (dx, dy), _) in enumerate(states):
        ox = 40 + i * 272
        cy = gy + 78
        c1, c2, c3 = ox + 46, ox + 46 + 28 + 7 + 42, ox + 46 + 28 + 7 + 84 + 7 + 28
        shapes = [("c", c1, cy, rs[0]), ("c", c2, cy, rs[1])]
        if nm == "drag":
            shapes.append(("p", c3 - 28, cy - 32, 82, 64, 32))
            shapes[1] = ("c", c2 + 4, cy, 42)
        else:
            shapes.append(("c", c3, cy, rs[2]))
        b.append(V.liquid(d, shapes))
        b.append(icon("back", c1, cy, 22) + icon("pause", c2, cy, 26) + icon("next", c3 + (9 if nm == "drag" else 0), cy, 22))
        b.append(note(nm.upper(), ox, cy + 74, 13, "#fff", 800) + note(desc, ox, cy + 94, 12, "#a1a1a6", 500))
    # voice persistence row
    vy = gy + 230
    b.append(note("3 · VOICE PERSISTS", 40, vy, 12, ORANGE, 800, extra=' letter-spacing="2"'))
    lines_v = ["Spoken: warm up, preparation, each exercise name, rest, 3-2-1 beeps, quarter-time calls, finish.",
               "Owned by the session, not the view: slides, sheets, the preview, resume and the lock screen do not cut it; only Pause or a newer callout does.",
               "The waveform lobe in the top group shows it is speaking and mutes it; the choice is remembered."]
    for i, ln in enumerate(lines_v):
        b.append(circ(46, vy + 28 + i * 24 - 4, 2.5, fill=ORANGE) + note(ln, 58, vy + 28 + i * 24, 14, "#d1d1d6", 500))
    return d.render(40 + 5 * (fw * sc + 18) + 22, vy + 120, "".join(b), bg="#161619", title="Motion, gooey and haptics")


def overview():
    d = Doc()
    V.ANIM = False
    sc = 0.36
    cols = 6
    cw, ch = W * sc + 30, H * sc + 64
    b = [text(d, "Tmax workout player: every view", 40, 70, 40, "black", "#fff"),
         note("Each tile is its own file in this folder (open in Safari or Chrome: the real clips loop there). Motion, gooey and haptics are on sheet 19.", 40, 100, 15, "#a1a1a6")]
    for i, (name, fn, title, _) in enumerate(VIEWS):
        col, row = i % cols, i // cols
        x, y = 40 + col * cw, 150 + row * ch
        b.append(device(d, fn(d), x, y, sc, chrome=True))
        b.append(note(f"{i + 1:02d} · {title}", x, y + H * sc + 22, 11, "#fff", 700))
    rows = (len(VIEWS) + cols - 1) // cols
    return d.render(40 + cols * cw, 150 + rows * ch + 20, "".join(b), bg="#161619", title="Tmax workout player: every view")


def main():
    V.ANIM = True
    files = []
    for i, (name, fn, title, bullets) in enumerate(VIEWS, 1):
        V.ANIM = True
        path = os.path.join(OUT, name + ".svg")
        open(path, "w").write(build_page(i, fn, title, bullets))
        files.append(path)
        print(name, os.path.getsize(path) // 1024, "KB")
    path = os.path.join(OUT, "19-motion-gooey-haptics.svg")
    open(path, "w").write(motion_sheet())
    files.append(path)
    V.ANIM = False
    path = os.path.join(OUT, "00-overview.svg")
    open(path, "w").write(overview())
    files.append(path)
    print("overview", os.path.getsize(path) // 1024, "KB")
    return files


def shot(path):
    png = "/tmp/wk/png/" + os.path.basename(path).replace(".svg", ".png")
    import re
    head = open(path).read(400)
    m = re.search(r'width="([\d.]+)" height="([\d.]+)"', head)
    w, h = int(float(m.group(1))), int(float(m.group(2)))
    subprocess.run(["/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", "--headless=new", "--disable-gpu", "--hide-scrollbars",
                    "--force-device-scale-factor=1", f"--window-size={w},{h}", "--virtual-time-budget=1500", f"--screenshot={png}", "file://" + path],
                   capture_output=True)
    return png


if __name__ == "__main__":
    files = main()
    if "--shots" in sys.argv:
        only = [a for a in sys.argv[1:] if not a.startswith("--")]
        todo = [p for p in files if not only or any(o in p for o in only)]
        with ThreadPoolExecutor(4) as ex:
            for png in ex.map(shot, todo):
                print("shot", png)
