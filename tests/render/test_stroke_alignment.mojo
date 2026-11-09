"""`stroke_alignment` moves a region's stroke inside its edge, centred on it
or around it, and the fill meets the stroke's inner edge.

Each scene is a 40-unit shape at the origin of a 100-unit offscreen canvas,
its edge crossing the +x axis at x = 20, filled red and stroked white 6
thick with antialiasing off, so every sample at a pixel centre is exact.
"""

from std.testing import TestSuite, assert_equal

from create import *

comptime _RECT = 0
comptime _ROUNDED_RECT = 1
comptime _CIRCLE = 2
comptime _SECTOR = 3
comptime _POLYGON = 4
comptime _TRIANGLE = 5
comptime _ROUNDED_TRIANGLE = 6
comptime _KINDS = 7


def _shape_canvas(kind: Int, alignment: StrokeAlign) raises -> Canvas:
    var canvas = Canvas(100, 100, antialiasing=Antialiasing.OFF)
    canvas.fill(Color.RED)
    canvas.stroke(Color.WHITE, 6)
    canvas.stroke_alignment(alignment)
    if kind == _RECT:
        canvas.rectangle((0, 0), 40, 40)
    elif kind == _ROUNDED_RECT:
        canvas.rectangle((0, 0), 40, 40, corner_radius=8)
    elif kind == _CIRCLE:
        canvas.circle((0, 0), 20)
    elif kind == _SECTOR:
        canvas.sector((0, 0), 20, -0.5, 1.0)
    elif kind == _POLYGON:
        canvas.polygon((-20, -20), (20, -20), (20, 20), (-20, 20))
    elif kind == _TRIANGLE:
        canvas.triangle((20, -20), (20, 20), (-20, 0))
    else:
        canvas.triangle((20, -20), (20, 20), (-20, 0), corner_radius=8)
    return canvas^


def _name(kind: Int) -> String:
    var names: List[String] = [
        "rectangle",
        "rounded rectangle",
        "circle",
        "sector",
        "polygon",
        "triangle",
        "rounded triangle",
    ]
    return names[kind]


def _check_band(
    kind: Int, alignment: StrokeAlign, inner: Float64, outer: Float64
) raises:
    """The stroke runs from `inner` to `outer` along +x, fill inside it and
    nothing outside."""
    var canvas = _shape_canvas(kind, alignment)
    var name = _name(kind) + " " + String(alignment)
    assert_equal(canvas.color_at((inner - 0.5, 0)), Color.RED, name + ": fill")
    assert_equal(
        canvas.color_at((inner + 0.5, 0)), Color.WHITE, name + ": stroke in"
    )
    assert_equal(
        canvas.color_at((outer - 0.5, 0)), Color.WHITE, name + ": stroke out"
    )
    assert_equal(
        canvas.color_at((outer + 0.5, 0)),
        Color.TRANSPARENT,
        name + ": outside",
    )


def test_inside_keeps_the_stroke_within_the_edge() raises -> None:
    for kind in range(_KINDS):
        _check_band(kind, StrokeAlign.INSIDE, 14, 20)


def test_center_straddles_the_edge() raises -> None:
    for kind in range(_KINDS):
        _check_band(kind, StrokeAlign.CENTER, 17, 23)


def test_outside_leaves_the_whole_shape_to_the_fill() raises -> None:
    for kind in range(_KINDS):
        _check_band(kind, StrokeAlign.OUTSIDE, 20, 26)


def test_a_sharp_rectangle_keeps_its_corner_outside() raises -> None:
    var canvas = _shape_canvas(_RECT, StrokeAlign.OUTSIDE)
    assert_equal(canvas.color_at((25.5, 25.5)), Color.WHITE)


def test_a_rounded_rectangle_rounds_its_outside_stroke() raises -> None:
    # The corner's centre is (12, 12) and the stroke's outer radius 8 + 6.
    var canvas = _shape_canvas(_ROUNDED_RECT, StrokeAlign.OUTSIDE)
    assert_equal(canvas.color_at((25.5, 25.5)), Color.TRANSPARENT)
    assert_equal(canvas.color_at((21.5, 21.5)), Color.WHITE)


def test_alignment_leaves_a_stroke_off_shape_alone() raises -> None:
    var canvas = Canvas(100, 100, antialiasing=Antialiasing.OFF)
    canvas.fill(Color.RED)
    canvas.stroke_enabled(False)
    canvas.stroke_alignment(StrokeAlign.OUTSIDE)
    canvas.rectangle((0, 0), 40, 40)
    assert_equal(canvas.color_at((19.5, 0)), Color.RED)
    assert_equal(canvas.color_at((20.5, 0)), Color.TRANSPARENT)


def _gradient_at(
    kind: Int, alignment: StrokeAlign, position: Point2D
) raises -> Color:
    var canvas = Canvas(100, 100, antialiasing=Antialiasing.OFF)
    canvas.fill(
        Gradient.linear(Color.RED, Color.BLUE, direction=Vector2D.RIGHT)
    )
    canvas.stroke(Color.WHITE, 6)
    canvas.stroke_alignment(alignment)
    if kind == _RECT:
        canvas.rectangle((0, 0), 40, 40)
    elif kind == _CIRCLE:
        canvas.circle((0, 0), 20)
    else:
        canvas.triangle((20, -20), (20, 20), (-20, 0))
    return canvas.color_at(position)


def test_a_gradient_stays_where_the_shape_is() raises -> None:
    # Each probe is in the fill under both alignments: the triangle's
    # slanted edges come within 6.93 of the leftmost, past its 6 stroke.
    for kind in [_RECT, _CIRCLE, _TRIANGLE]:
        for i in range(3):
            var x = -4.5 + 7.0 * Float64(i)
            assert_equal(
                _gradient_at(kind, StrokeAlign.OUTSIDE, Point2D(x, 0)),
                _gradient_at(kind, StrokeAlign.INSIDE, Point2D(x, 0)),
            )


def _ring_shadow(alignment: StrokeAlign) raises -> Canvas:
    # A stroke-only rectangle with x from -50 to -10, its hard shadow 50
    # to the right: from 0 to 40, before alignment.
    var canvas = Canvas(200, 100, antialiasing=Antialiasing.OFF)
    canvas.fill_enabled(False)
    canvas.stroke(Color.WHITE, 6)
    canvas.stroke_alignment(alignment)
    canvas.shadow(color=Color.GREEN, offset=Vector2D(50, 0), blur=0)
    canvas.rectangle((-30, 0), 40, 40)
    return canvas^


def test_an_outside_stroke_casts_its_ring_further_out() raises -> None:
    var inside = _ring_shadow(StrokeAlign.INSIDE)
    assert_equal(inside.color_at((39.5, 0)), Color.GREEN)
    assert_equal(inside.color_at((40.5, 0)), Color.TRANSPARENT)
    var outside = _ring_shadow(StrokeAlign.OUTSIDE)
    assert_equal(outside.color_at((45.5, 0)), Color.GREEN)
    assert_equal(outside.color_at((46.5, 0)), Color.TRANSPARENT)
    assert_equal(outside.color_at((39.5, 0)), Color.TRANSPARENT)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
