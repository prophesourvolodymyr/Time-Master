#!/usr/bin/env python3
"""Builds the Social chapter arena layers from the fgen stills in genesis/REFERENCE/website/social.

Real marks only: Instagram, TikTok, YouTube, X and Facebook come from simple-icons (CC0, trademarks of
their owners) and the M from public/brand/tmax-mark.svg. They are rasterized with resvg, warped onto
the blank stone faces with a homography and carved into the stone with relief shading, so the stone's
own light, veining and grain stay on top. The Ranked tier badges are exported unchanged from the app's asset catalog.
Run from website/: python3 tools/social/composite.py (add --preview to only render carving previews to the temp dir).
"""

from __future__ import annotations

import re
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path

import cv2
import numpy as np

WEBSITE = Path(__file__).resolve().parents[2]
SOURCE = WEBSITE.parent / "genesis/REFERENCE/website/social"
CANDIDATES = SOURCE / "candidates"
BUILD = SOURCE / "build"
OUT = WEBSITE / "public/media/chapters/social"
MANIFEST = WEBSITE / "src/sections/chapters/social/arena-assets.ts"
ICONS = WEBSITE / "node_modules/simple-icons/icons"
TMAX_MARK = WEBSITE / "public/brand/tmax-mark.svg"
APP_ASSETS = WEBSITE.parent / "TimeMaster/Resources/Assets.xcassets"
TIERS = ("iron", "bronze", "silver", "gold", "diamond", "champion")
TIER_WIDTHS = (192, 96)
FACE = 1024


@dataclass(frozen=True)
class Carving:
    quad: tuple[tuple[float, float], ...]
    light: tuple[float, float, float]
    fit: float = 0.56
    center: tuple[float, float] = (0.5, 0.5)
    depth: float = 7.0
    bevel: float = 15.0
    tone: float = 0.8
    shadow: float = 0.5
    engraved: bool = False


@dataclass(frozen=True)
class Layer:
    id: str
    source: str
    widths: tuple[int, ...]
    mark: str | None = None
    carving: Carving | None = None
    bottom_fade: float = 0.0
    solid: float = 7.0
    glow: float = 42.0
    close: int = 21


LIGHT_FROM_RIGHT = (0.62, -0.42, 0.66)
LIGHT_FROM_LEFT = (-0.62, -0.42, 0.66)

LAYERS = (
    Layer("arena", "arena", (1672, 960)),
    Layer(
        "monument",
        "monument",
        (1024, 560),
        mark="tmax",
        carving=Carving(quad=((136, 398), (883, 398), (883, 1128), (136, 1128)), light=(-0.5, -0.55, 0.67), fit=0.62, depth=4.0, bevel=7.0, tone=1.0, shadow=0.2),
        solid=30.0,
        glow=255.0,
        close=5,
    ),
    Layer(
        "spectator-instagram",
        "spectator-left-a",
        (1024, 560),
        mark="instagram",
        carving=Carving(quad=((299, 205), (876, 416), (907, 1182), (302, 1140)), light=LIGHT_FROM_RIGHT),
        bottom_fade=0.1,
    ),
    Layer(
        "spectator-tiktok",
        "spectator-left-c",
        (1024, 560),
        mark="tiktok",
        carving=Carving(quad=((258, 164), (836, 326), (964, 1030), (300, 924)), light=LIGHT_FROM_RIGHT, center=(0.5, 0.5)),
        bottom_fade=0.16,
    ),
    Layer(
        "spectator-youtube",
        "spectator-right-a",
        (1024, 560),
        mark="youtube",
        carving=Carving(quad=((204, 363), (765, 197), (765, 1135), (112, 1166)), light=LIGHT_FROM_LEFT, fit=0.6),
        bottom_fade=0.1,
    ),
    Layer(
        "spectator-x",
        "spectator-right-c",
        (1024, 560),
        mark="x",
        carving=Carving(quad=((232, 302), (836, 138), (836, 928), (92, 964)), light=LIGHT_FROM_LEFT, fit=0.5),
        bottom_fade=0.16,
    ),
    Layer(
        "spectator-facebook",
        "spectator-left-b",
        (900, 480),
        mark="facebook",
        carving=Carving(quad=((320, 76), (821, 340), (910, 1024), (294, 787)), light=LIGHT_FROM_RIGHT, fit=0.56),
        bottom_fade=0.2,
    ),
    Layer(
        "tablet-tiktok",
        "tablet-front",
        (1024, 640),
        mark="tiktok",
        carving=Carving(quad=((149, 134), (1105, 134), (1105, 1116), (149, 1116)), light=(0.55, -0.5, 0.67), fit=0.56),
    ),
    Layer("dust", "dust", (1280, 720)),
)


def run(*command: str) -> None:
    subprocess.run(command, check=True, capture_output=True)


def mark_svg(name: str) -> str:
    if name == "tmax":
        return TMAX_MARK.read_text()
    path = re.search(r' d="([^"]+)"', (ICONS / f"{name}.svg").read_text())
    if path is None:
        raise ValueError(f"simple-icons/{name}.svg has no path")
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path fill="#fff" d="{path.group(1)}"/></svg>'


def mark_alpha(name: str, width: int = 1600) -> np.ndarray:
    with tempfile.TemporaryDirectory() as directory:
        svg = Path(directory) / "mark.svg"
        png = Path(directory) / "mark.png"
        svg.write_text(mark_svg(name))
        run("resvg", "-w", str(width), str(svg), str(png))
        rgba = cv2.imread(str(png), cv2.IMREAD_UNCHANGED)
    return rgba[..., 3].astype(np.float32) / 255


def place(alpha: np.ndarray, fit: float, center: tuple[float, float]) -> np.ndarray:
    height, width = alpha.shape
    scale = fit * FACE / max(height, width)
    size = (max(1, round(width * scale)), max(1, round(height * scale)))
    resized = cv2.resize(alpha, size, interpolation=cv2.INTER_AREA)
    canvas = np.zeros((FACE, FACE), np.float32)
    left = round(center[0] * FACE - size[0] / 2)
    top = round(center[1] * FACE - size[1] / 2)
    canvas[top : top + size[1], left : left + size[0]] = resized
    return canvas


def relief(mask: np.ndarray, carving: Carving) -> tuple[np.ndarray, np.ndarray]:
    light = np.array(carving.light, np.float32)
    light /= np.linalg.norm(light)
    solid = (mask > 0.5).astype(np.uint8)
    inside = cv2.distanceTransform(solid, cv2.DIST_L2, 5)
    height = np.clip(inside / carving.bevel, 0, 1)
    height = height * height * (3 - 2 * height)
    height = cv2.GaussianBlur(height, (0, 0), carving.bevel * 0.2) * (-carving.depth if carving.engraved else carving.depth)
    gy, gx = np.gradient(height)
    normal = np.dstack([-gx, -gy, np.ones_like(gx)])
    normal /= np.linalg.norm(normal, axis=2, keepdims=True)
    lambert = np.clip(normal @ light, 0, None) / light[2]
    halfway = light + np.array([0, 0, 1], np.float32)
    halfway /= np.linalg.norm(halfway)
    slope = 1 - normal[..., 2]
    specular = np.clip(normal @ halfway, 0, 1) ** 24 * np.clip(slope * 6, 0, 1) * 0.55
    offset = -light[:2] / np.linalg.norm(light[:2]) * carving.bevel * 0.9
    shifted = cv2.warpAffine(mask, np.float32([[1, 0, offset[0]], [0, 1, offset[1]]]), (FACE, FACE))
    shifted = cv2.GaussianBlur(shifted, (0, 0), carving.bevel * 0.6)
    cast = mask * (1 - shifted) if carving.engraved else shifted * (1 - mask)
    occlusion = (1 - cv2.GaussianBlur(1 - mask, (0, 0), carving.bevel * 0.5)) * mask if carving.engraved else cv2.GaussianBlur(mask, (0, 0), carving.bevel * 0.5) * (1 - mask)
    tone = 1 + (carving.tone - 1) * mask
    multiply = lambert * (1 - carving.shadow * cast) * (1 - 0.25 * occlusion) * tone
    return multiply.astype(np.float32), specular.astype(np.float32)


def face_homography(carving: Carving) -> np.ndarray:
    square = np.float32([[0, 0], [FACE, 0], [FACE, FACE], [0, FACE]])
    return cv2.getPerspectiveTransform(square, np.float32(carving.quad))


def warp(image: np.ndarray, homography: np.ndarray, size: tuple[int, int], border: float) -> np.ndarray:
    return cv2.warpPerspective(image, homography, size, flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=border)


def carve(rgb: np.ndarray, name: str, carving: Carving) -> np.ndarray:
    size = (rgb.shape[1], rgb.shape[0])
    homography = face_homography(carving)
    mask = place(mark_alpha(name), carving.fit, carving.center)
    multiply, specular = relief(mask, carving)
    multiply = warp(multiply, homography, size, 1.0)[..., None]
    specular = warp(specular, homography, size, 0.0)[..., None]
    base = rgb.astype(np.float32)
    brightness = np.clip(base.max(axis=2, keepdims=True) / 255, 0.15, 1)
    lit = base * multiply + specular * 255 * brightness * np.float32([0.92, 0.96, 1.0])
    return np.clip(lit, 0, 255), mark_box(warp(mask, homography, size, 0.0))


def inlay(rgb: np.ndarray, carving: Carving, texture_source: np.ndarray) -> np.ndarray:
    size = (rgb.shape[1], rgb.shape[0])
    homography = face_homography(carving)
    mask = place(mark_alpha("tmax"), carving.fit, carving.center)
    stone = cv2.resize(texture_source, (FACE, FACE), interpolation=cv2.INTER_AREA).astype(np.float32)
    grey = stone.mean(axis=2, keepdims=True)
    stone = grey + (stone - grey) * 0.35
    ys, xs = np.mgrid[0:FACE, 0:FACE].astype(np.float32) / FACE
    falloff = (1.08 - 0.42 * (0.55 * xs + 0.45 * ys))[..., None]
    stone = np.clip(stone * falloff, 0, 255)
    multiply, specular = relief(mask, carving)
    seam = cv2.GaussianBlur(mask, (0, 0), 1.6) - mask
    stone = stone * multiply[..., None] + specular[..., None] * 255
    coverage = warp(mask, homography, size, 0.0)[..., None]
    stone = warp(stone, homography, size, 0.0)
    shadow = warp(np.abs(seam), homography, size, 0.0)[..., None]
    base = rgb.astype(np.float32) * (1 - 0.6 * shadow)
    return np.clip(base * (1 - coverage) + stone * coverage, 0, 255), mark_box(coverage[..., 0])


def mark_box(coverage: np.ndarray) -> tuple[int, int, int, int]:
    ys, xs = np.where(coverage > 0.5)
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def luminance(rgb: np.ndarray) -> np.ndarray:
    return rgb[..., 0] * 0.2126 + rgb[..., 1] * 0.7152 + rgb[..., 2] * 0.0722


def fill_holes(mask: np.ndarray) -> np.ndarray:
    padded = cv2.copyMakeBorder(mask, 1, 1, 1, 1, cv2.BORDER_CONSTANT, value=0)
    flood = padded.copy()
    cv2.floodFill(flood, np.zeros((padded.shape[0] + 2, padded.shape[1] + 2), np.uint8), (0, 0), 255)
    return (padded | cv2.bitwise_not(flood))[1:-1, 1:-1]


def silhouette(rgb: np.ndarray, threshold: float, close: int) -> np.ndarray:
    solid = (luminance(rgb) > threshold).astype(np.uint8) * 255
    solid = cv2.morphologyEx(solid, cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (close, close)))
    count, labels, stats, _ = cv2.connectedComponentsWithStats(solid)
    if count > 1:
        largest = stats[1:, cv2.CC_STAT_AREA].max()
        keep = [index for index in range(1, count) if stats[index, cv2.CC_STAT_AREA] > 0.05 * largest]
        solid = np.isin(labels, keep).astype(np.uint8) * 255
    return fill_holes(solid)


def cut_out(rgb: np.ndarray, layer: Layer) -> tuple[np.ndarray, np.ndarray]:
    shape = silhouette(rgb, layer.solid, layer.close)
    core = cv2.erode(shape, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (7, 7))).astype(np.float32) / 255
    core = cv2.GaussianBlur(core, (0, 0), 1.2)
    soft = np.clip(rgb.max(axis=2) / layer.glow, 0, 1)
    if layer.glow < 255:
        soft *= cv2.dilate(shape, np.ones((5, 5), np.uint8)) > 0
    alpha = np.maximum(core, soft)
    bottom_fade = layer.bottom_fade
    if bottom_fade > 0:
        rows = np.where(shape.max(axis=1) > 0)[0]
        top, bottom = rows[0], rows[-1]
        span = (bottom - top) * bottom_fade
        y = np.arange(rgb.shape[0], dtype=np.float32)
        fade = np.clip((bottom - y) / span, 0, 1)
        alpha *= (fade * fade * (3 - 2 * fade))[:, None]
    color = np.where(alpha[..., None] > 0.004, rgb / np.maximum(alpha[..., None], 0.004), 0)
    return np.clip(color, 0, 255), alpha


def seal_edges(rgb: np.ndarray) -> np.ndarray:
    height, width = rgb.shape[:2]
    y, x = np.mgrid[0:height, 0:width].astype(np.float32)
    u = np.abs(x / (width - 1) * 2 - 1)
    v = y / (height - 1)
    side = np.clip((1 - u) / 0.16, 0, 1)
    floor = np.clip((1 - v) / 0.12, 0, 1)
    seal = (side * side * (3 - 2 * side)) * (floor * floor * (3 - 2 * floor))
    black_point = 5.0
    lifted = np.clip((rgb - black_point) * (255 / (255 - black_point)), 0, 255)
    return lifted * seal[..., None]


def crop_to_alpha(rgb: np.ndarray, alpha: np.ndarray, margin: int = 6) -> tuple[np.ndarray, np.ndarray, tuple[int, int]]:
    ys, xs = np.where(alpha > 0.01)
    top, bottom = max(0, ys.min() - margin), min(alpha.shape[0], ys.max() + margin + 1)
    left, right = max(0, xs.min() - margin), min(alpha.shape[1], xs.max() + margin + 1)
    return rgb[top:bottom, left:right], alpha[top:bottom, left:right], (int(left), int(top))


def encode(image: np.ndarray, stem: Path, alpha: bool) -> None:
    with tempfile.TemporaryDirectory() as directory:
        png = Path(directory) / "layer.png"
        cv2.imwrite(str(png), image)
        webp_args = ["-q", "80", "-m", "6", "-sharp_yuv", "-metadata", "none"]
        avif_args = ["-q", "62", "-s", "4", "-j", "all", "--ignore-exif", "--ignore-xmp"]
        if alpha:
            webp_args += ["-alpha_q", "85", "-exact"]
            avif_args += ["--qalpha", "80"]
        run("cwebp", *webp_args, str(png), "-o", f"{stem}.webp")
        run("avifenc", *avif_args, str(png), f"{stem}.avif")


def export(layer: Layer, rgb: np.ndarray, alpha: np.ndarray | None, mark: dict | None = None) -> dict:
    BUILD.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    bgr = cv2.cvtColor(np.round(rgb).astype(np.uint8), cv2.COLOR_RGB2BGR)
    master = bgr if alpha is None else np.dstack([bgr, np.round(alpha * 255).astype(np.uint8)])
    cv2.imwrite(str(BUILD / f"{layer.id}.png"), master)
    height, width = master.shape[:2]
    widths = [min(target, width) for target in layer.widths]
    for target in widths:
        scaled = master if target == width else cv2.resize(master, (target, round(height * target / width)), interpolation=cv2.INTER_AREA)
        encode(scaled, OUT / f"{layer.id}-{target}", alpha is not None)
    return {"id": layer.id, "width": width, "height": height, "widths": widths, "mark": mark}


def export_tiers() -> None:
    for tier in TIERS:
        rgba = cv2.imread(str(APP_ASSETS / f"RankedBadge_{tier}.imageset/art.png"), cv2.IMREAD_UNCHANGED)
        for target in TIER_WIDTHS:
            encode(cv2.resize(rgba, (target, target), interpolation=cv2.INTER_AREA), OUT / f"tier-{tier}-{target}", True)


def build_layer(layer: Layer, texture: np.ndarray) -> dict:
    bgr = cv2.imread(str(CANDIDATES / f"{layer.source}.png"), cv2.IMREAD_COLOR)
    rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB).astype(np.float32)
    if layer.id == "arena":
        return export(layer, seal_edges(rgb), None)
    if layer.id == "dust":
        return export(layer, seal_edges(rgb) * 0.9, None)
    box = None
    if layer.mark == "tmax" and layer.carving is not None:
        rgb, box = inlay(rgb, layer.carving, texture)
    elif layer.mark is not None and layer.carving is not None:
        rgb, box = carve(rgb, layer.mark, layer.carving)
    color, alpha = cut_out(rgb, layer)
    color, alpha, (left, top) = crop_to_alpha(color, alpha)
    height, width = alpha.shape
    mark = None
    if box is not None:
        mark = {
            "x": round((box[0] - left) / width, 4),
            "y": round((box[1] - top) / height, 4),
            "width": round((box[2] - box[0]) / width, 4),
            "height": round((box[3] - box[1]) / height, 4),
        }
    return export(layer, color, alpha, mark)


def write_manifest(entries: list[dict]) -> None:
    ids = "\n".join(f'  | "{entry["id"]}"' for entry in entries)
    rows = "\n".join(f'  "{entry["id"]}": {asset_literal(entry)},' for entry in entries)
    MANIFEST.write_text(
        f"export type ArenaAssetId =\n{ids};\n\n"
        "export type MarkBox = { x: number; y: number; width: number; height: number };\n\n"
        "export type ArenaAsset = { width: number; height: number; widths: readonly number[]; mark?: MarkBox };\n\n"
        f"export const arenaAssets: Record<ArenaAssetId, ArenaAsset> = {{\n{rows}\n}};\n"
    )


def asset_literal(entry: dict) -> str:
    fields = [f'width: {entry["width"]}', f'height: {entry["height"]}', f'widths: [{", ".join(map(str, entry["widths"]))}]']
    if entry["mark"] is not None:
        mark = entry["mark"]
        fields.append(f'mark: {{ x: {mark["x"]}, y: {mark["y"]}, width: {mark["width"]}, height: {mark["height"]} }}')
    return "{ " + ", ".join(fields) + " }"


def preview(texture: np.ndarray) -> None:
    for layer in LAYERS:
        if layer.carving is None:
            continue
        rgb = cv2.cvtColor(cv2.imread(str(CANDIDATES / f"{layer.source}.png")), cv2.COLOR_BGR2RGB).astype(np.float32)
        rgb, _ = inlay(rgb, layer.carving, texture) if layer.mark == "tmax" else carve(rgb, layer.mark or "", layer.carving)
        cv2.imwrite(str(Path(tempfile.gettempdir()) / f"social-preview-{layer.id}.jpg"), cv2.cvtColor(np.round(rgb).astype(np.uint8), cv2.COLOR_RGB2BGR))


def main() -> None:
    tablet = cv2.cvtColor(cv2.imread(str(CANDIDATES / "tablet-front.png")), cv2.COLOR_BGR2RGB)
    texture = tablet[300:950, 300:950]
    if "--preview" in sys.argv:
        preview(texture)
        return
    if OUT.exists():
        shutil.rmtree(OUT)
    entries = [build_layer(layer, texture) for layer in LAYERS]
    export_tiers()
    write_manifest(entries)
    for entry in entries:
        print(entry)


if __name__ == "__main__":
    main()
