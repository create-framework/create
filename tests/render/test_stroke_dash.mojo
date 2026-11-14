"""`stroke_dash` breaks a stroke into dashes along its middle: the value
itself, how it reaches a command, the pattern walk, and where the dashes
land on each kind.

Scenes are drawn on offscreen canvases with antialiasing off, so a sample at
a pixel centre is exactly the stroke, the fill or nothing.
"""

from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)

from create import *
from create.render._dash import dash_path


def _canvas() raises -> Canvas:
    var canvas = Canvas(240, 120, antialiasing=Antialiasing.OFF)
    canvas.fill(Color.RED)
    canvas.stroke(Color.WHITE, 4)
    return canvas^


# The value.


def test_the_presets_and_patterns_print_as_written() raises -> None:
    assert_equal(String(StrokeDash.SOLID), "StrokeDash.SOLID")
    assert_equal(String(StrokeDash.DASHED), "StrokeDash.DASHED")
    assert_equal(String(StrokeDash.DOTTED), "StrokeDash.DOTTED")
    assert_equal(String(StrokeDash(12, 6)), "StrokeDash(12.0, 6.0)")
    assert_equal(
        String(StrokeDash(12, 4, 2, 4, offset=3)),
        "StrokeDash(12.0, 4.0, 2.0, 4.0, offset=3.0)",
    )
    assert_equal(
        String(StrokeDash.DASHED.with_offset(2)),
        "StrokeDash.DASHED.with_offset(2.0)",
    )


def test_equal_patterns_compare_equal() raises -> None:
    assert_true(StrokeDash(12, 6) == StrokeDash(12, 6))
    assert_true(StrokeDash(12, 6) != StrokeDash(12, 6, offset=1))
    assert_true(StrokeDash(12, 6) != StrokeDash(12, 6, 12, 6))
    assert_true(StrokeDash.DASHED != StrokeDash.DOTTED)
    assert_true(StrokeDash.SOLID == StrokeDash.SOLID)


def test_with_offset_returns_a_new_value() raises -> None:
    var dash = StrokeDash(12, 6)
    var moved = dash.with_offset(5)
    assert_equal(dash.offset(), 0.0)
    assert_equal(moved.offset(), 5.0)


def test_a_pattern_is_whole_pairs_and_at_most_four() raises -> None:
    with assert_raises(contains="even number"):
        _ = StrokeDash(12, 4, 2)
    with assert_raises(contains="at most 4"):
        _ = StrokeDash(1, 1, 1, 1, 1, 1, 1, 1, 1, 1)
    _ = StrokeDash(1, 1, 1, 1, 1, 1, 1, 1)


def test_a_pattern_of_no_length_is_solid() raises -> None:
    assert_true(StrokeDash.SOLID._is_solid())
    assert_true(StrokeDash(0, 0)._is_solid())
    assert_true(StrokeDash(-3, -3)._is_solid())
    assert_false(StrokeDash(0, 8)._is_solid())
    assert_false(StrokeDash.DASHED._is_solid())


def test_a_preset_resolves_against_the_thickness() raises -> None:
    var dashed = StrokeDash.DASHED.with_offset(1)._resolved(4)
    assert_equal(dashed, StrokeDash(12, 8, offset=1))
    assert_equal(StrokeDash.DOTTED._resolved(4), StrokeDash(0, 8))
    assert_equal(StrokeDash(5, 5)._resolved(4), StrokeDash(5, 5))


# Style and canvas.


def test_the_style_starts_solid_and_takes_a_dash() raises -> None:
    assert_equal(Style().stroke_dash, StrokeDash.SOLID)
    var style = Style(stroke_dash=StrokeDash.DASHED)
    assert_equal(style.stroke_dash, StrokeDash.DASHED)
    assert_true("stroke_dash=StrokeDash.DASHED" in String(style))


def test_naming_a_dash_does_not_switch_the_stroke_on() raises -> None:
    var style = Style(stroke_enabled=False, stroke_dash=StrokeDash.DASHED)
    assert_false(style.stroke_enabled)


def test_a_command_records_a_preset_as_lengths() raises -> None:
    var paint = Style(
        stroke_thickness=3, stroke_dash=StrokeDash.DASHED
    )._paint()
    assert_equal(paint.stroke_dash, StrokeDash(9, 6))
    assert_equal(paint.stroke_cap, StrokeCap.BUTT)


def test_dotted_is_round_whatever_the_cap() raises -> None:
    var paint = Style(
        stroke_dash=StrokeDash.DOTTED, stroke_cap=StrokeCap.SQUARE
    )._paint()
    assert_equal(paint.stroke_cap, StrokeCap.ROUND)


def test_a_style_block_scopes_the_dash() raises -> None:
    var canvas = _canvas()
    with canvas.style(stroke_dash=StrokeDash(20, 20)):
        canvas.line((-100, 0), (100, 0))
    canvas.line((-100, 30), (100, 30))
    assert_equal(canvas.color_at((-70, 0)), Color.TRANSPARENT)
    assert_equal(canvas.color_at((-70, 30)), Color.WHITE)


# The pattern walk.


def test_a_line_is_cut_into_its_dashes() raises -> None:
    var pieces = dash_path(
        [Point2D(0, 0), Point2D(100, 0)],
        False,
        [10.0, 10.0],
        0.0,
        2.0,
        StrokeCap.BUTT,
        Vector2D(1, 0),
    )
    # Five dashes, a quad each: [0, 10], [20, 30], ... [80, 90].
    assert_equal(len(pieces.quads), 20)
    assert_equal(pieces.quads[0].x, 0.0)
    assert_equal(pieces.quads[1].x, 10.0)
    assert_equal(pieces.quads[16].x, 80.0)


def test_the_offset_starts_inside_the_pattern() raises -> None:
    var pieces = dash_path(
        [Point2D(0, 0), Point2D(100, 0)],
        False,
        [10.0, 10.0],
        5.0,
        2.0,
        StrokeCap.BUTT,
        Vector2D(1, 0),
    )
    # [0, 5], [15, 25], ... [95, 100].
    assert_equal(len(pieces.quads), 24)
    assert_equal(pieces.quads[1].x, 5.0)
    assert_equal(pieces.quads[4].x, 15.0)


def test_a_negative_offset_wraps() raises -> None:
    var forward = dash_path(
        [Point2D(0, 0), Point2D(100, 0)],
        False,
        [10.0, 10.0],
        15.0,
        2.0,
        StrokeCap.BUTT,
        Vector2D(1, 0),
    )
    var back = dash_path(
        [Point2D(0, 0), Point2D(100, 0)],
        False,
        [10.0, 10.0],
        -5.0,
        2.0,
        StrokeCap.BUTT,
        Vector2D(1, 0),
    )
    assert_equal(len(forward.quads), len(back.quads))
    for i in range(len(back.quads)):
        assert_equal(forward.quads[i], back.quads[i])


def test_a_dash_round_a_corner_is_one_mitred_strip() raises -> None:
    var pieces = dash_path(
        [Point2D(0, 0), Point2D(10, 0), Point2D(10, 10)],
        False,
        [15.0, 100.0],
        0.0,
        2.0,
        StrokeCap.BUTT,
        Vector2D(1, 0),
    )
    # Two quads sharing the mitred corner (11, -1)-(9, 1).
    assert_equal(len(pieces.quads), 8)
    assert_equal(pieces.quads[1], pieces.quads[4])
    assert_equal(pieces.quads[2], pieces.quads[7])


def test_dots_are_dashes_of_no_length() raises -> None:
    var round = dash_path(
        [Point2D(0, 0), Point2D(40, 0)],
        False,
        [0.0, 10.0],
        0.0,
        4.0,
        StrokeCap.ROUND,
        Vector2D(1, 0),
    )
    # At 0, 10, 20, 30 and 40.
    assert_equal(len(round.caps), 5)
    var butt = dash_path(
        [Point2D(0, 0), Point2D(40, 0)],
        False,
        [0.0, 10.0],
        0.0,
        4.0,
        StrokeCap.BUTT,
        Vector2D(1, 0),
    )
    assert_equal(len(butt.quads) + len(butt.caps), 0)


def test_a_square_dot_turns_with_the_path() raises -> None:
    var pieces = dash_path(
        [Point2D(0, 0), Point2D(0, 40)],
        False,
        [0.0, 100.0],
        0.0,
        4.0,
        StrokeCap.SQUARE,
        Vector2D(1, 0),
    )
    assert_equal(len(pieces.quads), 4)
    # Lined up with the path, which runs up y: its first corner is behind
    # and to the right of the dot.
    assert_equal(pieces.quads[0], Point2D(2, -2))


def test_a_pattern_too_fine_to_see_is_solid() raises -> None:
    var pieces = dash_path(
        [Point2D(0, 0), Point2D(100, 0)],
        False,
        [0.25, 0.25],
        0.0,
        2.0,
        StrokeCap.BUTT,
        Vector2D(1, 0),
    )
    assert_equal(len(pieces.quads), 4)


def test_a_closed_path_runs_back_to_its_start() raises -> None:
    var pieces = dash_path(
        [Point2D(0, 0), Point2D(0, -10), Point2D(10, -10), Point2D(10, 0)],
        True,
        [5.0, 5.0],
        0.0,
        2.0,
        StrokeCap.BUTT,
        Vector2D(1, 0),
    )
    # A dash on each half of each of the four sides.
    assert_equal(len(pieces.quads), 16)


# Where the dashes land.


def test_a_dashed_line_leaves_gaps() raises -> None:
    var canvas = _canvas()
    canvas.stroke_dash(StrokeDash(20, 20))
    canvas.line((-100, 0), (100, 0))
    assert_equal(canvas.color_at((-90, 0)), Color.WHITE)
    assert_equal(canvas.color_at((-70, 0)), Color.TRANSPARENT)
    assert_equal(canvas.color_at((-50, 0)), Color.WHITE)


def test_the_presets_scale_with_the_thickness() raises -> None:
    var canvas = _canvas()
    canvas.stroke_dash(StrokeDash.DASHED)
    # Thickness 4: 12 on, 8 off from x = -100.
    canvas.line((-100, 0), (100, 0))
    canvas.stroke(thickness=8)
    # Thickness 8: 24 on, 16 off.
    canvas.line((-100, 30), (100, 30))
    assert_equal(canvas.color_at((-86, 0)), Color.TRANSPARENT)
    assert_equal(canvas.color_at((-86, 30)), Color.WHITE)
    assert_equal(canvas.color_at((-70, 30)), Color.TRANSPARENT)


def test_dotted_draws_round_dots_under_a_butt_cap() raises -> None:
    var canvas = _canvas()
    canvas.stroke(thickness=6)
    canvas.stroke_dash(StrokeDash.DOTTED)
    # Dots 6 wide every 12 units from x = -100.
    canvas.line((-100, 0), (100, 0))
    assert_equal(canvas.color_at((-88, 0)), Color.WHITE)
    assert_equal(canvas.color_at((-94, 0)), Color.TRANSPARENT)
    # Round: a dot's corner is empty.
    assert_equal(canvas.color_at((-85.5, 2.5)), Color.TRANSPARENT)


def test_lengths_scale_with_the_transform() raises -> None:
    var canvas = _canvas()
    canvas.stroke_dash(StrokeDash(10, 10))
    with canvas.transform(scale(2)):
        canvas.line((-50, 0), (50, 0))
    assert_equal(canvas.color_at((-90, 0)), Color.WHITE)
    assert_equal(canvas.color_at((-70, 0)), Color.TRANSPARENT)


def test_a_rectangle_starts_at_its_top_left_running_down() raises -> None:
    var canvas = _canvas()
    canvas.stroke_dash(StrokeDash(10, 10))
    # 80 square, stroke 4 inside: its middle runs down x = -38 from y = 38.
    canvas.rectangle((0, 0), 80, 80)
    assert_equal(canvas.color_at((-38, 33)), Color.WHITE)
    assert_equal(canvas.color_at((-38, 23)), Color.TRANSPARENT)
    assert_equal(canvas.color_at((-38, 13)), Color.WHITE)
    # The fill stops at the stroke's inner edge, gaps or not.
    assert_equal(canvas.color_at((-35, 23)), Color.RED)


def test_outside_puts_the_fill_under_the_gaps() raises -> None:
    var canvas = _canvas()
    canvas.stroke_dash(StrokeDash(10, 10))
    canvas.stroke_alignment(StrokeAlign.OUTSIDE)
    canvas.rectangle((0, 0), 80, 80)
    # The middle runs down x = -42 from y = 42.
    assert_equal(canvas.color_at((-42, 37)), Color.WHITE)
    assert_equal(canvas.color_at((-42, 27)), Color.TRANSPARENT)
    assert_equal(canvas.color_at((-38, 27)), Color.RED)


def test_a_circle_starts_on_the_right_running_counter_clockwise() raises -> (
    None
):
    var canvas = _canvas()
    canvas.stroke_dash(StrokeDash(10, 100))
    # Radius 40, stroke 4 inside: the middle is the circle of radius 38.
    canvas.circle((0, 0), 40)
    assert_equal(canvas.color_at((38, 4)), Color.WHITE)
    assert_equal(canvas.color_at((38, -4)), Color.TRANSPARENT)


def test_a_triangle_starts_at_its_first_corner() raises -> None:
    var canvas = _canvas()
    canvas.fill_enabled(False)
    canvas.stroke_dash(StrokeDash(10, 1000))
    canvas.triangle((-50, -40), (50, -40), (0, 40))
    # Along the bottom from the left corner, 4 thick inside it.
    assert_equal(canvas.color_at((-40, -38)), Color.WHITE)
    assert_equal(canvas.color_at((20, -38)), Color.TRANSPARENT)


def test_a_sector_starts_at_its_tip() raises -> None:
    var canvas = _canvas()
    canvas.fill_enabled(False)
    canvas.stroke_dash(StrokeDash(15, 1000))
    canvas.sector((0, -50), 100, 0.0, 1.0)
    # Out along the start radius (the +x axis), 4 thick inside it.
    assert_equal(canvas.color_at((10, -48)), Color.WHITE)
    assert_equal(canvas.color_at((60, -48)), Color.TRANSPARENT)


def test_a_polygon_starts_at_its_first_vertex() raises -> None:
    var canvas = _canvas()
    canvas.fill_enabled(False)
    canvas.stroke_dash(StrokeDash(20, 1000))
    canvas.polygon((40, 40), (-40, 40), (-40, -40), (40, -40))
    # Leftwards along the top from (40, 40), 4 thick inside it.
    assert_equal(canvas.color_at((30, 38)), Color.WHITE)
    assert_equal(canvas.color_at((-20, 38)), Color.TRANSPARENT)


def test_a_dashed_region_casts_a_dashed_ring() raises -> None:
    var canvas = _canvas()
    canvas.fill_enabled(False)
    canvas.stroke_dash(StrokeDash(10, 10))
    canvas.shadow(Color.BLUE, Vector2D(0, -20), blur=0)
    canvas.line((-100, 30), (100, 30))
    assert_equal(canvas.color_at((-95, 10)), Color.BLUE)
    assert_equal(canvas.color_at((-85, 10)), Color.TRANSPARENT)


def test_a_filled_dashed_shape_casts_its_silhouette() raises -> None:
    var canvas = _canvas()
    canvas.stroke_dash(StrokeDash(10, 10))
    canvas.shadow(Color.BLUE, Vector2D(100, 0), blur=0)
    canvas.rectangle((-60, 0), 80, 80)
    # Under a gap of the stroke, offset by the shadow's 100.
    assert_equal(canvas.color_at((2, 23)), Color.BLUE)


def test_a_blurred_shadow_of_a_dashed_circle_renders() raises -> None:
    var canvas = _canvas()
    canvas.fill_enabled(False)
    canvas.stroke_dash(StrokeDash.DOTTED)
    canvas.shadow(Color.BLACK, Vector2D(0, 0), blur=6)
    canvas.circle((0, 0), 40)
    # The blur reaches a little past the ring.
    assert_true(canvas.color_at((44, 0)).a > 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
