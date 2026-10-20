import argparse
import json
import shutil
import subprocess
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage


HERE = Path(__file__).resolve().parent
REFERENCE = HERE.parents[1] / "genesis/REFERENCE/ribbon-font/individual-m"
CONSTRUCTIONS = json.loads((REFERENCE / "glyph-calculations.json").read_text())["glyphs"]


def _letter_frame(letter, canvas):
    baseline = canvas["baseline_y"]
    if letter.isupper() or letter in "bdfhkl":
        return canvas["cap_line_y"], baseline
    if letter in "gjpqy":
        return baseline - canvas["lowercase_x_height"], canvas["descender_limit_y"]
    if letter == "t":
        return baseline - canvas["short_ascender_height"], baseline
    return baseline - canvas["lowercase_x_height"], baseline


def clean_letter(image):
    grayscale = np.asarray(image.convert("L"))
    labels, count = ndimage.label(grayscale >= 220)
    if not count:
        raise ValueError("The generated image contains no white glyph.")
    areas = np.bincount(labels.ravel())
    keep = areas >= areas[1:].max() * 0.1
    keep[0] = False
    mask = keep[labels]
    softened = ndimage.gaussian_filter(mask.astype(np.float32), sigma=1)
    antialiased = np.clip((softened - 0.25) * 2, 0, 1)
    return Image.fromarray(np.rint(antialiased * 255).astype("uint8")).convert("RGB")


def _descender_body_bottom(grayscale, letter):
    mask = np.asarray(grayscale) >= 128
    if letter in "gpq":
        holes, _ = ndimage.label(ndimage.binary_fill_holes(mask) & ~mask)
        areas = np.bincount(holes.ravel())
        if len(areas) < 2:
            raise ValueError(f"Lowercase {letter} needs an enclosed bowl for body alignment.")
        counter = holes == int(areas[1:].argmax()) + 1
        _, columns = np.nonzero(counter)
        center = round(float(np.median(columns)))
        side = mask[:, center:] if letter == "p" else mask[:, :center]
        occupied = side.any(axis=1)
        top = int(np.flatnonzero(occupied)[0])
        return top + int(np.flatnonzero(~occupied[top:])[0])
    left, top, right, bottom = grayscale.getbbox()
    body_bottoms = []
    for column in mask[:, left:(left + right) // 2].T:
        ink = np.flatnonzero(column)
        if not len(ink) or ink[0] >= (top + bottom) / 2:
            continue
        gaps = np.flatnonzero(~column[ink[0]:])
        if len(gaps) and ink[0] + gaps[0] < ink[-1]:
            body_bottoms.append(int(ink[0] + gaps[0]))
    if not body_bottoms:
        raise ValueError("Lowercase y needs a separate upper fork for body alignment.")
    return max(body_bottoms)


def _normalize_letter(image, letter, canvas):
    grayscale = image.convert("L")
    bounds = grayscale.getbbox()
    body_bounds = bounds
    dot_bounds = None
    if letter in "ij":
        labels, _ = ndimage.label(np.asarray(grayscale) >= 128)
        areas = np.bincount(labels.ravel())
        body_label = int(areas[1:].argmax()) + 1
        components = ndimage.find_objects(labels)
        body_top = components[body_label - 1][0].start
        dot_bottom = max(component[0].stop for index, component in enumerate(components, 1) if index != body_label and component is not None and component[0].stop < body_top)
        split = (dot_bottom + body_top) // 2
        dot_bounds = grayscale.crop((0, 0, image.width, split)).getbbox()
        local_body = grayscale.crop((0, split, image.width, image.height)).getbbox()
        body_bounds = (local_body[0], local_body[1] + split, local_body[2], local_body[3] + split)
    top, bottom = _letter_frame(letter, canvas)
    height = bottom - top
    reference_height = body_bounds[3] - body_bounds[1]
    if letter in "gpqy":
        height = canvas["lowercase_x_height"]
        reference_height = _descender_body_bottom(grayscale, letter) - body_bounds[1]
    scale = height / reference_height
    height = max(1, round((body_bounds[3] - body_bounds[1]) * scale))
    body = grayscale.crop(body_bounds)
    body = body.resize((max(1, round(body.width * scale)), height), Image.Resampling.LANCZOS)
    body_left = round((body_bounds[0] - bounds[0]) * scale)
    layers = [(body, body_left, top)]
    if dot_bounds is not None:
        dot = grayscale.crop(dot_bounds)
        dot_scale = min(scale, (top - canvas["cap_line_y"] - canvas["minimum_dot_gap"]) / dot.height)
        dot = dot.resize((max(1, round(dot.width * dot_scale)), max(1, round(dot.height * dot_scale))), Image.Resampling.LANCZOS)
        body_mask = np.asarray(body) >= 128
        rows = np.arange(round(body.height * 0.2), round(body.height * 0.6))
        centers = np.array([np.flatnonzero(body_mask[row]).mean() for row in rows])
        slope, intercept = np.polyfit(rows, centers, 1)
        dot_y = canvas["cap_line_y"] + dot.height / 2 - top
        dot_center = body_left + intercept + slope * dot_y
        layers.append((dot, round(dot_center - dot.width / 2), canvas["cap_line_y"]))
    ink_width = max(layer.width + left for layer, left, _ in layers)
    width = max(canvas["width"], ink_width + 32)
    offset = (width - ink_width) // 2
    canvas_height = max(canvas["height"], max(y + layer.height for layer, _, y in layers) + 32)
    normalized = Image.new("L", (width, canvas_height), 0)
    for layer, left, y in layers:
        normalized.paste(layer, (offset + left, y))
    return normalized.convert("RGB")


def _match_stem_weight(image, letter, canvas, plan):
    grayscale = np.asarray(image.convert("L"))
    labels, _ = ndimage.label(grayscale >= 128)
    areas = np.bincount(labels.ravel())
    areas[0] = 0
    body = labels == areas.argmax()
    body_rows = np.flatnonzero(body.any(axis=1))
    top, bottom = int(body_rows[0]), int(body_rows[-1]) + 1
    span = canvas["lowercase_x_height"] if letter in "ij" else bottom - top
    fractions = np.asarray(plan["profile_positions_from_top"])
    target = np.asarray(plan["primary_normal_width_profile"])
    if letter == "t":
        target, fractions = target[1:], fractions[1:]
    fit_start, fit_end = (0.5, 0.8) if letter == "t" else (0.2, 0.6)
    fit_rows = np.arange(top + round(span * fit_start), top + round(span * fit_end))
    centers = np.array([np.flatnonzero(body[row]).mean() for row in fit_rows])
    slope, _ = np.polyfit(fit_rows, centers, 1)
    rows = top + np.rint((span - 1) * fractions).astype(int)
    widths = np.array([np.count_nonzero(body[row]) for row in rows]) / np.sqrt(1 + slope * slope)
    gains = target / widths
    output = grayscale.copy()
    grid = np.arange(image.width)
    for row in range(top, bottom):
        columns = np.flatnonzero(body[row])
        if not len(columns):
            continue
        center = columns.mean()
        gain = float(np.interp(row, rows, gains))
        if letter == "T":
            gain = 1 + (gain - 1) * np.clip(((row - top) / span - 0.2) / 0.2, 0, 1)
        source = center + (grid - center) / gain
        output[row] = np.rint(np.interp(source, grid, grayscale[row], left=0, right=0)).astype("uint8")
    return Image.fromarray(output).convert("RGB")


def _export_preview_metrics():
    canvas = json.loads((REFERENCE / "style-measurements.json").read_text())["target_canvas"]
    glyphs = {}
    for letter in sorted(CONSTRUCTIONS):
        case = "uppercase" if letter.isupper() else "lowercase"
        source = REFERENCE / f"{case}-{letter}.png"
        if not source.exists():
            continue
        with Image.open(source) as image:
            bounds = image.convert("L").getbbox()
            glyphs[letter] = {
                "left": bounds[0],
                "width": bounds[2] - bounds[0],
                "canvasWidth": image.width,
                "canvasHeight": image.height,
            }
    metrics = {
        "capHeight": canvas["cap_height"],
        "capLine": canvas["cap_line_y"],
        "xLine": canvas["baseline_y"] - canvas["lowercase_x_height"],
        "xHeight": canvas["lowercase_x_height"],
        "baseline": canvas["baseline_y"],
        "glyphs": glyphs,
    }
    destination = REFERENCE / "preview-metrics.js"
    destination.write_text("window.ribbonStudyMetrics = " + json.dumps(metrics, indent=2) + ";\n")
    print(f"Saved combination preview metrics: {destination}", flush=True)


def main():
    parser = argparse.ArgumentParser(description="Generate individual M-based alphabet PNGs, retain raw images, and prepare the word preview.")
    parser.add_argument("--letters", default="".join(sorted(CONSTRUCTIONS)))
    parser.add_argument("--clean-existing", action="store_true", help="Re-export the saved raw images without calling Fgen.")
    parser.add_argument("--raw-only", action="store_true", help="Save separate Fgen images and prompts without changing the normalized previews.")
    parser.add_argument("--feedback", help="Apply a measured correction with the current normalized glyph as the editing input beside the original M.")
    parser.add_argument("--guide", type=Path, help="Attach a calculated geometry guide; the original M remains the style master.")
    arguments = parser.parse_args()
    if any(letter not in CONSTRUCTIONS for letter in arguments.letters):
        parser.error("Only A–Z and a–z are supported.")
    executable = shutil.which("fgen")
    if executable is None and not arguments.clean_existing:
        raise SystemExit("Fgen is required; use the existing subscription login.")
    template = (REFERENCE / "style-prompt.txt").read_text()
    canvas = json.loads((REFERENCE / "style-measurements.json").read_text())["target_canvas"]
    raw_directory = REFERENCE / "raw"
    raw_directory.mkdir(exist_ok=True)
    for letter in arguments.letters:
        case = "uppercase" if letter.isupper() else "lowercase"
        stem = f"{case}-{letter}"
        destination = REFERENCE / f"{stem}.png"
        raw = raw_directory / f"{stem}.png"
        if letter == "M" and not arguments.clean_existing:
            with Image.open(REFERENCE / "master-M-reference.png") as image:
                image.convert("RGB").save(raw, format="PNG")
            (REFERENCE / f"{stem}.txt").write_text("Original capital M reused directly from master-M-reference.png. No Fgen generation; the supplied M remains the design master.\n")
        elif not arguments.clean_existing:
            history = raw_directory / "measured" / stem
            history.mkdir(parents=True, exist_ok=True)
            if not (history / "before.png").exists():
                for source, name in ((raw, "before.png"), (destination, "before-normalized.png"), (REFERENCE / f"{stem}.txt", "before.txt")):
                    if source.exists():
                        shutil.copyfile(source, history / name)
            attempt = len(list(history.glob("attempt-*.txt"))) + 1
            attempt_stem = history / f"attempt-{attempt:03d}"
            plan = CONSTRUCTIONS[letter]
            prompt = template.format(
                letter=letter, case=case, construction=plan["construction"],
                calculations=json.dumps(plan["calculations"], indent=2, ensure_ascii=False),
            )
            images = ["--image", str(REFERENCE / "master-M-reference.png")]
            if arguments.feedback:
                images.extend(["--image", str(destination)])
                prompt += "\n\nMEASURED CORRECTION: Image 1 remains the original M style master. Image 2 is the previous glyph to correct, not a new style reference. Preserve its correct anatomy and case placement while applying this specific measured feedback:\n" + arguments.feedback
            if arguments.guide:
                images.extend(["--image", str(arguments.guide)])
                prompt += "\n\nCALCULATED GEOMETRY GUIDE: The last image is an explicit construction/weight guide calculated for this letter, not a second style master. Preserve its anatomy, broad-to-narrow stroke mass and forward axis. Finish its curves, joins and terminals using the original M's ribbon character; do not copy any guide annotation.\n"
            attempt_stem.with_suffix(".txt").write_text(prompt)
            print(f"Generating {letter} separately with the original M reference", flush=True)
            result = subprocess.run([
                executable, "gen", "--prompt", prompt,
                *images,
                "--quality", "high", "--size", "1024x1024", "--timeout", "600",
                "--out", str(attempt_stem.with_suffix(".png")), "--json",
            ], stdout=subprocess.PIPE, text=True)
            attempt_stem.with_suffix(".jsonl").write_text(result.stdout)
            print(result.stdout, end="", flush=True)
            result.check_returncode()
            for event in map(json.loads, result.stdout.splitlines()):
                if event.get("event") == "saved":
                    generated = Path(event["path"])
                    break
            else:
                raise RuntimeError(f"Fgen did not report a saved image for {letter}.")
            if generated != raw:
                shutil.copyfile(generated, raw)
            (REFERENCE / f"{stem}.txt").write_text(prompt)
        if arguments.raw_only:
            print(f"Saved raw {letter}: {raw}; preview preparation deferred", flush=True)
            continue
        with Image.open(raw) as image:
            if letter == "M":
                cleaned = image.convert("RGB")
            else:
                cleaned = _normalize_letter(clean_letter(image), letter, canvas)
                if letter in "ITijlt":
                    cleaned = _match_stem_weight(cleaned, letter, canvas, CONSTRUCTIONS[letter]["calculations"])
        cleaned.save(destination, format="PNG")
        print(f"Saved {letter}: {destination} ({cleaned.width} × {cleaned.height}; raw generation retained)", flush=True)
    if not arguments.raw_only:
        _export_preview_metrics()


if __name__ == "__main__":
    main()
