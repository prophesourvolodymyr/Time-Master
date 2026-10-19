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
    "j": "Lowercase j: a narrow subtly leaning x-height body flowing below the baseline into a short relaxed leftward hook, plus ONE small separate white dot above it. Same dot treatment and absolute stroke weight as i; no top slab, serif, loop, or decorative swash.",
}


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


def main():
    parser = argparse.ArgumentParser(description="Generate A–J and a–j individually with the original M attached to every Fgen call.")
    parser.add_argument("--letters", default="ABCDEFGHIJabcdefghij")
    parser.add_argument("--clean-existing", action="store_true", help="Re-export the saved raw images without calling Fgen.")
    arguments = parser.parse_args()
    if any(letter not in CONSTRUCTIONS for letter in arguments.letters):
        parser.error("This review batch contains only A–J and a–j.")
    executable = shutil.which("fgen")
    if executable is None and not arguments.clean_existing:
        raise SystemExit("Fgen is required; use the existing subscription login.")
    template = (REFERENCE / "style-prompt.txt").read_text()
    raw_directory = REFERENCE / "raw"
    raw_directory.mkdir(exist_ok=True)
    for letter in arguments.letters:
        case = "uppercase" if letter.isupper() else "lowercase"
        stem = f"{case}-{letter}"
        destination = REFERENCE / f"{stem}.png"
        raw = raw_directory / f"{stem}.png"
        if not arguments.clean_existing:
            prompt = template.format(letter=letter, case=case, construction=CONSTRUCTIONS[letter])
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
        with Image.open(raw) as image:
            cleaned = clean_letter(image)
        cleaned.save(destination, format="PNG")
        print(f"Saved {letter}: {destination} ({cleaned.width} × {cleaned.height}; raw generation retained)", flush=True)


if __name__ == "__main__":
    main()
