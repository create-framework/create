"""`ui.slider` and `ui.checkbox`: value widgets that change a value in place
and return whether they changed it."""
from std.testing import (
    TestSuite,
    assert_almost_equal,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)

from create import *
from _input import next_frame, point_at, press, release

# The handle's centre runs from x = -100 to 100: the track, inset by the
# handle's radius of 10.
comptime _TRACK = Rectangle((0, 0), 220, 32)
comptime _BOX = Rectangle((0, -60), 200, 32)


def _slider(
    mut ui: UI,
    mut context: Context,
    mut value: Float64,
    step: Float64 = 0,
    min: Float64 = 0,
    max: Float64 = 1,
) raises -> Bool:
    var canvas = Canvas(300, 200)
    with ui.screen(context, canvas) as layer:
        if step > 0:
            layer.slider(value, min, max, _TRACK, step=step)
        else:
            layer.slider(value, min, max, _TRACK)
        return layer.changed()


def test_pressing_the_track_moves_the_handle_there() raises -> None:
    var ui = UI()
    var context = Context()
    var value = 0.0
    point_at(context, Point(50, 0))
    assert_false(_slider(ui, context, value))
    next_frame(context)
    press(context, Point(50, 0))
    assert_true(_slider(ui, context, value))
    assert_almost_equal(value, 0.75)


def test_a_drag_past_the_end_stops_at_the_end_and_keeps_going() raises -> None:
    var ui = UI()
    var context = Context()
    var value = 0.5
    point_at(context, Point(0, 0))
    _ = _slider(ui, context, value)
    next_frame(context)
    press(context, Point(0, 0))
    assert_false(_slider(ui, context, value))  # pressed where it already is
    next_frame(context)
    point_at(context, Point(400, 300))  # far past the end, off the track
    assert_true(_slider(ui, context, value))
    assert_equal(value, 1.0)
    next_frame(context)
    point_at(context, Point(500, 300))
    assert_false(_slider(ui, context, value))  # already at the end
    assert_true(ui.wants_mouse(context))
    next_frame(context)
    point_at(context, Point(-50, 300))  # still held: follows the pointer
    assert_true(_slider(ui, context, value))
    assert_almost_equal(value, 0.25)
    next_frame(context)
    release(context, Point(-50, 300))
    _ = _slider(ui, context, value)
    next_frame(context)
    point_at(context, Point(80, 0))
    assert_false(_slider(ui, context, value))  # let go: hovering moves nothing
    assert_almost_equal(value, 0.25)


def test_a_step_rounds_the_value() raises -> None:
    var ui = UI()
    var context = Context()
    var value = 0.0
    point_at(context, Point(13, 0))
    _ = _slider(ui, context, value, step=0.25)
    next_frame(context)
    press(context, Point(13, 0))  # 0.565, nearest step 0.5
    assert_true(_slider(ui, context, value, step=0.25))
    assert_almost_equal(value, 0.5)


def test_a_step_past_max_comes_back_inside_a_reversed_range() raises -> None:
    var ui = UI()
    var context = Context()
    var value = 10.0
    point_at(context, Point(105, 0))
    _ = _slider(ui, context, value, step=6, min=10, max=0)
    next_frame(context)
    press(context, Point(105, 0))  # past the end: 0, which rounds to -2
    assert_true(_slider(ui, context, value, step=6, min=10, max=0))
    assert_equal(value, 4.0)  # the last step inside the range


def test_a_step_of_zero_raises() raises -> None:
    var ui = UI()
    var context = Context()
    var canvas = Canvas(300, 200)
    var value = 0.5
    with ui.screen(context, canvas) as layer:
        with assert_raises(contains="step must be more than 0"):
            layer.slider(value, 0, 1, _TRACK, step=0)


def test_a_value_out_of_range_is_left_alone_until_dragged() raises -> None:
    var ui = UI()
    var context = Context()
    var value = 3.0
    point_at(context, Point(80, 0))
    assert_false(_slider(ui, context, value))
    next_frame(context)
    assert_false(_slider(ui, context, value))
    assert_equal(value, 3.0)


def _checkbox(
    mut ui: UI, mut context: Context, mut checked: Bool
) raises -> Bool:
    var canvas = Canvas(300, 200)
    with ui.screen(context, canvas) as layer:
        layer.checkbox("Sound", checked, _BOX)
        return layer.changed()


def test_a_click_anywhere_on_a_checkbox_switches_it() raises -> None:
    var ui = UI()
    var context = Context()
    var checked = False
    var on_label = _BOX.position + Vector(60.0, 0.0)
    point_at(context, on_label)
    assert_false(_checkbox(ui, context, checked))
    next_frame(context)
    press(context, on_label)
    release(context, on_label)
    assert_true(_checkbox(ui, context, checked))
    assert_true(checked)
    next_frame(context)
    assert_false(_checkbox(ui, context, checked))
    assert_true(checked)
    next_frame(context)
    press(context, on_label)
    release(context, on_label)
    assert_true(_checkbox(ui, context, checked))
    assert_false(checked)


def test_a_widget_ignores_the_pointer_while_another_is_held() raises -> None:
    var ui = UI()
    var context = Context()
    var value = 0.5
    var checked = False
    var canvas = Canvas(300, 200)
    var on_box = _BOX.position
    for frame in range(4):
        if frame == 1:
            next_frame(context)
            press(context, Point(0, 0))  # take hold of the slider
        elif frame == 2:
            next_frame(context)
            point_at(context, on_box)  # drag over the checkbox
        elif frame == 3:
            next_frame(context)
            release(context, on_box)  # and let go on it
        else:
            point_at(context, Point(0, 0))
        with ui.screen(context, canvas) as layer:
            layer.slider(value, 0, 1, _TRACK)
            layer.checkbox("Sound", checked, _BOX)
            assert_false(layer.changed())
    assert_false(checked)


def test_changed_reports_only_the_widget_called_last() raises -> None:
    var ui = UI()
    var context = Context()
    var canvas = Canvas(300, 200)
    var value = 0.0
    point_at(context, Point(50, 0))
    for frame in range(3):
        if frame > 0:
            next_frame(context)
        if frame == 1:
            press(context, Point(50, 0))
        with ui.screen(context, canvas) as layer:
            if frame != 1:
                assert_false(layer.changed())  # each frame starts afresh
            layer.slider(value, 0, 1, _TRACK)
            if frame == 1:
                assert_true(layer.changed())
            _ = layer.button("OK", _BOX)
            assert_false(layer.changed())


def _drawn(
    value: Float64,
    track: Style = Style(),
    handle: Style = Style(),
    handle_outline: Style = Style(),
) raises -> Canvas:
    """One frame of a slider at `value`, in the parts' styles, unsmoothed."""
    var ui = UI()
    var context = Context()
    var canvas = Canvas(300, 200, antialiasing=Antialiasing.OFF)
    var shown = value
    with ui.screen(context, canvas) as layer:
        layer.slider(
            shown,
            0,
            1,
            _TRACK,
            track=track,
            handle=handle,
            handle_outline=handle_outline,
        )
    return canvas^


def test_the_handles_diameter_is_its_stroke_thickness() raises -> None:
    # 40 across, so its centre is inset 20 from the track's end, at -90
    var canvas = _drawn(
        0,
        track=Style(stroke=Color.BLUE),
        handle=Style(stroke=Color.RED, stroke_thickness=40),
    )
    assert_equal(canvas.color_at((-90 + 18, 0)), Color.RED)
    assert_equal(canvas.color_at((-90 + 23, 0)), Color.BLUE)
    assert_equal(canvas.color_at((-90, 19)), Color.RED)


def test_a_bigger_handle_insets_the_track_further() raises -> None:
    var usual = _drawn(1, track=Style(stroke=Color.BLUE))
    var big = _drawn(
        1, track=Style(stroke=Color.BLUE), handle=Style(stroke_thickness=40)
    )
    assert_true(usual.color_at((-96, 0)) != Color.TRANSPARENT)
    assert_equal(big.color_at((-96, 0)), Color.TRANSPARENT)


def test_a_thick_track_thickens_the_active_track() raises -> None:
    var canvas = _drawn(1, track=Style(stroke_thickness=12))
    var primary = ColorScheme.light().primary
    assert_equal(canvas.color_at((-50, 5)), primary)  # under 6 from the middle


def test_a_square_cap_makes_a_square_handle() raises -> None:
    var round = _drawn(0, handle=Style(stroke=Color.RED))
    var square = _drawn(
        0, handle=Style(stroke=Color.RED, stroke_cap=StrokeCap.SQUARE)
    )
    var corner = Point(-100 + 9, 9)  # inside the square, outside the circle
    assert_true(round.color_at(corner) != Color.RED)
    assert_equal(square.color_at(corner), Color.RED)


def test_a_handle_outline_draws_a_ring_on_top() raises -> None:
    var canvas = _drawn(
        0,
        handle=Style(stroke=Color.RED),
        handle_outline=Style(stroke=Color.GREEN, stroke_thickness=3),
    )
    assert_equal(canvas.color_at((-100, 0)), Color.RED)
    assert_equal(canvas.color_at((-100 + 8.5, 0)), Color.GREEN)


def test_no_outline_unless_given() raises -> None:
    var canvas = _drawn(0, handle=Style(stroke=Color.RED))
    assert_equal(canvas.color_at((-100 + 8.5, 0)), Color.RED)


def test_a_handle_can_cast_a_shadow() raises -> None:
    var flat = _drawn(0.5, handle=Style(stroke=Color.RED))
    var lifted = _drawn(
        0.5,
        handle=Style(
            stroke=Color.RED,
            shadow=Color(0, 0, 0, 60),
            shadow_offset=Vector(0, -3),
            shadow_blur=12,
        ),
    )
    var below = Point(0, -13)  # under the handle, past the track
    assert_true(lifted.color_at(below) != flat.color_at(below))


def test_a_dragged_handle_is_tinted() raises -> None:
    var ui = UI()
    var context = Context()
    var value = 0.5
    var colors = List[Color]()
    point_at(context, Point(0, 0))
    for frame in range(2):
        if frame == 1:
            next_frame(context)
            press(context, Point(0, 0))
        var canvas = Canvas(300, 200, antialiasing=Antialiasing.OFF)
        with ui.screen(context, canvas) as layer:
            layer.slider(value, 0, 1, _TRACK, handle=Style(stroke=Color.RED))
        colors.append(canvas.color_at((0, 0)))
    assert_true(colors[1] != Color.RED)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
