import argparse
import math
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.cu2quPen import Cu2QuPen
from fontTools.pens.recordingPen import RecordingPen
from fontTools.pens.t2CharStringPen import T2CharStringPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.svgLib.path.parser import parse_path
from fontTools.ttLib import TTFont


HERE = Path(__file__).resolve().parent
SHEETS = (
    ("source.png", "AMNVW", "AMNVW", "amnvw"),
    ("source-fghij.png", "FGHIJ", "FHI", "fhi"),
    ("source-klopq.png", "KLOPQ", "KLOP", "klo"),
    ("source-bcder.png", "BCDER", "BCDE", "bcder"),
)
UPPERCASE = "".join(sorted("".join(sheet[1] for sheet in SHEETS)))
CHARACTERS = UPPERCASE + UPPERCASE.lower()
UNITS_PER_EM = 1000
SIDE_BEARING = 30
PADDING = 3
TRACE_UNIT = 100


def extract_outlines(source, tracer, uppercase, cap_baseline_letters, lower_baseline_letters):
    image = np.asarray(Image.open(source).convert("L"))
    labels, _ = ndimage.label(image >= 128)
    components = []
    for label, slices in enumerate(ndimage.find_objects(labels), 1):
        if slices is None or np.count_nonzero(labels[slices] == label) < 500:
            continue
        y, x = slices
        components.append((label, x.start, y.start, x.stop, y.stop))
    upper = sorted(
        (item for item in components if (item[2] + item[4]) / 2 < image.shape[0] / 2),
        key=lambda item: (item[1] + item[3]) / 2,
    )
    lower = [item for item in components if (item[2] + item[4]) / 2 >= image.shape[0] / 2]
    if len(upper) != len(uppercase):
        raise ValueError(f"{source.name}: expected {len(uppercase)} uppercase glyphs; found {len(upper)}")
    groups = {character: [component] for character, component in zip(uppercase, upper)}
    groups.update({character: [] for character in uppercase.lower()})
    column_centers = [(item[1] + item[3]) / 2 for item in upper]
    for component in lower:
        center = (component[1] + component[3]) / 2
        column = min(range(len(upper)), key=lambda index: abs(center - column_centers[index]))
        groups[uppercase[column].lower()].append(component)
    if any(not group for group in groups.values()):
        raise ValueError(f"{source.name}: a lowercase glyph is missing")
    bounds = {
        character: (
            min(item[1] for item in group), min(item[2] for item in group),
            max(item[3] for item in group), max(item[4] for item in group),
        )
        for character, group in groups.items()
    }
    cap_baseline = max(bounds[character][3] for character in cap_baseline_letters)
    lower_baseline = max(bounds[character][3] for character in lower_baseline_letters)
    scale = 700 / (cap_baseline - min(bounds[character][1] for character in uppercase))
    outlines = {}
    metrics = {}
    with tempfile.TemporaryDirectory(prefix="ribbon-font-") as temporary:
        bitmap = Path(temporary) / "glyph.pbm"
        for character, group in groups.items():
            x0, y0, x1, y1 = bounds[character]
            mask = np.pad(np.isin(labels[y0:y1, x0:x1], [item[0] for item in group]), PADDING)
            Image.fromarray(np.where(mask, 0, 255).astype("uint8")).convert(
                "1", dither=Image.Dither.NONE
            ).save(bitmap)
            result = subprocess.run(
                [tracer, str(bitmap), "--svg", "--flat", "--unit", str(TRACE_UNIT),
                 "--opttolerance", "0.05", "--output", "-"],
                check=True, capture_output=True,
            )
            baseline = cap_baseline if character.isupper() else lower_baseline
            transform = (
                scale / TRACE_UNIT, 0, 0, scale / TRACE_UNIT,
                SIDE_BEARING - PADDING * scale,
                (baseline - y1 - PADDING) * scale,
            )
            recording = RecordingPen()
            pen = TransformPen(recording, transform)
            root = ET.fromstring(result.stdout)
            for path in root.iter("{http://www.w3.org/2000/svg}path"):
                parse_path(path.attrib["d"], pen)
            outline_bounds = BoundsPen(None)
            recording.replay(outline_bounds)
            outlines[character] = recording
            metrics[character] = (
                round((x1 - x0) * scale + 2 * SIDE_BEARING),
                round(outline_bounds.bounds[0]),
            )
    return outlines, metrics


def build_font(outlines, metrics, x_height, ascent, descent, output, is_ttf):
    order = [".notdef", "space", *CHARACTERS]
    missing = RecordingPen()
    for rectangle in [((60, 0), (60, 650), (450, 650), (450, 0)),
                      ((100, 40), (410, 40), (410, 610), (100, 610))]:
        missing.moveTo(rectangle[0])
        for point in rectangle[1:]:
            missing.lineTo(point)
        missing.closePath()
    recordings = {".notdef": missing, "space": RecordingPen(), **outlines}
    all_metrics = {".notdef": (510, 60), "space": (300, 0), **metrics}
    builder = FontBuilder(UNITS_PER_EM, isTTF=is_ttf)
    builder.setupGlyphOrder(order)
    builder.setupCharacterMap({32: "space", **{ord(c): c for c in CHARACTERS}})
    if is_ttf:
        glyphs = {}
        for name, recording in recordings.items():
            pen = TTGlyphPen(None)
            recording.replay(Cu2QuPen(pen, max_err=0.25))
            glyphs[name] = pen.glyph()
        builder.setupGlyf(glyphs)
        builder.setupHorizontalMetrics({
            name: (all_metrics[name][0], glyphs[name].xMin if glyphs[name].numberOfContours else 0)
            for name in order
        })
    else:
        char_strings = {}
        for name, recording in recordings.items():
            pen = T2CharStringPen(all_metrics[name][0], None)
            recording.replay(pen)
            char_strings[name] = pen.getCharString()
        builder.setupCFF(
            "RibbonSpecimen-Regular",
            {"FullName": "Ribbon Specimen Regular", "FamilyName": "Ribbon Specimen", "Weight": "Regular"},
            char_strings, {},
        )
        builder.setupHorizontalMetrics(all_metrics)
    builder.setupHorizontalHeader(ascent=ascent, descent=-descent, lineGap=0)
    builder.setupNameTable({
        "familyName": "Ribbon Specimen",
        "styleName": "Regular",
        "uniqueFontIdentifier": "RibbonSpecimen-Regular-1.100",
        "fullName": "Ribbon Specimen Regular",
        "psName": "RibbonSpecimen-Regular",
        "version": "Version 1.100",
        "description": f"{len(CHARACTERS)} glyphs traced from four supplied PNG sheets. {UPPERCASE} and lowercase; space. No other characters are supplied.",
    })
    builder.setupOS2(
        version=4,
        sTypoAscender=ascent, sTypoDescender=-descent, sTypoLineGap=0,
        usWinAscent=ascent, usWinDescent=descent,
        sCapHeight=700, sxHeight=x_height, usWeightClass=400,
        fsSelection=0xC0, fsType=0,
    )
    builder.setupPost()
    builder.font["head"].created = 3875212800
    builder.font["head"].modified = 3875212800
    builder.font.recalcTimestamp = False
    builder.font["head"].fontRevision = 1.1
    destination = output / ("ribbon-specimen.ttf" if is_ttf else "ribbon-specimen.otf")
    builder.save(destination)
    print(f"Created {destination.name}: {destination.stat().st_size:,} bytes")


def main():
    parser = argparse.ArgumentParser(description="Trace the supplied ribbon letter sheets into real OpenType fonts. Requires Potrace, Pillow, NumPy, SciPy, and fonttools[woff].")
    parser.add_argument("--source-dir", type=Path, default=HERE.parents[1] / "genesis/REFERENCE/ribbon-font")
    parser.add_argument("--output", type=Path, default=HERE)
    arguments = parser.parse_args()
    tracer = shutil.which("potrace")
    if tracer is None:
        raise SystemExit("Potrace is required. On macOS: brew install potrace")
    arguments.output.mkdir(parents=True, exist_ok=True)
    outlines = {}
    metrics = {}
    for filename, uppercase, cap_baseline_letters, lower_baseline_letters in SHEETS:
        sheet_outlines, sheet_metrics = extract_outlines(
            arguments.source_dir / filename, tracer, uppercase,
            cap_baseline_letters, lower_baseline_letters,
        )
        outlines.update(sheet_outlines)
        metrics.update(sheet_metrics)
        print(f"Traced {uppercase} and {uppercase.lower()} from {filename}")
    bounds = BoundsPen(None)
    for recording in outlines.values():
        recording.replay(bounds)
    ascent = max(820, math.ceil(bounds.bounds[3] / 10) * 10)
    descent = max(180, math.ceil(-bounds.bounds[1] / 10) * 10)
    x_bounds = BoundsPen(None)
    outlines["m"].replay(x_bounds)
    x_height = round(x_bounds.bounds[3])
    for is_ttf in (False, True):
        build_font(outlines, metrics, x_height, ascent, descent, arguments.output, is_ttf)
    font = TTFont(arguments.output / "ribbon-specimen.ttf", recalcTimestamp=False)
    font.flavor = "woff2"
    destination = arguments.output / "ribbon-specimen.woff2"
    font.save(destination)
    print(f"Created {destination.name}: {destination.stat().st_size:,} bytes")
    print(f"Character coverage: {CHARACTERS} and space; no invented letters")


if __name__ == "__main__":
    main()
