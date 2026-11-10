"""`canvas.ellipse` and `Ellipse`: where the fill and the stroke land, that
the stroke is as thick all round, and that an ellipse clips like any region.

Offscreen 120 x 100 canvases (origin centred, y up), antialiasing off, read
back with `color_at`.
"""
from std.testing import TestSuite, assert_equal, assert_true

from create import *

comptime _FILL = Color(0x40, 0x80, 0xFF)


def _canvas() raises -> Canvas:
    var canvas = Canvas(120, 100, antialiasing=Antialiasing.OFF)
    canvas.fill(_FILL)
    canvas.stroke_enabled(False)
    return canvas^


def _inked(mut canvas: Canvas, p: Point2D) raises -> Bool:
    return canvas.color_at(p) != Color.TRANSPARENT


def test_fill_reaches_both_axes_and_no_further() raises -> None:
    var canvas = _canvas()
    canvas.ellipse((0, 0), 80, 40)
    assert_equal(canvas.color_at((0.5, 0.5)), _FILL)
    assert_true(_inked(canvas, (38.5, 0.5)), "inside the width")
    assert_true(not _inked(canvas, (41.5, 0.5)), "past the width")
    assert_true(_inked(canvas, (0.5, 18.5)), "inside the height")
    assert_true(not _inked(canvas, (0.5, 21.5)), "past the height")
    # Inside the bounds' corner but outside the curve.
    assert_true(not _inked(canvas, (36.5, 17.5)), "in the bounds' corner")


def test_draw_matches_the_named_method() raises -> None:
    var drawn = _canvas()
    var named = _canvas()
    drawn.stroke(Color.BLACK, 3)
    named.stroke(Color.BLACK, 3)
    drawn.draw(Ellipse((10.0, -5.0), 70.0, 30.0))
    named.ellipse((10.0, -5.0), 70.0, 30.0)
    var a = drawn.snapshot()
    var b = named.snapshot()
    for j in range(a.height()):
        for i in range(a.width()):
            assert_equal(a.pixel(i, j), b.pixel(i, j))


def test_stroke_is_as_thick_all_round() raises -> None:
    # A stroke 6 thick, inset: 6 deep along each axis and along the normal
    # in between, where a ring between the ellipse and one 6 smaller each
    # way would be thinner.
    var canvas = _canvas()
    canvas.fill_enabled(False)
    canvas.stroke(Color.BLACK, 6)
    canvas.ellipse((0, 0), 80, 40)
    assert_true(_inked(canvas, (36.5, 0.5)), "stroke along the width")
    assert_true(not _inked(canvas, (32.5, 0.5)), "inside the stroke, width")
    assert_true(_inked(canvas, (0.5, 16.5)), "stroke along the height")
    assert_true(not _inked(canvas, (0.5, 12.5)), "inside the stroke, height")
    # The point at 45 degrees round, and its inward normal.
    var on = Point2D(40.0 * cos(PI / 4.0), 20.0 * sin(PI / 4.0))
    var normal = Vector2D(on.x / 1600.0, on.y / 400.0).normalize()
    assert_true(_inked(canvas, on - normal * 5.2), "5.2 in, between axes")
    assert_true(not _inked(canvas, on - normal * 7.0), "7 in, between axes")


def test_outside_stroke_grows_the_ellipse() raises -> None:
    var canvas = _canvas()
    canvas.stroke(Color.BLACK, 6)
    canvas.stroke_alignment(StrokeAlign.OUTSIDE)
    canvas.ellipse((0, 0), 80, 40)
    assert_equal(canvas.color_at((38.5, 0.5)), _FILL)
    assert_equal(canvas.color_at((43.5, 0.5)), Color.BLACK)
    assert_true(not _inked(canvas, (47.5, 0.5)), "past the outside stroke")


def test_equal_axes_cover_the_circle() raises -> None:
    var round = _canvas()
    var circle = _canvas()
    round.ellipse((0, 0), 60, 60)
    circle.circle((0, 0), 30)
    var a = round.snapshot()
    var b = circle.snapshot()
    var differ = 0
    for j in range(a.height()):
        for i in range(a.width()):
            if a.pixel(i, j) != b.pixel(i, j):
                differ += 1
    # The flattened outline can only flip a few pixels along the rim.
    assert_true(differ <= 8, String(differ) + " pixels differ")


def test_flat_ellipse_draws_as_its_bounds() raises -> None:
    var flat = _canvas()
    var rect = _canvas()
    flat.stroke(Color.BLACK, 2)
    rect.stroke(Color.BLACK, 2)
    flat.ellipse((0, 0), 60, 0)
    rect.rectangle((0, 0), 60, 0)
    var a = flat.snapshot()
    var b = rect.snapshot()
    for j in range(a.height()):
        for i in range(a.width()):
            assert_equal(a.pixel(i, j), b.pixel(i, j))


def test_ellipse_clips() raises -> None:
    var canvas = _canvas()
    with canvas.clip(Ellipse((0, 0), 80, 40)):
        canvas.background(Color.RED)
    assert_equal(canvas.color_at((0.5, 0.5)), Color.RED)
    assert_equal(canvas.color_at((38.5, 0.5)), Color.RED)
    assert_true(not _inked(canvas, (36.5, 17.5)), "clipped off the corner")
    assert_true(not _inked(canvas, (0.5, 30.5)), "clipped off above")


def test_turned_ellipse_follows_the_transform() raises -> None:
    var canvas = _canvas()
    with canvas.transform(rotate(PI / 2.0)):
        canvas.ellipse((0, 0), 80, 40)
    assert_true(_inked(canvas, (0.5, 38.5)), "width turned upright")
    assert_true(not _inked(canvas, (30.5, 0.5)), "height turned sideways")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
