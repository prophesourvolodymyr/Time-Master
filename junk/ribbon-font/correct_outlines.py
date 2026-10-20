import json
import math

import numpy as np
from PIL import Image

from generate_individual import CONSTRUCTIONS, REFERENCE, _export_preview_metrics, _normalize_letter, clean_letter


CANVAS = json.loads((REFERENCE / "style-measurements.json").read_text())["target_canvas"]
DX_DY = json.loads((REFERENCE / "glyph-calculations.json").read_text())["master_measurement"]["principal_rightward_dx_per_dy"]


def load(letter):
    case = "uppercase" if letter.isupper() else "lowercase"
    with Image.open(REFERENCE / f"{case}-{letter}.png") as image:
        return np.asarray(image.convert("L"))


def load_generated(letter):
    case = "uppercase" if letter.isupper() else "lowercase"
    with Image.open(REFERENCE / "raw" / f"{case}-{letter}.png") as image:
        return np.asarray(_normalize_letter(clean_letter(image), letter, CANVAS).convert("L"))


def intervals(row):
    transitions = np.diff(np.pad(row >= 128, (1, 1)).astype(int))
    return [(int(left), int(right)) for left, right in zip(np.flatnonzero(transitions == 1), np.flatnonzero(transitions == -1)) if right - left > 12]


def fit_spine(pixels, side, rows):
    centers = []
    widths = []
    for row in rows:
        left, right = intervals(pixels[row])[0 if side == "left" else -1]
        centers.append((left + right - 1) / 2)
        widths.append(right - left)
    slope, intercept = np.polyfit(rows, centers, 1)
    return float(slope), float(intercept), float(np.median(widths))


def center_image(pixels):
    image = Image.fromarray(pixels)
    bounds = image.getbbox()
    ink = image.crop((bounds[0], 0, bounds[2], image.height))
    output = Image.new("L", (max(1024, ink.width + 64), image.height))
    output.paste(ink, ((output.width - ink.width) // 2, 0))
    return np.asarray(output)


def combine(layers):
    height = max(pixels.shape[0] for pixels, _ in layers)
    left = min(offset for _, offset in layers)
    right = max(offset + pixels.shape[1] for pixels, offset in layers)
    output = np.zeros((height, right - left), dtype=np.uint8)
    for pixels, offset in layers:
        region = output[:pixels.shape[0], offset - left:offset - left + pixels.shape[1]]
        np.maximum(region, pixels, out=region)
    return center_image(output)


def repair_n(pixels):
    plan = CONSTRUCTIONS["n"]["calculations"]
    top, span = 386, 406
    fractions = np.asarray(plan["profile_positions_from_top"])
    rows = top + np.rint((span - 1) * fractions).astype(int)
    anchor = top + round(span * 0.4)
    anchor_runs = intervals(pixels[anchor])
    centers = [(left + right - 1) / 2 for left, right in anchor_runs]
    sample_widths = np.array([[right - left for left, right in intervals(pixels[row])] for row in rows])
    target = np.asarray(plan["primary_normal_width_profile"]) * np.sqrt(1 + DX_DY * DX_DY)
    gains = target[:, None] / sample_widths
    output = pixels.copy()
    grid = np.arange(pixels.shape[1])
    for row in range(top, 792):
        runs = intervals(pixels[row])
        if len(runs) != 2:
            continue
        blend = float(np.clip((row - (top + span * 0.25)) / (span * 0.15), 0, 1))
        output[row] = 0
        for index, (left, right) in enumerate(runs):
            center = (left + right - 1) / 2
            desired_center = centers[index] - DX_DY * (row - anchor)
            new_center = center + blend * (desired_center - center)
            gain = 1 + blend * (float(np.interp(row, rows, gains[:, index])) - 1)
            source = center + (grid - new_center) / gain
            band = np.zeros(pixels.shape[1], dtype=np.uint8)
            band[max(0, left - 2):right + 2] = pixels[row, max(0, left - 2):right + 2]
            np.maximum(output[row], np.rint(np.interp(source, grid, band, left=0, right=0)).astype("uint8"), out=output[row])
    return center_image(output)


def master_stem(master, width, top, bottom, center_at_baseline):
    source_top, source_bottom = 233, 791
    slope, intercept, _ = fit_spine(master, "left", np.arange(344, 568))
    output = np.zeros((1024, width), dtype=np.uint8)
    grid = np.arange(width)
    source_grid = np.arange(master.shape[1])
    for row in range(top, bottom):
        source_row = round(source_top + (row - top) * (source_bottom - source_top - 1) / (bottom - top - 1))
        center = center_at_baseline - DX_DY * (row - 792)
        source = slope * source_row + intercept + grid - center
        output[row] = np.rint(np.interp(source, source_grid, master[source_row], left=0, right=0)).astype("uint8")
    return output


def repair_spine(pixels, letter, master):
    side = "right" if letter in "dqy" else "left"
    full = letter in "bdk"
    rows = np.arange(500, 630) if letter == "y" else (np.arange(344, 412) if full else np.arange(548, 710))
    slope, intercept, old_width = fit_spine(pixels, side, rows)
    shear = -DX_DY - slope
    ys, _ = np.nonzero(pixels >= 128)
    shifts = [shear * (int(row) - 792) for row in (ys.min(), ys.max())]
    offset = 32 - math.floor(min(0, *shifts))
    width = pixels.shape[1] + math.ceil(max(0, *shifts)) + offset + 32
    center = slope * 792 + intercept + offset
    features = np.zeros((1024, width), dtype=np.uint8)
    grid = np.arange(width)
    source_grid = np.arange(pixels.shape[1])
    plan = CONSTRUCTIONS[letter]["calculations"]
    join = min(old_width / 2, 0.5 * plan["primary_normal_width_profile"][0] * np.sqrt(1 + DX_DY * DX_DY) - plan["inside_turn_radius_guide"])
    for row in range(386, min(792, pixels.shape[0])):
        source = grid - offset - shear * (row - 792)
        values = np.interp(source, source_grid, pixels[row], left=0, right=0)
        axis = center - DX_DY * (row - 792)
        keep = grid > axis + join if side == "left" else grid < axis - join
        features[row] = np.rint(np.where(keep, values, 0)).astype("uint8")
    occupied = np.flatnonzero(np.any(features >= 128, axis=1))
    feature_top, feature_bottom = int(occupied[0]), int(occupied[-1]) + 1
    mapped = np.zeros_like(features)
    for row in range(386, 792):
        source_row = round(feature_top + (row - 386) * (feature_bottom - feature_top - 1) / 405)
        source = grid + DX_DY * (row - source_row)
        mapped[row] = np.rint(np.interp(source, grid, features[source_row], left=0, right=0)).astype("uint8")
    top, bottom = (232, 792) if full else ((386, 938) if letter in "pqy" else (386, 792))
    stem = master_stem(master, width, top, bottom, center)
    np.maximum(mapped, stem, out=mapped)
    return center_image(mapped), {"primary_side": side, "original_axis_degrees": round(math.degrees(math.atan2(1, -slope)), 2), "corrected_axis_degrees": 60.96, "body_feature_top_before": feature_top, "body_feature_top_after": 386, "stem_top": top, "stem_bottom": bottom}


def save(letter, pixels):
    clean_letter(Image.fromarray(pixels)).save(REFERENCE / f"lowercase-{letter}.png")


def main():
    master = load("I")
    records = {}
    n = repair_n(load_generated("n"))
    save("n", n)
    left_slope, left_intercept, _ = fit_spine(n, "left", np.arange(560, 700))
    right_slope, right_intercept, _ = fit_spine(n, "right", np.arange(560, 700))
    spacing = round(np.median([(right_slope - left_slope) * row + right_intercept - left_intercept for row in range(560, 700)]))
    l = center_image(master_stem(master, 1400, 232, 792, 600))
    save("l", l)
    l_slope, l_intercept, _ = fit_spine(l, "left", np.arange(560, 700))
    shift = round(np.median([(left_slope - l_slope) * row + left_intercept - l_intercept for row in range(560, 700)]))
    save("h", combine(((n, 0), (l, shift))))
    save("m", combine(((n, 0), (n, spacing))))
    records.update({"l": {"repair": "Replace rejected lambda-like l with the measured single I ribbon, fitted to M axis; same cap height and absolute taper."}, "n": {"repair": "Retain generated shoulder; correct both separated shafts to the measured M taper and one forward axis."}, "h": {"repair": "Union corrected n shoulder/body with the measured l ascender on its first shaft.", "ascender_offset_x": shift}, "m": {"repair": "Union two corrected n components with one shared middle shaft, producing exactly three shafts and two shoulders.", "shared_stem_spacing": spacing}})
    for letter in "bdkpqry":
        pixels, record = repair_spine(load_generated(letter), letter, master)
        save(letter, pixels)
        records[letter] = {"repair": "Retain generated bowl/arms or y fork; fit the primary ribbon to M axis and absolute weight, fit body features to x-height, and use the common compact descender depth.", **record}
    (REFERENCE / "contour-corrections.json").write_text(json.dumps({"style_master": "Original untouched M; I supplies its measured ribbon profile. Each letter's actual raw Fgen attempts and submitted calculations remain under raw/.", "glyphs": records}, indent=2) + "\n")
    _export_preview_metrics()
    print("Corrected n/l/h/m and b/d/k/p/q/r/y from the retained generated contours; raw generations unchanged.")


if __name__ == "__main__":
    main()
