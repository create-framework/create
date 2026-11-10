"""`canvas.capsule` and `Capsule`: where the fill and the stroke land along
the sides and round the ends, the gradient's box, and that a capsule clips
like any region.

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


def test_fill_reaches_the_sides_and_ends() raises -> None:
    var canvas = _canvas()
    canvas.capsule((-30, 0), (30, 0), 15)
    assert_equal(canvas.color_at((0.5, 0.5)), _FILL)
    assert_true(_inked(canvas, (0.5, 13.5)), "inside the side")
    assert_true(not _inked(canvas, (0.5, 16.5)), "past the side")
    assert_true(_inked(canvas, (43.5, 0.5)), "inside the round end")
    assert_true(not _inked(canvas, (46.5, 0.5)), "past the round end")
    # In the bounds' corner but outside the round end.
    assert_true(not _inked(canvas, (42.5, 12.5)), "in the bounds' corner")
    assert_true(_inked(canvas, (-40.5, 7.5)), "inside the other end")


def test_draw_matches_the_named_method() raises -> None:
    var drawn = _canvas()
    var named = _canvas()
    drawn.stroke(Color.BLACK, 3)
    named.stroke(Color.BLACK, 3)
    drawn.draw(Capsule((-20.0, -10.0), (25.0, 15.0), 12.0))
    named.capsule((-20.0, -10.0), (25.0, 15.0), 12.0)
    var a = drawn.snapshot()
    var b = named.snapshot()
    for j in range(a.height()):
        for i in range(a.width()):
            assert_equal(a.pixel(i, j), b.pixel(i, j))


def test_stroke_is_inset_and_as_thick_round_the_ends() raises -> None:
    var canvas = _canvas()
    canvas.fill_enabled(False)
    canvas.stroke(Color.BLACK, 6)
    canvas.capsule((-30, 0), (30, 0), 15)
    assert_true(_inked(canvas, (0.5, 11.5)), "stroke along the side")
    assert_true(not _inked(canvas, (0.5, 7.5)), "inside the stroke, side")
    # Round the end, 45 degrees up from the axis.
    var outward = Vector2D.from_angle(PI / 4.0, 1.0)
    var tip = Point2D(30.0, 0.0)
    assert_true(_inked(canvas, tip + outward * 11.5), "stroke round the end")
    assert_true(not _inked(canvas, tip + outward * 7.5), "inside it, the end")


def test_outside_stroke_grows_it() raises -> None:
    var canvas = _canvas()
    canvas.stroke(Color.BLACK, 6)
    canvas.stroke_alignment(StrokeAlign.OUTSIDE)
    canvas.capsule((-30, 0), (30, 0), 15)
    assert_equal(canvas.color_at((0.5, 13.5)), _FILL)
    assert_equal(canvas.color_at((0.5, 18.5)), Color.BLACK)
    assert_true(not _inked(canvas, (0.5, 22.5)), "past the outside stroke")


def test_gradient_spans_its_bounds() raises -> None:
    # Left to right over the bounds, x -45..45: red at the round end's tip,
    # blue at the other.
    var canvas = _canvas()
    canvas.fill(
        Gradient.linear(Color.RED, Color.BLUE, direction=Vector2D.RIGHT)
    )
    canvas.capsule((-30, 0), (30, 0), 15)
    var left = canvas.color_at((-44.5, 0.5))
    var right = canvas.color_at((44.5, 0.5))
    assert_true(left.r > 245 and left.b < 10, String(left))
    assert_true(right.b > 245 and right.r < 10, String(right))


def test_a_point_capsule_covers_its_circle() raises -> None:
    var dot = _canvas()
    var circle = _canvas()
    dot.capsule((5, 5), (5, 5), 25)
    circle.circle((5, 5), 25)
    var a = dot.snapshot()
    var b = circle.snapshot()
    # The flattened ends sit a fraction of a pixel inside the true circle,
    # so pixels may differ only along its rim: centre (65, 45) in image
    # coordinates, radius 25.
    for j in range(a.height()):
        for i in range(a.width()):
            if a.pixel(i, j) != b.pixel(i, j):
                var d = Point2D(Float64(i) + 0.5, Float64(j) + 0.5).distance(
                    (65.0, 45.0)
                )
                assert_true(
                    d > 24.0 and d < 26.0,
                    "differs off the rim at " + String(i) + ", " + String(j),
                )


def test_zero_radius_draws_nothing() raises -> None:
    var canvas = _canvas()
    canvas.stroke(Color.BLACK, 4)
    canvas.capsule((-30, 0), (30, 0), 0)
    assert_true(not _inked(canvas, (0.5, 0.5)), "no inside to fill or stroke")


def test_capsule_clips() raises -> None:
    var canvas = _canvas()
    with canvas.clip(Capsule((-30, 0), (30, 0), 15)):
        canvas.background(Color.RED)
    assert_equal(canvas.color_at((0.5, 0.5)), Color.RED)
    assert_equal(canvas.color_at((43.5, 0.5)), Color.RED)
    assert_true(not _inked(canvas, (42.5, 12.5)), "clipped off the corner")
    assert_true(not _inked(canvas, (0.5, 20.5)), "clipped off above")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
