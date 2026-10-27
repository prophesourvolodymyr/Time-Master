#!/usr/bin/env python3
"""Lock the highlighted word of every book page to the center of the frame for the page-change edit."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

SETS = {"desktop": (1600, 900), "mobile": (864, 1536)}
MAX_EQUALIZING_ZOOM = 1.25
QUALITY = 80


def highlight_box(rgb: np.ndarray) -> tuple[int, int, int, int]:
    hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV)
    hue, saturation, value = hsv[..., 0], hsv[..., 1], hsv[..., 2]
    mask = ((hue >= 4) & (hue <= 24) & (saturation >= 110) & (value >= 140)).astype(np.uint8)
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, np.ones((11, 11), np.uint8))
    count, _, stats, _ = cv2.connectedComponentsWithStats(mask, connectivity=8)
    if count <= 1:
        raise RuntimeError("no highlighter stroke found")
    largest = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
    x, y, width, height = (int(value) for value in stats[largest, :4])
    return x, y, width, height


def placement(rgb: np.ndarray, size: tuple[int, int]) -> tuple[float, float, int, float]:
    x, y, width, height = highlight_box(rgb)
    center_x, center_y = x + width / 2, y + height / 2
    rows, columns = rgb.shape[:2]
    inside = max((size[0] / 2) / min(center_x, columns - center_x), (size[1] / 2) / min(center_y, rows - center_y)) * 1.005
    return center_x, center_y, height, inside


def lock(rgb: np.ndarray, center_x: float, center_y: float, scale: float, size: tuple[int, int]) -> Image.Image:
    matrix = np.float32([[scale, 0, size[0] / 2 - center_x * scale], [0, scale, size[1] / 2 - center_y * scale]])
    locked = cv2.warpAffine(rgb, matrix, size, flags=cv2.INTER_LANCZOS4, borderMode=cv2.BORDER_REPLICATE)
    soft = cv2.GaussianBlur(locked, (0, 0), 1.0)
    return Image.fromarray(cv2.addWeighted(locked, 1.35, soft, -0.35, 0))


def export(name: str, sources: list[Path], out: Path) -> list[str]:
    size = SETS[name]
    folder = out / name
    folder.mkdir(parents=True, exist_ok=True)
    for old in folder.glob("page-*.webp"):
        old.unlink()
    images = [np.array(Image.open(source).convert("RGB")) for source in sources]
    placements = [placement(rgb, size) for rgb in images]
    target = float(np.median([height * inside for _, _, height, inside in placements]))
    urls = []
    for index, (rgb, (center_x, center_y, height, inside)) in enumerate(zip(images, placements), start=1):
        scale = max(inside, min(target / height, inside * MAX_EQUALIZING_ZOOM))
        page = f"page-{index:02d}.webp"
        lock(rgb, center_x, center_y, scale, size).save(folder / page, "WEBP", quality=QUALITY, method=6)
        urls.append(f"/media/edit/{name}/{page}")
        print(f"{name} {page}: zoom {scale:.2f}, word {height * scale / size[1]:.1%} of the frame")
    return urls


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("order", type=Path, help='JSON file {"desktop": [photos], "mobile": [photos]} in playback order')
    parser.add_argument("--out", type=Path, default=Path("public/media/edit"))
    parser.add_argument("--manifest", type=Path, default=Path("src/content/edit-pages.ts"))
    args = parser.parse_args()

    order = json.loads(args.order.read_text())
    if len(order["desktop"]) != len(order["mobile"]):
        raise SystemExit("desktop and mobile need the same number of pages")
    for old in args.out.glob("page-*.webp"):
        old.unlink()
    desktop = export("desktop", [Path(path) for path in order["desktop"]], args.out)
    mobile = export("mobile", [Path(path) for path in order["mobile"]], args.out)
    pages = [{"desktop": d, "mobile": m} for d, m in zip(desktop, mobile)]
    args.manifest.write_text(
        "export type EditPage = { desktop: string; mobile: string };\n\nexport const editPages: readonly EditPage[] = %s;\n"
        % json.dumps(pages, indent=2).replace('"desktop"', "desktop").replace('"mobile"', "mobile").replace('"\n  }', '",\n  }').replace("}\n]", "},\n]")
    )
    print(f"{len(pages)} pages locked")


if __name__ == "__main__":
    main()
