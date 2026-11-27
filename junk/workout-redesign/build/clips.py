"""Loop frames from the user's real attachment videos, cropped to each card's shape, for the looping mockups."""
import base64
import io
import json
import os
import subprocess
import tempfile

from PIL import Image

import prepare_media as pm

HERE = os.path.dirname(os.path.abspath(__file__))
FPS, FRAMES = 8, 18
ROLES = {"hero": (360, 360, FRAMES), "now": (300, 352, FRAMES), "next": (140, 370, 12), "sheet": (360, 214, 14)}
CLIPS = {  # key -> page title in the real library
    "dive": "Dive Bomber Push-Up", "walkout": "Hand Walkout", "kick": "Kick Through", "sprawl": "Sprawl Straight Down",
    "bridge": "Back Bridge with Hands", "neckrock": "Front Neck Bridge Rock (Hands and Knees)", "neckext": "Lying Neck Extension",
    "couch": "Couch Stretch", "cobra": "Cobra Side-to-Side Shift", "straddle": "Seated Straddle Reach to Toes",
}


def jpeg(im, q):
    buf = io.BytesIO()
    im.save(buf, "JPEG", quality=q, optimize=True)
    return "data:image/jpeg;base64," + base64.b64encode(buf.getvalue()).decode()


def crop_fill(im, w, h, bias=0.42):
    sc = max(w / im.width, h / im.height)
    im = im.resize((max(w, round(im.width * sc)), max(h, round(im.height * sc))), Image.LANCZOS)
    x = (im.width - w) // 2
    y = round((im.height - h) * bias)
    return im.crop((x, y, x + w, y + h))


def main():
    pages = pm.load_pages()
    by_title = {}
    for pid, p in pages.items():
        by_title.setdefault(p["title"], (pid, p))
    out = {}
    for key, title in CLIPS.items():
        pid, page = by_title[title]
        vids = [f for f in page["files"] if f.lower().endswith((".mp4", ".mov", ".m4v"))]
        src = vids[0]
        slug = f"{pid[:8].lower()}-0"
        info = pm.convert(src, slug)
        video = os.path.join(pm.MEDIA, slug + ".mp4")
        with tempfile.TemporaryDirectory() as tmp:
            subprocess.run(["ffmpeg", "-y", "-v", "error", "-ss", "0.2", "-t", f"{FRAMES / FPS + 0.1}", "-i", video, "-vf", f"fps={FPS}",
                            os.path.join(tmp, "f%03d.png")], check=True)
            files = sorted(os.listdir(tmp))[:FRAMES]
            raw = [Image.open(os.path.join(tmp, f)).convert("RGB") for f in files]
        if len(raw) < FRAMES:  # short clip: ping the loop around so the count is full
            raw = (raw * 3)[:FRAMES]
        entry = {"title": title, "w": info["w"], "h": info["h"]}
        for role, (w, h, n) in ROLES.items():
            step = max(1, round(len(raw) / n))
            picks = [raw[(i * step) % len(raw)] for i in range(n)]
            entry[role] = [jpeg(crop_fill(f, w, h), 58 if role != "next" else 52) for f in picks]
            entry[role + "_fps"] = FPS / step
        entry["thumb"] = jpeg(crop_fill(raw[0], 128, 128), 72)
        entry["thumb_big"] = jpeg(crop_fill(raw[0], 220, 220), 70)
        out[key] = entry
        print(key, title, info["w"], info["h"], "frames", len(raw), "KB", sum(len(x) for x in entry["hero"]) // 1024)
    with open(os.path.join(HERE, "clips.json"), "w") as fh:
        json.dump(out, fh)


if __name__ == "__main__":
    main()
