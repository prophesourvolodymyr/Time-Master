import argparse
import hashlib
import json
import math
import os
import platform
import shutil
import string
import subprocess
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

try:
    import fontTools
    import numpy as np
    import PIL
    import scipy
    from PIL import Image
    from scipy import ndimage
    from fontTools.feaLib.builder import addOpenTypeFeaturesFromString
    from fontTools.fontBuilder import FontBuilder
    from fontTools.pens.areaPen import AreaPen
    from fontTools.pens.basePen import BasePen
    from fontTools.pens.boundsPen import BoundsPen
    from fontTools.pens.cu2quPen import Cu2QuPen
    from fontTools.pens.recordingPen import RecordingPen
    from fontTools.pens.reverseContourPen import ReverseContourPen
    from fontTools.pens.roundingPen import RoundingPen
    from fontTools.pens.t2CharStringPen import T2CharStringPen
    from fontTools.pens.transformPen import TransformPen
    from fontTools.pens.ttGlyphPen import TTGlyphPen
    from fontTools.svgLib.path.parser import parse_path
    from fontTools.ttLib import TTFont
    from fontTools.ttLib.woff2 import haveBrotli
except ImportError as error:
    raise SystemExit(
        f"Missing Python prerequisite: {error}. Install with: "
        "python3 -m pip install pillow numpy scipy 'fonttools[woff]'"
    ) from None


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
SOURCE = ROOT / "genesis/REFERENCE/ribbon-font/ribbon-source.json"
METRICS = ROOT / "genesis/REFERENCE/ribbon-font/ribbon-font-metrics.json"
RUNTIME_SOURCE = HERE / "ribbon-source.js"
LETTERS = string.ascii_uppercase + string.ascii_lowercase
SIDE_BEARING = 14
SPACE_ADVANCE = 240
MINIMUM_INK_GAP = 24
MINIMUM_KERN = 8
MAXIMUM_TUCK = 64
MAXIMUM_TUCK_FRACTION = 0.12
ENVELOPE_CELL = 1
ENVELOPE_PADDING = 1
RASTER_PADDING = 3
TRACE_UNIT = 1000
QUADRATIC_ERROR = 0.15
MAXIMUM_AREA_ERROR = 0.02
TIMESTAMP = 3875212800


def require(condition, message):
    if not condition:
        raise ValueError(message)


def relative(path):
    return path.relative_to(ROOT).as_posix()


def project_path(value):
    path = (ROOT / value).resolve()
    require(path.is_relative_to(ROOT), f"Source path is outside the project: {value}")
    return path


def fingerprint(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verify_sources(source):
    records = source["provenanceFiles"] + [
        {"path": source["glyphs"][letter]["src"], "sha256": source["glyphs"][letter]["sha256"]}
        for letter in LETTERS
    ]
    for record in records:
        path = project_path(record["path"])
        require(path.is_file(), f"Missing immutable source: {record['path']}")
        require(fingerprint(path) == record["sha256"], f"Source fingerprint changed: {record['path']}")
    return len(records)


def bounds(recording):
    pen = BoundsPen(None)
    recording.replay(pen)
    require(pen.bounds is not None, "An expected outline is empty")
    return pen.bounds


def contours(recording):
    result = []
    current = None
    for command, arguments in recording.value:
        if command == "moveTo":
            require(current is None, "An outline contour is not closed")
            current = RecordingPen()
        require(current is not None, "An outline contour has no starting point")
        getattr(current, command)(*arguments)
        if command == "closePath":
            result.append(current)
            current = None
        require(command != "endPath", "An outline contains an open contour")
    require(current is None, "An outline contour is not closed")
    return result


def contour_areas(recording):
    result = []
    for contour in contours(recording):
        pen = AreaPen(None)
        contour.replay(pen)
        require(abs(pen.value) > 0, "An outline contour has no filled area")
        result.append(pen.value)
    return result


def outline_metrics(recording):
    areas = contour_areas(recording)
    return {
        "bounds": [round(value, 6) for value in bounds(recording)],
        "components": sum(area < 0 for area in areas),
        "counters": sum(area > 0 for area in areas),
        "filledArea": round(-sum(areas), 6),
    }


def check_topology(letter, measured, expected):
    require(
        (measured["components"], measured["counters"]) == (expected["components"], expected["counters"]),
        f"{letter}: silhouette components/counters changed: {measured['components']}/{measured['counters']} "
        f"instead of {expected['components']}/{expected['counters']}",
    )


def component_metrics(labels, count):
    areas = np.bincount(labels.ravel())
    result = []
    for label, slices in enumerate(ndimage.find_objects(labels), 1):
        if slices is None:
            continue
        y, x = slices
        result.append({"pixelArea": int(areas[label]), "bounds": [x.start, y.start, x.stop, y.stop]})
    require(len(result) == count, "A raster component could not be measured")
    return result


def read_mask(letter, record, source):
    with Image.open(project_path(record["src"])) as original:
        require(original.size == (record["canvasWidth"], record["canvasHeight"]), f"{letter}: PNG dimensions changed")
        rgba = original.convert("RGBA")
        image = Image.alpha_composite(Image.new("RGBA", rgba.size, (0, 0, 0, 255)), rgba).convert("L")
        threshold = source["raster"]["threshold"]
        mask = np.asarray(image) >= threshold
        excluded = int(np.count_nonzero((np.asarray(rgba.convert("L")) >= threshold) & ~mask))
        original_mode = original.mode
    y, x = np.nonzero(mask)
    require(len(x) > 0, f"{letter}: PNG has no white silhouette after compositing against black")
    extent = [int(x.min()), int(y.min()), int(x.max()) + 1, int(y.max()) + 1]
    require(
        extent[0] > 0 and extent[1] > 0 and extent[2] < mask.shape[1] and extent[3] < mask.shape[0],
        f"{letter}: source ink touches the PNG canvas edge",
    )
    labels, count = ndimage.label(mask)
    holes, hole_count = ndimage.label(ndimage.binary_fill_holes(mask) & ~mask)
    check_topology(letter, {"components": count, "counters": hole_count}, record["silhouette"])
    baseline = record.get("baseline", record["bottom"])
    body_top = record["top"] if letter.isupper() else record.get("xTop", record["top"])
    require(0 <= body_top < baseline <= record["canvasHeight"], f"{letter}: invalid body landmarks")
    height = source["capHeight"] if letter.isupper() else source["xHeight"]
    scale = height / (baseline - body_top)
    return mask, scale, baseline, {
        "source": record["src"],
        "sha256": record["sha256"],
        "canvas": [record["canvasWidth"], record["canvasHeight"]],
        "originalLayoutBounds": [record[key] for key in ("left", "top", "right", "bottom")],
        "bodyTop": body_top,
        "baseline": baseline,
        "uniformScale": round(scale, 12),
        "rasterBounds": extent,
        "originalMode": original_mode,
        "alphaCompositedAgainstBlack": True,
        "foregroundPixelsExcludedByAlpha": excluded,
        "rasterMaskSha256": hashlib.sha256(np.packbits(mask, bitorder="big").tobytes()).hexdigest(),
        "rasterInkPixels": int(np.count_nonzero(mask)),
        "rasterComponents": component_metrics(labels, count),
        "rasterCounters": component_metrics(holes, hole_count),
        "normalizedRasterArea": int(np.count_nonzero(mask)) * scale * scale,
    }


def trace_glyph(letter, mask, scale, baseline, tracer, temporary, metric):
    x0, y0, x1, y1 = metric["rasterBounds"]
    cropped = np.pad(mask[y0:y1, x0:x1], RASTER_PADDING)
    bitmap = temporary / "glyph.pbm"
    Image.fromarray(np.where(cropped, 0, 255).astype("uint8")).convert("1", dither=Image.Dither.NONE).save(bitmap)
    result = subprocess.run(
        [tracer, str(bitmap), "--svg", "--flat", "--unit", str(TRACE_UNIT), "--turdsize", "0",
         "--alphamax", "1", "--opttolerance", "0.05", "--output", "-"],
        capture_output=True,
    )
    require(result.returncode == 0, f"{letter}: Potrace failed: {result.stderr.decode(errors='replace').strip()}")
    recording = RecordingPen()
    transform = (
        scale / TRACE_UNIT, 0, 0, scale / TRACE_UNIT,
        -RASTER_PADDING * scale, (baseline - y1 - RASTER_PADDING) * scale,
    )
    pen = TransformPen(recording, transform)
    for element in ET.fromstring(result.stdout).iter("{http://www.w3.org/2000/svg}path"):
        parse_path(element.attrib["d"], pen)
    areas = contour_areas(recording)
    require(areas, f"{letter}: Potrace produced no closed contours")
    if max(areas, key=abs) > 0:
        reversed_recording = RecordingPen()
        recording.replay(ReverseContourPen(reversed_recording))
        recording = reversed_recording
    x_min = bounds(recording)[0]
    positioned = RecordingPen()
    recording.replay(TransformPen(positioned, (1, 0, 0, 1, SIDE_BEARING - x_min, 0)))
    metric["sourceToFontTransform"] = [
        round(scale, 12), 0, 0, round(-scale, 12),
        round(SIDE_BEARING - x_min - x0 * scale, 6), round(baseline * scale, 6),
    ]
    return positioned


def missing_glyph():
    recording = RecordingPen()
    for points in (
        ((40, 0), (40, 560), (400, 560), (400, 0)),
        ((90, 50), (350, 50), (350, 510), (90, 510)),
    ):
        recording.moveTo(points[0])
        for point in points[1:]:
            recording.lineTo(point)
        recording.closePath()
    return recording


def quadratic_glyphs(recordings):
    result = {}
    for name, recording in recordings.items():
        pen = TTGlyphPen(None)
        recording.replay(Cu2QuPen(pen, max_err=QUADRATIC_ERROR))
        glyph = pen.glyph()
        if glyph.numberOfContours:
            glyph.recalcBounds(None)
        result[name] = glyph
    return result


class EnvelopePen(BasePen):
    def __init__(self, y_min, size):
        super().__init__(None)
        self.y_min = y_min
        self.left = np.full(size, np.inf)
        self.right = np.full(size, -np.inf)
        self.current = None
        self.first = None

    def _mark(self, points):
        x_values, y_values = zip(*points)
        first = max(0, math.floor(min(y_values)) - ENVELOPE_PADDING - self.y_min)
        last = min(len(self.left), math.ceil(max(y_values)) + ENVELOPE_PADDING - self.y_min + 1)
        self.left[first:last] = np.minimum(self.left[first:last], min(x_values) - ENVELOPE_PADDING)
        self.right[first:last] = np.maximum(self.right[first:last], max(x_values) + ENVELOPE_PADDING)

    def _bezier(self, points):
        x_values, y_values = zip(*points)
        if max(max(x_values) - min(x_values), max(y_values) - min(y_values)) <= ENVELOPE_CELL:
            self._mark(points)
            return
        left, right = [points[0]], [points[-1]]
        while len(points) > 1:
            points = tuple(((a[0] + b[0]) / 2, (a[1] + b[1]) / 2) for a, b in zip(points, points[1:]))
            left.append(points[0])
            right.append(points[-1])
        self._bezier(tuple(left))
        self._bezier(tuple(reversed(right)))

    def _moveTo(self, point):
        self.current = point
        self.first = point

    def _lineTo(self, point):
        self._bezier((self.current, point))
        self.current = point

    def _curveToOne(self, first, second, point):
        self._bezier((self.current, first, second, point))
        self.current = point

    def _qCurveToOne(self, control, point):
        self._bezier((self.current, control, point))
        self.current = point

    def _closePath(self):
        self._lineTo(self.first)
        self.first = None

    def _endPath(self):
        raise ValueError("An outline contains an open contour")


def measure_spacing(recordings, quadratics, advances, ascent, descent):
    y_min = -descent - MINIMUM_INK_GAP - 2
    size = ascent + descent + 2 * MINIMUM_INK_GAP + 5
    envelopes = {}
    widths = {}
    for letter in LETTERS:
        pen = EnvelopePen(y_min, size)
        recordings[letter].replay(pen)
        quadratics[letter].draw(pen, None)
        envelopes[letter] = (
            pen.left,
            ndimage.maximum_filter1d(pen.right, size=2 * MINIMUM_INK_GAP + 1, mode="constant", cval=-np.inf),
        )
        extent = bounds(recordings[letter])
        widths[letter] = extent[2] - extent[0]
    adjustments = {}
    pairs = {}
    smallest_gap = math.inf
    largest_gap = -math.inf
    for left in LETTERS:
        dilated_right = envelopes[left][1]
        for right in LETTERS:
            left_edges = envelopes[right][0]
            shared = np.isfinite(dilated_right) & np.isfinite(left_edges)
            require(np.any(shared), f"{left}{right}: no shared vertical body range for optical measurement")
            gap = float(np.min(advances[left] + left_edges[shared] - dilated_right[shared]))
            tuck_limit = math.floor(min(MAXIMUM_TUCK, MAXIMUM_TUCK_FRACTION * min(widths[left], widths[right])))
            adjustment = max(-tuck_limit, math.ceil(MINIMUM_INK_GAP - gap))
            if -MINIMUM_KERN < adjustment < 0:
                adjustment = 0
            adjusted_gap = gap + adjustment
            require(adjusted_gap >= MINIMUM_INK_GAP - 1e-9, f"{left}{right}: optical spacing would collide")
            smallest_gap = min(smallest_gap, adjusted_gap)
            largest_gap = max(largest_gap, adjusted_gap)
            if adjustment:
                adjustments[(left, right)] = adjustment
            pairs[left + right] = {
                "adjustment": adjustment,
                "unkernedConservativeGap": round(gap, 6),
                "kernedConservativeGap": round(adjusted_gap, 6),
            }
    require(adjustments, "The optical measurements produced no built-in kerning")
    return adjustments, {
        "externalTracking": 0,
        "boundingBoxSideBearing": SIDE_BEARING,
        "minimumInkClearance": MINIMUM_INK_GAP,
        "envelopeCell": ENVELOPE_CELL,
        "envelopePadding": ENVELOPE_PADDING,
        "verticalNeighborhood": MINIMUM_INK_GAP,
        "maximumTuck": MAXIMUM_TUCK,
        "maximumTuckFractionOfNarrowerInk": MAXIMUM_TUCK_FRACTION,
        "minimumAppliedKern": MINIMUM_KERN,
        "spaceAdvance": SPACE_ADVANCE,
        "measuredLetterPairCount": len(pairs),
        "adjustedPairCount": len(adjustments),
        "adjustmentRange": [min(adjustments.values()), max(adjustments.values())],
        "kernedConservativeGapRange": [round(smallest_gap, 6), round(largest_gap, 6)],
        "method": "Full ink bounds receive positive side bearings, never a reduced advance. "
        "GPOS only adjusts measured pairs, with bounded corner tucks and no word-specific rules. "
        "Conservative one-unit Bezier control-hull envelopes cover both cubic and rounded quadratic outlines, "
        "expanded by one unit and compared across a 24-unit vertical neighborhood. "
        "Every adjusted horizontal gap is at least 24 units; vertically more distant ink is also at least 24 units apart. "
        "Small negative adjustments below eight units are omitted. Spaces receive no pair adjustment.",
        "pairs": pairs,
    }


def compile_font(source, source_hash, recordings, quadratics, advances, kerning, ascent, descent, output, quadratic):
    builder = FontBuilder(source["unitsPerEm"], isTTF=quadratic)
    builder.setupGlyphOrder(list(recordings))
    builder.setupCharacterMap({32: "space", **{ord(letter): letter for letter in LETTERS}})
    if quadratic:
        builder.setupGlyf(quadratics)
        builder.setupHorizontalMetrics({
            name: (advances[name], glyph.xMin if glyph.numberOfContours else 0)
            for name, glyph in quadratics.items()
        })
    else:
        charstrings = {}
        for name, recording in recordings.items():
            pen = T2CharStringPen(advances[name], None, roundTolerance=0)
            recording.replay(RoundingPen(pen, roundFunc=lambda value: round(value * 64) / 64))
            charstrings[name] = pen.getCharString()
        builder.setupCFF(
            source["postScriptName"],
            {"FullName": source["familyName"] + " " + source["styleName"], "FamilyName": source["familyName"],
             "Weight": source["styleName"], "version": "1.000", "Copyright": source["copyright"],
             "Notice": source["license"]},
            charstrings, {},
        )
        builder.setupHorizontalMetrics({
            name: (advances[name], round(bounds(recording)[0]) if name != "space" else 0)
            for name, recording in recordings.items()
        })
    builder.setupHorizontalHeader(ascent=ascent, descent=-descent, lineGap=0)
    builder.setupNameTable({
        "copyright": source["copyright"],
        "designer": source["designer"],
        "licenseDescription": source["license"],
        "familyName": source["familyName"],
        "styleName": source["styleName"],
        "typographicFamily": source["familyName"],
        "typographicSubfamily": source["styleName"],
        "uniqueFontIdentifier": f"{source['postScriptName']};1.000;{source_hash[:16]}",
        "fullName": source["familyName"] + " " + source["styleName"],
        "psName": source["postScriptName"],
        "version": "Version 1.000",
        "description": "The 52 selected original-M ribbon PNG silhouettes, uniformly scaled and traced without pixel cleanup. "
        "A-Z, a-z and space only. Numbers, punctuation, diacritics and symbols are not supplied. "
        "Positive side bearings and built-in optical GPOS kerning; use zero external tracking.",
    })
    builder.setupOS2(
        version=4, sTypoAscender=ascent, sTypoDescender=-descent, sTypoLineGap=0,
        usWinAscent=ascent, usWinDescent=descent,
        sCapHeight=source["capHeight"], sxHeight=source["xHeight"], usWeightClass=400,
        fsSelection=0xC0, fsType=0x0002,
    )
    builder.setupPost()
    features = ["languagesystem DFLT dflt;", "languagesystem latn dflt;", "feature kern {"]
    features.extend(f"pos {left} {right} {value};" for (left, right), value in sorted(kerning.items()))
    features.append("} kern;")
    addOpenTypeFeaturesFromString(builder.font, "\n".join(features))
    builder.font["head"].created = TIMESTAMP
    builder.font["head"].modified = TIMESTAMP
    builder.font["head"].fontRevision = 1.0
    builder.font.recalcTimestamp = False
    builder.save(output)


def subtable_kern(subtable, left, right):
    if subtable.Format == 1:
        if left not in subtable.Coverage.glyphs:
            return None
        pair_set = subtable.PairSet[subtable.Coverage.glyphs.index(left)]
        for pair in pair_set.PairValueRecord:
            if pair.SecondGlyph == right:
                return getattr(pair.Value1, "XAdvance", 0) if pair.Value1 else 0
        return None
    require(subtable.Format == 2, "Unexpected GPOS pair positioning format")
    if left not in subtable.Coverage.glyphs:
        return None
    first = subtable.ClassDef1.classDefs.get(left, 0)
    second = subtable.ClassDef2.classDefs.get(right, 0)
    value = subtable.Class1Record[first].Class2Record[second].Value1
    return getattr(value, "XAdvance", 0) if value else 0


def validate_kerning(font, kerning):
    require("GPOS" in font, "Compiled font has no built-in GPOS kerning")
    table = font["GPOS"].table
    lookup_indices = sorted({
        index
        for feature in table.FeatureList.FeatureRecord if feature.FeatureTag == "kern"
        for index in feature.Feature.LookupListIndex
    })
    require(lookup_indices, "Compiled font has no active kern feature")
    for left in LETTERS:
        for right in LETTERS:
            measured = 0
            for index in lookup_indices:
                lookup = table.LookupList.Lookup[index]
                require(lookup.LookupType in (2, 9), "Unexpected lookup type in kern feature")
                for subtable in lookup.SubTable:
                    if lookup.LookupType == 9:
                        require(subtable.ExtensionLookupType == 2, "Unexpected extension lookup in kern feature")
                        subtable = subtable.ExtSubTable
                    value = subtable_kern(subtable, left, right)
                    if value is not None:
                        measured += value
                        break
            require(measured == kerning.get((left, right), 0), f"{left}{right}: compiled GPOS adjustment changed")


def validate_font(path, source, glyph_metrics, advances, kerning, ascent, descent):
    result = {}
    with TTFont(path, recalcTimestamp=False) as font:
        expected_cmap = {32: "space", **{ord(letter): letter for letter in LETTERS}}
        require(font.getBestCmap() == expected_cmap, f"{path.name}: character coverage differs from the supplied alphabet")
        require(font["name"].getDebugName(6) == source["postScriptName"], f"{path.name}: PostScript name changed")
        require(font["head"].unitsPerEm == source["unitsPerEm"], f"{path.name}: units per em changed")
        require(font["head"].created == TIMESTAMP and font["head"].modified == TIMESTAMP, f"{path.name}: unstable timestamps")
        require(font["hhea"].ascent == ascent and font["hhea"].descent == -descent, f"{path.name}: line metrics changed")
        validate_kerning(font, kerning)
        glyph_set = font.getGlyphSet()
        for letter in LETTERS:
            recording = RecordingPen()
            glyph_set[letter].draw(recording)
            measured = outline_metrics(recording)
            check_topology(letter, measured, source["glyphs"][letter]["silhouette"])
            x0, y0, x1, y1 = bounds(recording)
            require(y0 >= -descent and y1 <= ascent, f"{path.name}: {letter} would be clipped vertically")
            require(x0 > 0 and x1 < advances[letter], f"{path.name}: {letter} has no positive bounding-box side bearings")
            require(font["hmtx"][letter][0] == advances[letter], f"{path.name}: {letter} advance changed")
            area_error = abs(measured["filledArea"] / glyph_metrics[letter]["normalizedRasterArea"] - 1)
            require(area_error <= MAXIMUM_AREA_ERROR, f"{path.name}: {letter} traced area differs by {area_error:.2%}")
            measured["relativeRasterAreaError"] = round(area_error, 9)
            measured["advance"] = advances[letter]
            measured["leftSideBearing"] = font["hmtx"][letter][1]
            measured["rightInkBearing"] = round(advances[letter] - x1, 6)
            measured["outlineSha256"] = hashlib.sha256(json.dumps(recording.value, separators=(",", ":")).encode()).hexdigest()
            result[letter] = measured
        require(font["hmtx"]["space"][0] == SPACE_ADVANCE, f"{path.name}: word space changed")
    return result


def runtime_source(source):
    glyphs = {}
    for letter in LETTERS:
        record = source["glyphs"][letter]
        glyph = {"src": os.path.relpath(project_path(record["src"]), HERE).replace(os.sep, "/")}
        for key in ("canvasWidth", "canvasHeight", "left", "top", "right", "bottom", "xTop", "baseline"):
            if key in record:
                glyph[key] = record[key]
        glyphs[letter] = glyph
    result = {key: source[key] for key in ("unitsPerEm", "capHeight", "xHeight")}
    result["glyphs"] = glyphs
    return "window.ribbonSource = " + json.dumps(result, ensure_ascii=True, separators=(",", ":")) + ";\n"


def main():
    parser = argparse.ArgumentParser(
        description="Build TimeMaster TTF, OTF, WOFF2, runtime PNG mapping and provenance/spacing metrics from the canonical source JSON.",
        epilog="Run from any directory. Requires Potrace (macOS: brew install potrace), Pillow, NumPy, SciPy and fonttools[woff]. "
        "Coverage: A-Z, a-z and space only; no numbers, punctuation, diacritics or symbols.",
    )
    parser.parse_args()
    tracer = shutil.which("potrace")
    require(tracer is not None, "Potrace is required. Install with: brew install potrace")
    require(haveBrotli, "WOFF2 compression requires Brotli. Install with: python3 -m pip install 'fonttools[woff]'")
    require(SOURCE.is_file(), f"Missing canonical source mapping: {SOURCE}")
    source = json.loads(SOURCE.read_text(encoding="utf-8"))
    NATIVE_TTF = project_path(source["outputs"]["nativeTtf"])
    SPECIMEN_OTF = project_path(source["outputs"]["specimenOtf"])
    WEB_WOFF2 = project_path(source["outputs"]["webWoff2"])
    require(source["schemaVersion"] == 1, "Unsupported canonical source schema")
    require(set(source["glyphs"]) == set(LETTERS), "Canonical source must contain exactly A-Z and a-z")
    require((source["unitsPerEm"], source["capHeight"], source["xHeight"]) == (1000, 560, 406), "Canonical shared heights must be 1000/560/406")
    require(source["raster"] == {"alphaBackground": "#000000", "threshold": 128, "foregroundComparison": "greater-than-or-equal", "componentConnectivity": 4}, "Unsupported silhouette threshold/compositing policy")
    source_hash = fingerprint(SOURCE)
    verified_source_count = verify_sources(source)
    version = subprocess.run([tracer, "--version"], check=True, capture_output=True, text=True).stdout.splitlines()[0].strip()
    with tempfile.TemporaryDirectory(prefix="timemaster-font-") as directory:
        temporary = Path(directory)
        outlines, glyph_metrics = {}, {}
        for letter in LETTERS:
            record = source["glyphs"][letter]
            mask, scale, baseline, metric = read_mask(letter, record, source)
            outline = trace_glyph(letter, mask, scale, baseline, tracer, temporary, metric)
            check_topology(letter, outline_metrics(outline), record["silhouette"])
            outlines[letter] = outline
            glyph_metrics[letter] = metric
        recordings = {".notdef": missing_glyph(), "space": RecordingPen(), **outlines}
        quadratics = quadratic_glyphs(recordings)
        advances = {".notdef": 440, "space": SPACE_ADVANCE}
        all_bounds = []
        for letter in LETTERS:
            cubic_bounds = bounds(outlines[letter])
            quadratic_recording = RecordingPen()
            quadratics[letter].draw(quadratic_recording, None)
            quadratic_bounds = bounds(quadratic_recording)
            all_bounds.extend((cubic_bounds, quadratic_bounds))
            advances[letter] = math.ceil(max(cubic_bounds[2], quadratics[letter].xMax)) + SIDE_BEARING
        ascent = math.ceil((max(extent[3] for extent in all_bounds) + MINIMUM_INK_GAP) / 10) * 10
        descent = math.ceil((max(0, -min(extent[1] for extent in all_bounds)) + MINIMUM_INK_GAP) / 10) * 10
        kerning, spacing = measure_spacing(recordings, quadratics, advances, ascent, descent)
        outputs = {
            NATIVE_TTF: temporary / NATIVE_TTF.name,
            SPECIMEN_OTF: temporary / SPECIMEN_OTF.name,
            WEB_WOFF2: temporary / WEB_WOFF2.name,
            RUNTIME_SOURCE: temporary / RUNTIME_SOURCE.name,
        }
        compile_font(source, source_hash, recordings, quadratics, advances, kerning, ascent, descent, outputs[NATIVE_TTF], True)
        compile_font(source, source_hash, recordings, quadratics, advances, kerning, ascent, descent, outputs[SPECIMEN_OTF], False)
        with TTFont(outputs[NATIVE_TTF], recalcTimestamp=False) as font:
            font.flavor = "woff2"
            font.save(outputs[WEB_WOFF2])
        validated = {}
        for destination in (NATIVE_TTF, SPECIMEN_OTF, WEB_WOFF2):
            validated[destination] = validate_font(outputs[destination], source, glyph_metrics, advances, kerning, ascent, descent)
        for letter in LETTERS:
            require(
                validated[NATIVE_TTF][letter]["outlineSha256"] == validated[WEB_WOFF2][letter]["outlineSha256"],
                f"{letter}: WOFF2 outlines differ from native TTF",
            )
            glyph_metrics[letter]["outlines"] = {
                "ttf": validated[NATIVE_TTF][letter],
                "otf": validated[SPECIMEN_OTF][letter],
                "woff2": validated[WEB_WOFF2][letter],
            }
            glyph_metrics[letter]["normalizedRasterArea"] = round(glyph_metrics[letter]["normalizedRasterArea"], 6)
        outputs[RUNTIME_SOURCE].write_text(runtime_source(source), encoding="utf-8")
        minimum_left = min(validated[NATIVE_TTF][letter]["bounds"][0] for letter in LETTERS)
        minimum_right = min(validated[NATIVE_TTF][letter]["rightInkBearing"] for letter in LETTERS)
        spacing["minimumWordSpaceInkGap"] = round(SPACE_ADVANCE + minimum_left + minimum_right, 6)
        require(spacing["minimumWordSpaceInkGap"] > 2 * MINIMUM_INK_GAP, "Word spaces are not distinct from letter spacing")
        metrics = {
            "schemaVersion": 1,
            "font": {
                "familyName": source["familyName"], "styleName": source["styleName"], "postScriptName": source["postScriptName"],
                "copyright": source["copyright"], "designer": source["designer"], "license": source["license"],
                "unitsPerEm": source["unitsPerEm"], "capHeight": source["capHeight"], "xHeight": source["xHeight"],
                "ascent": ascent, "descent": descent, "lineGap": 0,
                "coverage": source["coverage"], "mappedCodePointCount": len(LETTERS) + 1,
                "glyphCountIncludingNotdef": len(recordings), "fixedOpenTypeTimestamp": TIMESTAMP,
            },
            "provenance": {
                "mapping": relative(SOURCE), "mappingSha256": source_hash,
                "builder": relative(Path(__file__).resolve()), "builderSha256": fingerprint(Path(__file__).resolve()),
                "verifiedImmutableSourceCount": verified_source_count,
                "files": source["provenanceFiles"],
            },
            "toolchain": {
                "python": platform.python_version(), "fontTools": fontTools.__version__, "pillow": PIL.__version__,
                "numpy": np.__version__, "scipy": scipy.__version__, "potrace": version,
            },
            "trace": {
                "raster": source["raster"], "rasterPadding": RASTER_PADDING, "potraceUnit": TRACE_UNIT,
                "potraceTurdSize": 0, "potraceAlphaMax": 1, "potraceOptimizationTolerance": 0.05,
                "quadraticMaximumError": QUADRATIC_ERROR, "maximumRelativeRasterAreaError": MAXIMUM_AREA_ERROR,
                "pixelCleanup": False, "nonuniformScaling": False,
            },
            "invariants": {
                "sourceFingerprintsUnchanged": True, "allSuppliedLettersMapped": True,
                "noInventedCoverage": True, "allContoursClosed": True, "componentsAndCountersPreserved": True,
                "dotsRemainSeparate": True, "lineMetricsContainEveryOutline": True,
                "positiveBoundingBoxSideBearings": True, "allLetterPairsMeetMinimumClearance": True,
                "compiledGposMatchesMeasuredPairs": True, "woff2OutlinesMatchNativeTtf": True,
            },
            "spacing": spacing,
            "glyphs": glyph_metrics,
            "artifacts": {
                relative(destination): {"sha256": fingerprint(staged), "bytes": staged.stat().st_size}
                for destination, staged in outputs.items()
            },
        }
        verify_sources(source)
        require(fingerprint(SOURCE) == source_hash, "Canonical source mapping changed during the build")
        staged_metrics = temporary / METRICS.name
        staged_metrics.write_text(json.dumps(metrics, ensure_ascii=True, indent=2) + "\n", encoding="utf-8")
        outputs[METRICS] = staged_metrics
        for destination, staged in outputs.items():
            destination.parent.mkdir(parents=True, exist_ok=True)
            staged.replace(destination)
            print(f"Created {relative(destination)}: {destination.stat().st_size:,} bytes")
    print(f"Coverage: {LETTERS} and U+0020 space only.")
    print("Unsupported: numbers, punctuation, diacritics and symbols. No substitute glyphs were invented.")
    print(f"Tracking 0: positive {SIDE_BEARING}-unit bearings; {len(kerning)} measured GPOS pairs; minimum ink clearance {MINIMUM_INK_GAP} units.")
    print(f"Preserved fingerprints: {verified_source_count} immutable source/provenance files.")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError, ET.ParseError) as error:
        raise SystemExit(f"TimeMaster font build failed: {error}") from None
