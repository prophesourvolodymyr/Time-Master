import math
import string
import unittest
from pathlib import Path

from fontTools.pens.recordingPen import RecordingPen
from fontTools.ttLib import TTFont


FONT = Path(__file__).with_name("ribbon-vector.otf")


def cubic_join_angles(recording):
    contours = []
    segments = []
    start = current = None
    for command, points in recording.value:
        if command == "moveTo":
            start = current = points[0]
            segments = []
        elif command == "curveTo":
            segments.append(("cubic", [current, *points]))
            current = points[-1]
        elif command == "lineTo":
            segments.append(("line", [current, points[0]]))
            current = points[0]
        elif command == "closePath":
            if math.dist(current, start) > 1e-7:
                segments.append(("line", [current, start]))
            contours.append(segments)
    for segments in contours:
        for (kind, before), (next_kind, after) in zip(segments, segments[1:] + segments[:1]):
            if kind != "cubic" or next_kind != "cubic":
                continue
            incoming = next(
                ((before[-1][0] - point[0], before[-1][1] - point[1])
                 for point in reversed(before[:-1]) if math.dist(before[-1], point) > 1e-7),
                None,
            )
            outgoing = next(
                ((point[0] - after[0][0], point[1] - after[0][1])
                 for point in after[1:] if math.dist(point, after[0]) > 1e-7),
                None,
            )
            if incoming is None or outgoing is None:
                yield before[-1], 180
                continue
            cosine = sum(a * b for a, b in zip(incoming, outgoing)) / (math.hypot(*incoming) * math.hypot(*outgoing))
            yield before[-1], math.degrees(math.acos(max(-1, min(1, cosine))))


class VectorContourTests(unittest.TestCase):
    def test_drawn_curves_do_not_kink_at_cubic_joins(self):
        with TTFont(FONT, recalcTimestamp=False) as font:
            glyphs = font.getGlyphSet()
            for letter in string.ascii_letters.replace("M", ""):
                outline = RecordingPen()
                glyphs[letter].draw(outline)
                for point, angle in cubic_join_angles(outline):
                    with self.subTest(letter=letter, point=point):
                        self.assertLessEqual(angle, 5, f"{letter}: abrupt {angle:.2f}-degree tangent change")


if __name__ == "__main__":
    unittest.main()
