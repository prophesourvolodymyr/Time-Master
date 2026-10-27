#!/usr/bin/env python3
"""Turn the generated hero film into web frame sequences with a transparent phone screen.

Every frame gets its chroma-green screen keyed to a soft transparent hole (marble fingers that
overlap the screen stay opaque), green spill removed from the marble, near-black crushed to true
black, and the four screen corners measured so the site can place app recordings in perspective.
"""

from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

DESKTOP_WIDTH = 1600
MOBILE_ASPECT = 9 / 16
MOBILE_CENTER = (0.46, 0.5)
SMOOTHING_RADIUS = 2


def probe(path: Path) -> tuple[int, int, float]:
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height,r_frame_rate", "-of", "json", str(path)],
        capture_output=True, check=True, text=True,
    ).stdout
    stream = json.loads(out)["streams"][0]
    num, den = stream["r_frame_rate"].split("/")
    return stream["width"], stream["height"], float(num) / float(den)


def read_frames(path: Path, width: int, height: int):
    proc = subprocess.Popen(["ffmpeg", "-v", "error", "-i", str(path), "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], stdout=subprocess.PIPE)
    size = width * height * 3
    while True:
        chunk = proc.stdout.read(size)
        if len(chunk) < size:
            break
        yield np.frombuffer(chunk, np.uint8).reshape(height, width, 3)
    proc.wait()


def key_screen(rgb: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    f = rgb.astype(np.float32)
    dominance = f[..., 1] - np.maximum(f[..., 0], f[..., 2])
    hard = ((dominance > 60) & (f[..., 1] > 110)).astype(np.uint8)
    count, labels, stats, _ = cv2.connectedComponentsWithStats(hard, connectivity=8)
    if count <= 1:
        raise RuntimeError("no green screen found")
    screen = (labels == 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))).astype(np.uint8)
    near = cv2.dilate(screen, np.ones((11, 11), np.uint8)).astype(np.float32)
    key = np.clip((dominance - 16.0) / (64.0 - 16.0), 0.0, 1.0) * near
    return screen, key


def side_lines(hull_mask: np.ndarray) -> list[np.ndarray]:
    contours, _ = cv2.findContours(hull_mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
    contour = max(contours, key=cv2.contourArea).reshape(-1, 2).astype(np.float32)
    perimeter = cv2.arcLength(contour.reshape(-1, 1, 2), True)
    approx = None
    for factor in np.linspace(0.01, 0.12, 45):
        candidate = cv2.approxPolyDP(contour.reshape(-1, 1, 2), factor * perimeter, True)
        if len(candidate) == 4:
            approx = candidate.reshape(4, 2).astype(np.float32)
            break
    if approx is None:
        raise RuntimeError("screen outline is not quadrilateral")
    points = contour.astype(np.float64)
    lines = []
    for index in range(4):
        start, end = approx[index].astype(np.float64), approx[(index + 1) % 4].astype(np.float64)
        direction = end - start
        length = float(np.linalg.norm(direction))
        unit = direction / length
        normal = np.array([-unit[1], unit[0]])
        rel = points - start
        along = np.einsum("ij,j->i", rel, unit)
        middle = (along > 0.2 * length) & (along < 0.8 * length)
        coarse = contour[middle & (np.abs(np.einsum("ij,j->i", rel, normal)) < max(12.0, 0.1 * length))]
        vx, vy, x0, y0 = cv2.fitLine(coarse, cv2.DIST_HUBER, 0, 0.01, 0.01).ravel().astype(np.float64)
        fitted_normal = np.array([-vy, vx])
        fine = contour[middle & (np.abs(np.einsum("ij,j->i", points - np.array([x0, y0]), fitted_normal)) < 2.5)]
        if len(fine) >= 12:
            vx, vy, x0, y0 = cv2.fitLine(fine, cv2.DIST_HUBER, 0, 0.01, 0.01).ravel()
        lines.append(np.array([x0, y0, vx, vy], np.float64))
    return lines


def intersect(a: np.ndarray, b: np.ndarray) -> np.ndarray:
    matrix = np.array([[a[2], -b[2]], [a[3], -b[3]]])
    t = np.linalg.solve(matrix, np.array([b[0] - a[0], b[1] - a[1]]))[0]
    return np.array([a[0] + t * a[2], a[1] + t * a[3]])


def screen_corners(screen: np.ndarray) -> np.ndarray:
    contours, _ = cv2.findContours(screen, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
    hull = cv2.convexHull(max(contours, key=cv2.contourArea))
    hull_mask = np.zeros_like(screen)
    cv2.fillPoly(hull_mask, [hull], 1)
    lines = side_lines(hull_mask)
    corners = np.array([intersect(lines[i], lines[(i + 1) % 4]) for i in range(4)])
    center = corners.mean(axis=0)
    angles = np.arctan2(corners[:, 1] - center[1], corners[:, 0] - center[0])
    ordered = corners[np.argsort(angles)]
    top_left = int(np.argmin(ordered.sum(axis=1)))
    return np.roll(ordered, -top_left, axis=0)


def finish_pixels(rgb: np.ndarray, key: np.ndarray, screen: np.ndarray) -> np.ndarray:
    f = rgb.astype(np.float32)
    spill_zone = cv2.dilate(screen, np.ones((61, 61), np.uint8)).astype(bool)
    limit = np.maximum(f[..., 0], f[..., 2])
    green = f[..., 1]
    f[..., 1] = np.where(spill_zone & (green > limit), limit, green)
    f = np.clip((f - 3.0) * (255.0 / 252.0), 0, 255)
    alpha = (1.0 - key) * 255.0
    return np.dstack([f, alpha]).astype(np.uint8)


def smooth(quads: np.ndarray, radius: int) -> np.ndarray:
    result = quads.copy()
    for index in range(len(quads)):
        lo, hi = max(0, index - radius), min(len(quads), index + radius + 1)
        result[index] = quads[lo:hi].mean(axis=0)
    return result


def save_webp(rgba: np.ndarray, path: Path, quality: int) -> None:
    Image.fromarray(rgba).save(path, "WEBP", quality=quality, alpha_quality=90, method=6)


def mobile_window(width: int, height: int, progress: float) -> int:
    crop = int(round(height * MOBILE_ASPECT))
    eased = progress * progress * (3 - 2 * progress)
    center = (MOBILE_CENTER[0] + (MOBILE_CENTER[1] - MOBILE_CENTER[0]) * eased) * width
    return int(np.clip(round(center - crop / 2), 0, width - crop))


def read_depth(path: Path, width: int, height: int, fps: float, total: int):
    proc = subprocess.Popen(
        ["ffmpeg", "-v", "error", "-i", str(path), "-vf", f"fps={fps},scale={width}:{height}", "-frames:v", str(total), "-f", "rawvideo", "-pix_fmt", "gray", "-"],
        stdout=subprocess.PIPE,
    )
    size = width * height
    while True:
        chunk = proc.stdout.read(size)
        if len(chunk) < size:
            break
        yield np.frombuffer(chunk, np.uint8).reshape(height, width)
    proc.wait()


def export_depth(depth_video: Path, out_dir: Path, source: tuple[int, int, float], desktop_height: int, mobile_offsets: list[int], quality: int) -> None:
    width, height, fps = source
    mobile_width = int(round(height * MOBILE_ASPECT))
    count = 0
    for index, gray in enumerate(read_depth(depth_video, width, height, fps, len(mobile_offsets))):
        smooth_depth = cv2.GaussianBlur(gray, (0, 0), 2.0)
        desktop = cv2.resize(smooth_depth, (DESKTOP_WIDTH // 2, desktop_height // 2), interpolation=cv2.INTER_AREA)
        Image.fromarray(desktop).save(out_dir / "desktop-depth" / f"{index:04d}.webp", "WEBP", quality=quality, method=6)
        offset = mobile_offsets[index]
        mobile = cv2.resize(smooth_depth[:, offset:offset + mobile_width], (mobile_width // 2, height // 2), interpolation=cv2.INTER_AREA)
        Image.fromarray(mobile).save(out_dir / "mobile-depth" / f"{index:04d}.webp", "WEBP", quality=quality, method=6)
        count += 1
    if count != len(mobile_offsets):
        raise RuntimeError(f"depth video produced {count} frames, expected {len(mobile_offsets)}")


def run(source: Path, out_dir: Path, manifest_path: Path, quality: int, depth: Path | None) -> None:
    width, height, fps = probe(source)
    desktop_height = int(round(height * DESKTOP_WIDTH / width / 2) * 2)
    mobile_width = int(round(height * MOBILE_ASPECT))
    for variant in ("desktop", "mobile", "desktop-depth", "mobile-depth"):
        (out_dir / variant).mkdir(parents=True, exist_ok=True)
        for old in (out_dir / variant).glob("*.webp"):
            old.unlink()

    raw_quads = [screen_corners(key_screen(rgb)[0]) for rgb in read_frames(source, width, height)]
    quads = smooth(np.array(raw_quads), SMOOTHING_RADIUS)
    total = len(quads)

    scale = DESKTOP_WIDTH / width
    mobile_offsets = []
    for index, rgb in enumerate(read_frames(source, width, height)):
        screen, key = key_screen(rgb)
        rgba = finish_pixels(rgb, key, screen)
        desktop = cv2.resize(rgba, (DESKTOP_WIDTH, desktop_height), interpolation=cv2.INTER_AREA)
        save_webp(desktop, out_dir / "desktop" / f"{index:04d}.webp", quality)
        offset = mobile_window(width, height, index / max(1, total - 1))
        mobile_offsets.append(offset)
        save_webp(rgba[:, offset:offset + mobile_width], out_dir / "mobile" / f"{index:04d}.webp", quality)

    def flat(points: np.ndarray, factor: float, dx: float = 0.0) -> list[float]:
        return [round(float(value), 1) for corner in points for value in ((corner[0] - dx) * factor, corner[1] * factor)]

    manifest = {
        "fps": round(fps, 3),
        "frameCount": total,
        "depth": depth is not None,
        "desktop": {
            "width": DESKTOP_WIDTH,
            "height": desktop_height,
            "quads": [flat(q, scale) for q in quads],
        },
        "mobile": {
            "width": mobile_width,
            "height": height,
            "quads": [flat(q, 1.0, mobile_offsets[i]) for i, q in enumerate(quads)],
        },
    }
    manifest_path.write_text(json.dumps(manifest, separators=(",", ":")))
    if depth:
        export_depth(depth, out_dir, (width, height, fps), desktop_height, mobile_offsets, quality)
    print(f"{total} frames, desktop {DESKTOP_WIDTH}x{desktop_height}, mobile {mobile_width}x{height}, depth {'yes' if depth else 'no'}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("out_dir", type=Path)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--quality", type=int, default=78)
    parser.add_argument("--depth", type=Path, help="depth video aligned with the source film")
    args = parser.parse_args()
    run(args.source, args.out_dir, args.manifest, args.quality, args.depth)


if __name__ == "__main__":
    main()
