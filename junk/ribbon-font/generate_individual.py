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
CONSTRUCTIONS = {
    "A": "Capital A: two asymmetric rising and falling ribbon legs, a softly rounded crest, and the original M's curved right foot. A SHORT crossbar grows rightward from the left leg but STOPS WELL BEFORE the right leg: its rounded tip must remain visibly separated from the right leg by black space. The internal triangular negative space is OPEN to the outside through this gap, not a fully enclosed triangular hole. This open, incomplete crossbar is essential; do not use a conventional closed-counter A. Keep the main left rise near the M's 61-degree diagonal, not an upright rounded-sans A.",
    "B": "Capital B: a gently leaning ribbon spine and two compact asymmetric bowls. The upper bowl is smaller; the lower bowl flows into the M-like curved foot. Two clean black counters. Avoid a thick rectangular stem or balloon-like bowls.",
    "C": "Capital C: a single open flowing ribbon, slightly oblique and softly asymmetric rather than a perfect oval. The upper and lower cut ends share M's subtly flattened round terminals. A generous clean opening on the right.",
    "D": "Capital D: a gently leaning ribbon spine flowing through one broad asymmetric outside bowl. One clean open black counter. The lower-right curve should feel like M's relaxed terminal turn, not a rigid geometric semicircle.",
    "E": "Capital E: a subtly leaning, softly bending spine with three restrained ribbon arms. The middle arm is shorter. Keep rounded internal joins and M-like soft-cut terminals, without slab serifs or inflated pill-shaped bars.",
    "F": "Capital F: the same gently moving ribbon spine and short soft-cut upper and middle arms as E, without a bottom arm. Natural width, restrained crossbars, no slabs or serifs.",
    "G": "Capital G: C's open asymmetric ribbon bowl with a short inward curl or restrained horizontal bar at the lower-right opening. The opening stays clear; avoid a generic geometric rounded G or a swollen circular bowl.",
    "H": "Capital H: two slightly asymmetric ribbon uprights, with the rising direction and soft terminal cuts borrowed from M, joined by one restrained curved crossbar. Keep open black spaces above and below it. No sharp corners.",
    "I": "Capital I: one narrow, gently leaning or softly bent ribbon stroke with M's rounded-flat top and bottom cuts. NO top bar, NO bottom bar, NO serifs. Keep it narrow; do not turn it into a slab I.",
    "J": "Capital J: one gently leaning ribbon descends from cap height and flows left into a relaxed rounded hook near the baseline. Use the M's curved-foot gesture. No top slab, no serif, no decorative loop.",
    "a": "Lowercase a, single storey: an oblique softly asymmetric bowl with one black counter and a short flowing right-hand foot. Body reaches the lowercase x-height, not cap height. It should echo the original M's curved troughs and terminal sweep, not a round balloon.",
    "b": "Lowercase b: one softly leaning ascender reaches cap height, flowing into a single x-height bowl on the right. One clean black counter. The shoulder and curved foot are made from M's rising ribbon and relaxed terminal, without a rigid upright or swollen oval.",
    "c": "Lowercase c: an open, softly oblique ribbon bowl at lowercase x-height. M-like flat-rounded terminals with a generous right-hand opening. Smaller body than uppercase C, with the SAME absolute stroke weight, not a scaled-down thin capital.",
    "d": "Lowercase d: one asymmetric x-height bowl on the left with a clean black counter, joined smoothly to a leaning ascender that reaches cap height on the right. A restrained M-like curved foot. Same stroke weight as uppercase, not a geometric balloon d.",
    "e": "Lowercase e: one compact, oblique, open ribbon bowl at x-height with a short soft cross-stroke that flows into its outer curve. A small clean black counter and clear right-hand aperture. No oversized round bowl, no sharp join.",
    "f": "Lowercase f: one softly bent ribbon ascender reaching cap height, turning gently at its top and ending near the baseline. A short restrained rounded crossbar near x-height. No slab, serif, oversized crossbar, decorative loop, or long descending swash.",
    "g": "Lowercase g, SINGLE STOREY: a softly oblique x-height bowl with one clean black counter, flowing into one relaxed right-side descender and a simple open leftward hook below the baseline. No second lower bowl, no double-storey g, no decorative loop.",
    "h": "Lowercase h: a gently leaning cap-height ascender, then one soft x-height shoulder descending into M's relaxed curved foot. The shoulder should come from one wave of M. Exactly one arch, not an m. Keep negative space open and the stroke weight unchanged.",
    "i": "Lowercase i: a narrow subtly leaning ribbon body ending at the baseline and reaching x-height, plus ONE small separate white dot above it. The dot is a softly rounded compact square or round shape, sized in proportion to M's ribbon width. No serif or baseline slab.",
    "j": "Lowercase j, correcting a rejected generic rounded-sans design. Build the body from the original M's broad LEFT RISING DIAGONAL: approximately 61 degrees above horizontal, with the top distinctly to the RIGHT of the baseline. The descending stroke therefore sweeps DOWN AND LEFT, not nearly vertically. Carry M's subtle taper, crisp smooth ribbon edges and softly flattened cuts. The body begins at lowercase x-height, passes the baseline, and finishes only 146 pixels below it with a SHORT restrained LEFTWARD exit. Keep the lower turn compact and shallow, not a large banana-shaped U hook, swollen heel or decorative swash. Add ONE separate compact slanted rounded-quadrilateral dot near the cap line; its width is approximately the stem thickness and its height about 80 percent of that width. The dot has softly flattened edges, never an egg, teardrop, circle or pill. Exactly two disconnected white components. No loop, serif, top slab, upright monoline sausage or ball-shaped terminal.",
    "K": "Capital K: one gently leaning ribbon spine with two asymmetric diagonal arms meeting in a rounded, compact central join. The rising diagonal and the relaxed lower-right foot come from M. Open triangular spaces, no rigid straight mechanical bars.",
    "L": "Capital L: one softly leaning ribbon spine turning naturally into a low rightward foot. Borrow M's rounded-flat terminal and relaxed curved-foot gesture. No serif, slab, or extra loop.",
    "M": "Original capital M: retain the supplied design master exactly; this glyph is sourced directly from the reference, not regenerated.",
    "N": "Capital N, unmistakably the letter N rather than M: exactly TWO tall upright ribbon stems, one on the left and one on the right, connected by ONE long descending diagonal from the TOP of the left stem to the BOTTOM of the right stem. The left and right stems both reach the cap line and baseline. There is NO middle rising arch, NO central peak, NO two-hump M skeleton. Keep the normal capital-N skeleton while borrowing only M's stroke weight, soft bends and terminal cuts. The diagonal must visibly run upper-left to lower-right.",
    "O": "Capital O: one continuous oblique asymmetric ribbon bowl, with one generous clean black counter. Gentle thick-to-thin flow, softly flattened turns, not a geometric circle or inflated balloon.",
    "P": "Capital P: one gently leaning full-height ribbon spine and one compact CLOSED upper bowl. The lower return of the bowl MUST JOIN the spine at mid-height, fully enclosing exactly ONE black counter. There must be NO gap between the bowl's lower return and the spine. A recognizable capital P, not an open hook, F or musical symbol. The lower stem ends in M's restrained soft-cut terminal. No lower bowl or serif.",
    "Q": "Capital Q: O's flowing asymmetric ribbon bowl, one clean counter, and one short diagonal tail exiting the lower-right edge. The tail is restrained and rounded, never a long swash or extra letter.",
    "R": "Capital R: a softly leaning ribbon spine, one compact upper bowl with a clean counter, and a relaxed diagonal lower-right leg flowing from the middle join. M-like foot, no slab or sharp corner.",
    "S": "Capital S: one smooth continuous asymmetric ribbon with a smaller upper curve and a broader lower curve. Deep clean internal turns, generous open terminals and controlled M-like thick-to-thin rhythm.",
    "T": "Capital T: one restrained broad top ribbon and one gently leaning descending spine. Compact rounded joins, softly flattened terminal cuts. No serifs, slab ends or oversized pill-like top bar.",
    "U": "Capital U: two gently leaning ribbon uprights flowing together through one deep soft bottom turn. Open at the top, asymmetric natural curvature, M-like relaxed right terminal.",
    "V": "Capital V: two asymmetric diagonal ribbon strokes meet in one softly rounded low turn. Preserve M's broad rising diagonal and deep inner trough, with no sharp pointed vertex.",
    "W": "Capital W: two connected asymmetric ribbon troughs with a smaller central rise, drawn as a flowing counterpart to M. Natural wide proportions, smooth rounded low turns and soft-cut terminals, no sharp zigzag.",
    "X": "Capital X: two oblique asymmetric ribbon diagonals cross in one compact rounded join. Preserve M's forward movement and natural stroke modulation; four restrained soft-cut terminals.",
    "Y": "Capital Y: two asymmetric ribbon branches meet in one compact soft join above a single descending spine. Open upper fork, restrained lower terminal, no extra branch or swash.",
    "Z": "Capital Z: two restrained horizontal ribbon ends joined by one broad flowing diagonal. Smooth directional turns and M-like rounded-flat terminal cuts, no angular mechanical corners.",
    "k": "Lowercase k: a softly leaning cap-height ascender and two compact asymmetric diagonal arms confined to the lowercase body area. Rounded central join and relaxed lower-right foot, not a small capital K.",
    "l": "Lowercase l, correcting a rejected generic rounded-sans design. Make ONE continuous ascender using the original M's broad LEFT RISING DIAGONAL, approximately 61 degrees above horizontal. The top must sit distinctly to the RIGHT of the baseline, with horizontal travel about 55 percent of cap height: an unmistakably oblique sweeping ribbon, NOT a nearly upright straight capsule. Preserve M's controlled thick-to-thin modulation, softly flattened terminal cuts and smooth asymmetric edge rhythm. At the baseline, finish with a SHORT restrained rightward exit borrowed from M's far-right foot. Keep that bottom turn shallow and compact, with no large U/C hook, bulbous heel or inflated foot. Full ascender height, naturally narrow letter proportions. No loop, top hook, serif, slab, second hump, circular cap or generic rounded-sans stem.",
    "m": "Lowercase m: two compact asymmetric x-height shoulders joined to a gently leaning ribbon stem. Exactly two arches, M-like rounded crests and relaxed feet. The body is distinctly shorter than capitals, not a capital M.",
    "n": "Lowercase n: one softly leaning x-height stem flowing into exactly one compact shoulder and a relaxed right foot. M-like rising ribbon and soft crest, not h, m or a small capital N.",
    "o": "Lowercase o: one compact oblique asymmetric x-height bowl with a clean black counter. Same ribbon character as M, natural width, not an inflated circle or a cap-height O.",
    "p": "Lowercase p: one x-height bowl to the right of a gently leaning stem that continues below the baseline. One clean counter; the bowl must stay inside the lowercase body area and only the stem descends.",
    "q": "Lowercase q: one compact x-height bowl on the left, one clean counter, and a gently leaning right stem continuing below the baseline with a restrained terminal. No extra lower loop or swash.",
    "r": "Lowercase r: one short x-height ribbon stem with one compact open rightward shoulder ending in a soft cut. No full arch, bowl, serif or decorative hook.",
    "s": "Lowercase s: one compact asymmetric x-height ribbon with a smaller upper curve and broader lower curve. Open soft-cut terminals and controlled concave turns, not a capital-height S.",
    "t": "Lowercase t: one gently leaning short ascender reaching between x-height and cap height, one restrained crossbar near x-height, and a soft curved baseline foot. Clearly shorter than a full cap-height ascender, no slab or serif.",
    "u": "Lowercase u: two compact x-height ribbon rises joined by one soft low turn and ending in a restrained right foot. Natural asymmetry and open top, not a cap-height U.",
    "v": "Lowercase v: two compact x-height asymmetric ribbon diagonals join in one rounded low turn. Open top and M-like inner trough, not a pointed geometric V.",
    "w": "Lowercase w, unmistakably an upright w rather than m or M: four connected short ribbon diagonals travel DOWN, UP, DOWN, UP from left to right. Start at the x-height at the upper-left, descend into the FIRST LOW VALLEY on the baseline, rise to the central x-height, descend into the SECOND LOW VALLEY on the baseline, then rise to the upper-right endpoint at x-height. Both outside endpoints are HIGH, both valleys are LOW, and the form opens upward. There must be NO two upward arches, NO upside-down w and NO M-shaped wave. Borrow only M's stroke character, soft low turns and terminal cuts. The entire body stays at lowercase x-height.",
    "x": "Lowercase x: two short oblique ribbon diagonals cross in a compact soft join entirely inside the x-height body area. Restrained rounded-flat terminal cuts, not a cap-height X.",
    "y": "Lowercase y: two compact x-height ribbon arms form a soft open fork, with the right-hand stroke continuing below the baseline into one restrained leftward hook. Only the descender extends below the lowercase body.",
    "z": "Lowercase z: two short restrained ribbon ends joined by one flowing diagonal entirely inside the x-height body area. Soft directional turns and rounded-flat cuts, not a cap-height Z.",
}


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
        if len(gaps) and ink[0] + gaps[0] < bottom:
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
        dot_center = ((dot_bounds[0] + dot_bounds[2]) / 2 - bounds[0]) * scale
        dot = dot.resize((max(1, round(dot.width * dot_scale)), max(1, round(dot.height * dot_scale))), Image.Resampling.LANCZOS)
        layers.append((dot, round(dot_center - dot.width / 2), canvas["cap_line_y"]))
    ink_width = max(layer.width + left for layer, left, _ in layers)
    width = max(canvas["width"], ink_width + 32)
    offset = (width - ink_width) // 2
    canvas_height = max(canvas["height"], max(y + layer.height for layer, _, y in layers) + 32)
    normalized = Image.new("L", (width, canvas_height), 0)
    for layer, left, y in layers:
        normalized.paste(layer, (offset + left, y))
    return normalized.convert("RGB")


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
            top, bottom = _letter_frame(letter, canvas)
            proportions = f"The main {case} form of {letter} occupies y={top} through y={bottom}. Lowercase bowls and short bodies are 406 pixels tall, only 72.5 percent of the 560-pixel capital height. For i/j only, the detached dot sits above the body near the cap line. Do not enlarge a lowercase body to fill the canvas."
            prompt = template.format(letter=letter, case=case, construction=CONSTRUCTIONS[letter], proportions=proportions)
            print(f"Generating {letter} separately with the original M reference", flush=True)
            result = subprocess.run([
                executable, "gen", "--prompt", prompt,
                "--image", str(REFERENCE / "master-M-reference.png"),
                "--quality", "high", "--size", "1024x1024", "--timeout", "600",
                "--out", str(raw), "--json",
            ], stdout=subprocess.PIPE, text=True)
            print(result.stdout, end="", flush=True)
            result.check_returncode()
            for event in map(json.loads, result.stdout.splitlines()):
                if event.get("event") == "saved":
                    generated = Path(event["path"])
                    break
            else:
                raise RuntimeError(f"Fgen did not report a saved image for {letter}.")
            with Image.open(generated) as image:
                pixels = image.convert("RGB")
            pixels.save(raw, format="PNG")
            (REFERENCE / f"{stem}.txt").write_text(prompt)
            if generated != raw:
                generated.unlink()
        if arguments.raw_only:
            print(f"Saved raw {letter}: {raw}; preview preparation deferred", flush=True)
            continue
        with Image.open(raw) as image:
            if letter == "M":
                cleaned = image.convert("RGB")
            else:
                cleaned = _normalize_letter(clean_letter(image), letter, canvas)
        cleaned.save(destination, format="PNG")
        print(f"Saved {letter}: {destination} ({cleaned.width} × {cleaned.height}; raw generation retained)", flush=True)
    if not arguments.raw_only:
        _export_preview_metrics()


if __name__ == "__main__":
    main()
