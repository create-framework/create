"""`ui.slider` and `ui.checkbox`: value widgets that change a value in place
and return whether they changed it."""
from std.testing import (
    TestSuite,
    assert_almost_equal,
    assert_equal,
    assert_false,
    assert_true,
)

from create import *
from _input import next_frame, point_at, press, release

# The handle's centre runs from x = -100 to 100: the track, inset by the
# handle's radius of 10.
comptime _TRACK = Rectangle((0, 0), 220, 32)
comptime _BOX = Rectangle((0, -60), 200, 32)


def _slider(
    mut ui: UI, mut context: Context, mut value: Float64, step: Float64 = 0
) raises -> Bool:
    var canvas = Canvas(300, 200)
    with ui.screen(context, canvas) as layer:
        if step > 0:
            layer.slider(value, 0, 1, _TRACK, step=step)
        else:
            layer.slider(value, 0, 1, _TRACK)
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
    assert_true(ui.wants_mouse())
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


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
