import unittest

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

from generate_individual import _descender_body_bottom, _match_stem_weight, _normalize_letter
from correct_outlines import repair_spine


class DotPlacementTests(unittest.TestCase):
    def test_dots_follow_the_forward_stem_axis(self):
        canvas = {
            "width": 1024,
            "height": 1024,
            "cap_line_y": 232,
            "baseline_y": 792,
            "lowercase_x_height": 406,
            "short_ascender_height": 476,
            "minimum_dot_gap": 34,
            "descender_limit_y": 938,
        }
        for letter, bottom in (("i", 792), ("j", 938)):
            with self.subTest(letter=letter):
                image = Image.new("L", (1024, 1024))
                draw = ImageDraw.Draw(image)
                travel = (bottom - 386) // 2
                draw.polygon(((570, 386), (670, 386), (670 - travel, bottom), (570 - travel, bottom)), fill=255)
                draw.rectangle((530, 232, 610, 310), fill=255)

                result = _normalize_letter(image, letter, canvas)
                labels, count = ndimage.label(np.asarray(result.convert("L")) >= 128)
                self.assertEqual(count, 2, "The dot must stay detached and unclipped.")
                areas = np.bincount(labels.ravel())
                body_label = int(areas[1:].argmax()) + 1
                body = labels == body_label
                dot = (labels != 0) & ~body
                dot_y, dot_x = np.nonzero(dot)
                sample_y = canvas["baseline_y"] - 120
                stem_x = np.flatnonzero(body[sample_y]).mean()
                expected_dot_x = stem_x + 0.5 * (sample_y - dot_y.mean())

                self.assertAlmostEqual(dot_x.mean(), expected_dot_x, delta=2)
                body_top = np.nonzero(body)[0].min()
                self.assertGreaterEqual(body_top - dot_y.max() - 1, canvas["minimum_dot_gap"])


class DescenderAlignmentTests(unittest.TestCase):
    def test_y_body_alignment_ignores_black_after_the_tail(self):
        image = Image.new("L", (120, 220))
        draw = ImageDraw.Draw(image)
        draw.rectangle((30, 20, 50, 90), fill=255)
        draw.polygon(((80, 20), (100, 20), (40, 180), (20, 180)), fill=255)
        draw.rectangle((50, 80, 80, 100), fill=255)

        self.assertEqual(_descender_body_bottom(image, "y"), 91)


class StemWeightTests(unittest.TestCase):
    def test_measured_taper_preserves_axis_height_and_detached_dot(self):
        image = Image.new("L", (1024, 1024))
        draw = ImageDraw.Draw(image)
        draw.polygon(((565, 386), (655, 386), (452, 791), (362, 791)), fill=255)
        draw.ellipse((650, 232, 730, 302), fill=255)
        fractions = np.array((0.4, 0.5, 0.6, 0.7, 0.8, 0.88))
        targets = np.array((132, 140, 143, 148, 157, 160))
        plan = {
            "profile_positions_from_top": fractions.tolist(),
            "primary_normal_width_profile": targets.tolist(),
        }
        result = _match_stem_weight(image, "i", {"lowercase_x_height": 406}, plan)
        before = np.asarray(image)
        after = np.asarray(result.convert("L"))
        np.testing.assert_array_equal(before[:386], after[:386])
        self.assertEqual(image.getbbox()[1::2], result.getbbox()[1::2])
        for fraction, target in zip(fractions, targets):
            row = 386 + round(405 * fraction)
            old_columns = np.flatnonzero(before[row] >= 128)
            columns = np.flatnonzero(after[row] >= 128)
            self.assertAlmostEqual(len(columns) / np.sqrt(1.25), target, delta=1.5)
            self.assertAlmostEqual(columns.mean(), old_columns.mean(), delta=1)
        self.assertEqual(ndimage.label(after >= 128)[1], 2)


class SpineJoinTests(unittest.TestCase):
    def test_weight_correction_keeps_both_descender_bowls_closed_and_attached(self):
        master = np.zeros((1024, 1400), dtype=np.uint8)
        for row in range(233, 791):
            center = 650 - 0.5553 * (row - 792)
            master[row, round(center - 80):round(center + 80)] = 255
        for letter, side in (("p", 1), ("q", -1)):
            with self.subTest(letter=letter):
                pixels = np.zeros((1024, 1800), dtype=np.uint8)
                for row in range(386, 938):
                    axis = 850 - 0.5553 * (row - 792)
                    pixels[row, round(axis - 120):round(axis + 120)] = 255
                    if row < 792:
                        start, end = (0, 430) if row < 470 or row >= 710 else (350, 430)
                        left, right = sorted((round(axis + side * start), round(axis + side * end)))
                        pixels[row, left:right] = 255

                result, _ = repair_spine(pixels, letter, master)
                mask = result >= 128
                self.assertEqual(ndimage.label(mask)[1], 1, "The bowl must remain attached to its stem.")
                self.assertEqual(ndimage.label(ndimage.binary_fill_holes(mask) & ~mask)[1], 1)
                np.testing.assert_array_equal(np.flatnonzero(mask.any(axis=1))[[0, -1]], (386, 937))


if __name__ == "__main__":
    unittest.main()
