#!/usr/bin/env python3
"""Composite a real app screen into the first film frame for the hero posters and the share image."""

import argparse
import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont

SCREEN_BLEED = 1.012
SHARE_SIZE = (1200, 630)
ACCENT = (255, 106, 0)


def composite(frame_path: Path, screen: np.ndarray, quad: list[float]) -> np.ndarray:
    frame = np.array(Image.open(frame_path).convert("RGBA"))
    height, width = frame.shape[:2]
    corners = np.float32(quad).reshape(4, 2)
    center = corners.mean(axis=0)
    corners = center + (corners - center) * SCREEN_BLEED
    source = np.float32([[0, 0], [screen.shape[1], 0], [screen.shape[1], screen.shape[0]], [0, screen.shape[0]]])
    matrix = cv2.getPerspectiveTransform(source, corners)
    under = cv2.warpPerspective(screen, matrix, (width, height), flags=cv2.INTER_LANCZOS4).astype(np.float32)
    alpha = frame[..., 3:4].astype(np.float32) / 255.0
    return (frame[..., :3].astype(np.float32) * alpha + under * (1.0 - alpha)).astype(np.uint8)


def share_image(poster: np.ndarray, font_path: Path, out_path: Path) -> None:
    image = Image.fromarray(poster)
    scale = SHARE_SIZE[0] / image.width
    image = image.resize((SHARE_SIZE[0], round(image.height * scale)), Image.LANCZOS)
    top = (image.height - SHARE_SIZE[1]) // 2
    image = image.crop((0, top, SHARE_SIZE[0], top + SHARE_SIZE[1]))
    draw = ImageDraw.Draw(image)
    font = ImageFont.truetype(str(font_path), 66)
    lines = [[("A Fitness", "white")], [("Everything", ACCENT)], [("App You", "white")], [("Dreamed Of", "white")]]
    y = 150
    for line in lines:
        x = 690
        for text, color in line:
            draw.text((x, y), text, font=font, fill=color)
            x += draw.textlength(text, font=font)
        y += 76
    image.convert("RGB").save(out_path, "JPEG", quality=88, optimize=True, progressive=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("screen", type=Path, help="app screen image, e.g. a recording poster")
    parser.add_argument("--frames", type=Path, default=Path("public/media/film"))
    parser.add_argument("--manifest", type=Path, default=Path("src/content/film.json"))
    parser.add_argument("--font", type=Path, default=Path("../TimeMaster/Resources/Fonts/Inter-Black.ttf"))
    parser.add_argument("--share", type=Path, default=Path("src/app/opengraph-image.jpg"))
    args = parser.parse_args()

    manifest = json.loads(args.manifest.read_text())
    screen = np.array(Image.open(args.screen).convert("RGB"))
    posters = {}
    for variant in ("desktop", "mobile"):
        poster = composite(args.frames / variant / "0000.webp", screen, manifest[variant]["quads"][0])
        Image.fromarray(poster).save(args.frames / f"poster-{variant}.webp", "WEBP", quality=82, method=6)
        posters[variant] = poster
    share_image(posters["desktop"], args.font, args.share)
    print("posters and share image written")


if __name__ == "__main__":
    main()
