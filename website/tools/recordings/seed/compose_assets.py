#!/usr/bin/env python3
"""Renders the demo images from the app's own artwork.

usage: compose_assets.py <repo-root> <output-dir>
Exercise covers stage the Ranked movement illustrations on a dark set with the orange floor glow
(4:3 for library pages, square with pure-black edges for the workout player and workout cards);
workout covers, the profile banner and the Recovery group reuse genesis/REFERENCE/workout-music-covers.
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

REPO = Path(sys.argv[1])
OUT = Path(sys.argv[2])
ASSETS = REPO / "TimeMaster" / "Resources" / "Assets.xcassets"
COVERS = REPO / "genesis" / "REFERENCE" / "workout-music-covers"
ORANGE = (255, 106, 0)

MOVEMENTS = [
    "standardPushUp", "widePushUp", "closePushUp", "kneePushUp", "pausedPushUp", "tempoPushUp",
    "diamondPushUp", "wallHandstandPushUp", "freestandingHandstandPushUp", "planchePushUp",
    "standardSquat", "wideSquat", "narrowSquat", "pausedSquat",
    "forearmPlank", "highPlank", "leftSidePlank", "rightSidePlank",
]
GROUP_FIGURES = {
    "push": "diamondPushUp",
    "legs": "standardSquat",
    "core": "forearmPlank",
    "skills": "freestandingHandstandPushUp",
}
WORKOUT_COVERS = ["flow", "playlist", "pulse", "recovery"]


def asset(name):
    folder = ASSETS / f"{name}.imageset"
    contents = json.loads((folder / "Contents.json").read_text())
    return Image.open(folder / contents["images"][0]["filename"]).convert("RGBA")


def trimmed(image):
    box = image.getchannel("A").point(lambda alpha: 255 if alpha > 10 else 0).getbbox()
    return image.crop(box) if box else image


def radial(size, inner, outer, center, radius):
    mask = Image.radial_gradient("L").resize((int(radius * 2), int(radius * 2)), Image.BICUBIC)
    full = Image.new("L", size, 255)
    full.paste(mask, (int(center[0] - radius), int(center[1] - radius)))
    return Image.composite(Image.new("RGB", size, outer), Image.new("RGB", size, inner), full)


def stage(figure, size, box, glow_strength=150, outer=(6, 6, 6), reach=0.64):
    width, height = size
    canvas = radial(size, (46, 46, 46), outer, (width / 2, height * 0.44), max(size) * reach)
    figure = trimmed(figure)
    scale = min(box[0] / figure.width, box[1] / figure.height)
    figure = figure.resize((round(figure.width * scale), round(figure.height * scale)), Image.LANCZOS)
    x = (width - figure.width) // 2
    y = (height - figure.height) // 2 + round(height * 0.035)
    floor = y + figure.height
    glow = Image.new("L", size, 0)
    spread = max(figure.width * 0.58, 180)
    ImageDraw.Draw(glow).ellipse((width / 2 - spread, floor - 30, width / 2 + spread, floor + 30), fill=glow_strength)
    canvas = Image.composite(Image.new("RGB", size, ORANGE), canvas, glow.filter(ImageFilter.GaussianBlur(40)))
    shadow = Image.new("L", size, 0)
    shadow.paste(figure.getchannel("A").point(lambda alpha: int(alpha * 0.6)), (x, y + 16))
    canvas = Image.composite(Image.new("RGB", size, (0, 0, 0)), canvas, shadow.filter(ImageFilter.GaussianBlur(18)))
    canvas.paste(figure, (x, y), figure)
    return canvas


def cover_crop(image, size):
    image = image.convert("RGB")
    scale = max(size[0] / image.width, size[1] / image.height)
    image = image.resize((round(image.width * scale), round(image.height * scale)), Image.LANCZOS)
    left = (image.width - size[0]) // 2
    top = (image.height - size[1]) // 2
    return image.crop((left, top, left + size[0], top + size[1]))


def avatar():
    figure = trimmed(asset("RankedHero"))
    bust = figure.crop((0, 0, figure.width, round(figure.height * 0.42)))
    size = (720, 720)
    canvas = radial(size, (255, 128, 40), (24, 8, 0), (360, 300), 560)
    scale = 640 / bust.width
    bust = bust.resize((round(bust.width * scale), round(bust.height * scale)), Image.LANCZOS)
    canvas.paste(bust, ((size[0] - bust.width) // 2, size[1] - bust.height), bust)
    return canvas


def save(image, name):
    image.convert("RGB").save(OUT / name, "JPEG", quality=88, optimize=True)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for movement in MOVEMENTS:
        art = asset(f"Ranked_{movement}")
        save(stage(art, (1200, 900), (760, 470)), f"exercise-{movement}.jpg")
        save(stage(art, (1080, 1080), (900, 640), outer=(0, 0, 0), reach=0.56), f"square-{movement}.jpg")
    for group, movement in GROUP_FIGURES.items():
        save(stage(asset(f"Ranked_{movement}"), (1200, 900), (860, 540), 175), f"group-{group}.jpg")
    save(cover_crop(Image.open(COVERS / "recovery.png"), (1200, 900)), "group-recovery.jpg")
    for name in WORKOUT_COVERS:
        save(cover_crop(Image.open(COVERS / f"{name}.png"), (1080, 1080)), f"cover-{name}.jpg")
    save(cover_crop(Image.open(COVERS / "pulse.png"), (1500, 600)), "profile-banner.jpg")
    save(avatar(), "profile-avatar.jpg")


main()
