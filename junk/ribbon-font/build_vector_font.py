import argparse
import base64
import hashlib
import json
import math
import shutil
import string
import subprocess
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

from PIL import Image, ImageOps
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.areaPen import AreaPen
from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.cu2quPen import Cu2QuPen
from fontTools.pens.recordingPen import RecordingPen
from fontTools.pens.reverseContourPen import ReverseContourPen
from fontTools.pens.roundingPen import RoundingPen
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.t2CharStringPen import T2CharStringPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.svgLib.path.parser import parse_path
from fontTools.ttLib import TTFont

from vector_lowercase import GLYPHS as LOWERCASE
from vector_uppercase import GLYPHS as UPPERCASE


HERE = Path(__file__).resolve().parent
REFERENCE = HERE.parents[1] / "genesis/REFERENCE/ribbon-font"
LETTERS = string.ascii_uppercase + string.ascii_lowercase
UNITS_PER_EM = 1000
CAP_HEIGHT = 560
X_HEIGHT = 406
ASCENT = 680
DESCENT = 200
BEARING = 24
MASTER_ADVANCE = 880
SHEAR = 0.5553


def bounds(recording):
    pen = BoundsPen(None)
    recording.replay(pen)
    return pen.bounds


def oriented(recording, counter=False):
    area = AreaPen(None)
    recording.replay(area)
    if not area.value:
        raise ValueError("A contour has no filled area")
    if (area.value > 0) == counter:
        return recording
    result = RecordingPen()
    recording.replay(ReverseContourPen(result))
    return result


def draw_letter(character, definition):
    result = RecordingPen()
    outer_count = 0
    for data, counter in definition["paths"]:
        contour = RecordingPen()
        parse_path(data, contour)
        if sum(command == "moveTo" for command, _ in contour.value) != 1:
            raise ValueError(f"{character}: each path must contain one contour")
        if not contour.value or contour.value[-1][0] != "closePath":
            raise ValueError(f"{character}: an outline is not closed")
        outer_count += not counter
        oriented(contour, counter).replay(TransformPen(result, (1, 0, SHEAR, 1, BEARING, 0)))
    if outer_count != (2 if character in "ij" else 1):
        raise ValueError(f"{character}: unexpected detached positive contours")
    x0, y0, x1, y1 = bounds(result)
    if y0 < -DESCENT or y1 > ASCENT:
        raise ValueError(f"{character}: font metrics would clip the outline")
    return result, (round(definition["width"] + 2 * BEARING), round(x0))


def trace_master(source):
    tracer = shutil.which("potrace")
    if tracer is None:
        raise SystemExit("Potrace is required to trace the original M; install with brew install potrace.")
    with Image.open(source) as original:
        image = original.convert("L")
    image = image.resize((image.width * 4, image.height * 4), Image.Resampling.LANCZOS)
    scale = CAP_HEIGHT / image.height
    padding = 3
    bitmap = ImageOps.expand(image.point(lambda pixel: 0 if pixel >= 128 else 255), padding, 255)
    with tempfile.TemporaryDirectory(prefix="ribbon-original-M-") as directory:
        destination = Path(directory) / "M.pbm"
        bitmap.convert("1", dither=Image.Dither.NONE).save(destination)
        traced = subprocess.run(
            [tracer, str(destination), "--svg", "--flat", "--unit", "100",
             "--alphamax", "1.334", "--opttolerance", "0.05", "--output", "-"],
            check=True, capture_output=True,
        )
    result = RecordingPen()
    transform = (scale / 100, 0, 0, scale / 100, BEARING - padding * scale, -padding * scale)
    root = ET.fromstring(traced.stdout)
    for element in root.iter("{http://www.w3.org/2000/svg}path"):
        contour = RecordingPen()
        parse_path(element.attrib["d"], contour)
        oriented(contour).replay(TransformPen(result, transform))
    if sum(command == "moveTo" for command, _ in result.value) != 1:
        raise ValueError("The original M must remain one continuous silhouette")
    return result, (MASTER_ADVANCE, round(bounds(result)[0]))


def missing_glyph():
    result = RecordingPen()
    for data, counter in (
        ("M 40 0 L 40 560 L 400 560 L 400 0 Z", False),
        ("M 90 50 L 90 510 L 350 510 L 350 50 Z", True),
    ):
        contour = RecordingPen()
        parse_path(data, contour)
        oriented(contour, counter).replay(result)
    return result


def compile_font(outlines, metrics, output, quadratic):
    recordings = {".notdef": missing_glyph(), "space": RecordingPen(), **outlines}
    widths = {".notdef": (440, 40), "space": (240, 0), **metrics}
    order = list(recordings)
    builder = FontBuilder(UNITS_PER_EM, isTTF=quadratic)
    builder.setupGlyphOrder(order)
    builder.setupCharacterMap({32: "space", **{ord(letter): letter for letter in LETTERS}})
    if quadratic:
        glyphs = {}
        for name, recording in recordings.items():
            pen = TTGlyphPen(None)
            recording.replay(Cu2QuPen(pen, max_err=0.15))
            glyphs[name] = pen.glyph()
        builder.setupGlyf(glyphs)
        builder.setupHorizontalMetrics({
            name: (widths[name][0], glyphs[name].xMin if glyphs[name].numberOfContours else 0)
            for name in order
        })
    else:
        charstrings = {}
        for name, recording in recordings.items():
            pen = T2CharStringPen(widths[name][0], None, roundTolerance=0)
            recording.replay(RoundingPen(pen, roundFunc=lambda value: round(value * 64) / 64))
            charstrings[name] = pen.getCharString()
        builder.setupCFF(
            "RibbonMVector-Regular",
            {"FullName": "Ribbon M Vector Regular", "FamilyName": "Ribbon M Vector", "Weight": "Regular"},
            charstrings, {},
        )
        builder.setupHorizontalMetrics(widths)
    builder.setupHorizontalHeader(ascent=ASCENT, descent=-DESCENT, lineGap=0)
    builder.setupNameTable({
        "familyName": "Ribbon M Vector",
        "styleName": "Regular",
        "uniqueFontIdentifier": "RibbonMVector-Regular-2.000",
        "fullName": "Ribbon M Vector Regular",
        "psName": "RibbonMVector-Regular",
        "version": "Version 2.000",
        "description": "Original M traced without redesign; 51 individually drawn filled Bezier letterforms. A-Z, a-z and space. Human design review pending.",
    })
    builder.setupOS2(
        version=4, sTypoAscender=ASCENT, sTypoDescender=-DESCENT, sTypoLineGap=0,
        usWinAscent=ASCENT, usWinDescent=DESCENT,
        sCapHeight=CAP_HEIGHT, sxHeight=X_HEIGHT, usWeightClass=400,
        fsSelection=0xC0, fsType=0,
    )
    builder.setupPost()
    builder.font["head"].created = 3875212800
    builder.font["head"].modified = 3875212800
    builder.font["head"].fontRevision = 2.0
    builder.font.recalcTimestamp = False
    path = output / ("ribbon-vector.ttf" if quadratic else "ribbon-vector.otf")
    builder.save(path)
    print(f"Created {path.name}: {path.stat().st_size:,} bytes")


def export_review(output, reference, definitions, source):
    reference.mkdir(parents=True, exist_ok=True)
    font = TTFont(output / "ribbon-vector.otf", recalcTimestamp=False)
    glyph_set = font.getGlyphSet()
    glyphs = {}
    for character in LETTERS:
        outline = RecordingPen()
        glyph_set[character].draw(outline)
        extent = bounds(outline)
        canvas_width = max(1024, math.ceil(extent[2] - extent[0] + 96))
        offset = (canvas_width - extent[2] + extent[0]) / 2 - extent[0]
        svg = SVGPathPen(None)
        outline.replay(svg)
        filename = f"{'uppercase' if character.isupper() else 'lowercase'}-{character}.svg"
        (reference / filename).write_text(
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{canvas_width}" height="1024" viewBox="0 0 {canvas_width} 1024">'
            f'<title>Ribbon M Vector — {character}</title><path fill="#000" d="M0 0H{canvas_width}V1024H0Z"/>'
            f'<path fill="#fff" transform="translate({offset:g} 792) scale(1 -1)" d="{svg.getCommands()}"/></svg>\n'
        )
        glyphs[character] = {
            "advance": font["hmtx"][character][0],
            "bounds": [round(value, 3) for value in extent],
            "canvasWidth": canvas_width,
            "canvasHeight": 1024,
            "contours": sum(command == "moveTo" for command, _ in outline.value),
            "cubicSegments": sum(command == "curveTo" for command, _ in outline.value),
            "note": definitions[character]["note"] if character != "M" else "The user's original M, uniformly traced at cap height 560. Its outline is not sheared, redesigned or patched. An optical advance of 880 units reduces excess spacing after its right foot while keeping consecutive M letters separate at zero tracking.",
        }
    font.close()
    metadata = {
        "unitsPerEm": UNITS_PER_EM, "capHeight": CAP_HEIGHT, "xHeight": X_HEIGHT,
        "ascender": ASCENT, "descender": DESCENT, "glyphs": glyphs,
    }
    construction = {
        "status": "Human design review pending; not human-approved.",
        "source": str(source.relative_to(HERE.parents[1])),
        "sourceSha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "construction": "M is traced from the untouched original. Other letters are individually drawn closed cubic Bezier contours. Counters use opposite winding; no overlapping positive components or raster outline repairs.",
        "axisRightwardTravelPerHeight": SHEAR,
        "curveConversion": "OTF retains cubic outlines on a 1/64-unit coordinate grid, preventing fractional closing drift. TTF and WOFF2 use quadratic conversion with maximum curve-fit error 0.15 design units before integer coordinate rounding.",
        **metadata,
    }
    (reference / "construction.json").write_text(json.dumps(construction, indent=2) + "\n")
    embedded = {"font": "data:font/woff2;base64," + base64.b64encode((output / "ribbon-vector.woff2").read_bytes()).decode(), **metadata}
    (output / "vector-font.js").write_text("window.ribbonVector = " + json.dumps(embedded, separators=(",", ":")) + ";\n")
    print(f"Exported {len(glyphs)} exact cubic glyph previews and an embedded real webfont")


def main():
    parser = argparse.ArgumentParser(description="Build the new M-based cubic-outline alphabet and its actual-font review assets.")
    parser.add_argument("--output", type=Path, default=HERE)
    parser.add_argument("--reference", type=Path, default=REFERENCE / "vector-m")
    arguments = parser.parse_args()
    definitions = {**UPPERCASE, **LOWERCASE}
    if set(definitions) != set(LETTERS) - {"M"}:
        raise ValueError("Provide every uppercase and lowercase letter except the untouched M")
    source = REFERENCE / "individual-m/master-M.png"
    outlines = {}
    metrics = {}
    for character in LETTERS:
        outlines[character], metrics[character] = trace_master(source) if character == "M" else draw_letter(character, definitions[character])
    arguments.output.mkdir(parents=True, exist_ok=True)
    for quadratic in (False, True):
        compile_font(outlines, metrics, arguments.output, quadratic)
    webfont = TTFont(arguments.output / "ribbon-vector.ttf", recalcTimestamp=False)
    webfont.flavor = "woff2"
    webfont.save(arguments.output / "ribbon-vector.woff2")
    webfont.close()
    export_review(arguments.output, arguments.reference, definitions, source)
    print("Coverage: A–Z, a–z and space; app fonts and earlier attempts are unchanged")


if __name__ == "__main__":
    main()
