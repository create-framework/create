"""`Slider` as a value: pressed and dragged to set its value, which
`changed()` reports, and drawn in a style for each part."""
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


def _canvas() raises -> Canvas:
    return Canvas(300, 200, antialiasing=Antialiasing.OFF)


def _frame(mut slider: Slider, mut context: Context) raises -> Bool:
    """Update `slider` in a new frame: whether it changed."""
    next_frame(context)
    var canvas = _canvas()
    slider.update(context, canvas)
    return slider.changed()


def test_pressing_the_track_moves_the_handle_there() raises -> None:
    var slider = Slider(0, 0, 1, _TRACK)
    var context = Context()
    var canvas = _canvas()
    point_at(context, (50, 0))
    assert_false(_frame(slider, context))
    press(context, (50, 0))
    slider.update(context, canvas)
    assert_true(slider.changed())
    assert_almost_equal(slider.value, 0.75)


def test_a_drag_past_the_end_stops_at_the_end_and_keeps_going() raises -> None:
    var slider = Slider(0.5, 0, 1, _TRACK)
    var context = Context()
    var canvas = _canvas()
    point_at(context, (0, 0))
    press(context, (0, 0))
    slider.update(context, canvas)
    assert_false(slider.changed())  # pressed where it already is
    point_at(context, (400, 300))  # far past the end, off the track
    assert_true(_frame(slider, context))
    assert_equal(slider.value, 1.0)
    point_at(context, (500, 300))
    assert_false(_frame(slider, context))  # already at the end
    assert_true(slider.down())
    point_at(context, (-50, 300))  # still held: follows the pointer
    assert_true(_frame(slider, context))
    assert_almost_equal(slider.value, 0.25)
    next_frame(context)
    release(context, (-50, 300))
    slider.update(context, canvas)
    point_at(context, (80, 0))
    assert_false(_frame(slider, context))  # let go: hovering moves nothing
    assert_almost_equal(slider.value, 0.25)


def test_a_release_off_the_track_moves_the_handle_there() raises -> None:
    var slider = Slider(0.5, 0, 1, _TRACK)
    var context = Context()
    var canvas = _canvas()
    point_at(context, (0, 0))
    press(context, (0, 0))
    slider.update(context, canvas)
    next_frame(context)
    release(context, (-50, 300))  # moved and let go off the track
    slider.update(context, canvas)
    assert_true(slider.changed())
    assert_almost_equal(slider.value, 0.25)


def test_a_step_rounds_the_value() raises -> None:
    var slider = Slider(0, 0, 1, _TRACK, step=0.25)
    var context = Context()
    var canvas = _canvas()
    point_at(context, (13, 0))
    press(context, (13, 0))  # 0.565, nearest step 0.5
    slider.update(context, canvas)
    assert_almost_equal(slider.value, 0.5)


def test_a_step_past_the_maximum_comes_back_inside() raises -> None:
    var slider = Slider(10, 10, 0, _TRACK, step=6)
    var context = Context()
    var canvas = _canvas()
    point_at(context, (105, 0))
    press(context, (105, 0))  # past the end: 0, which rounds to -2
    slider.update(context, canvas)
    assert_equal(slider.value, 4.0)  # the last step inside the range


def test_a_step_of_zero_raises() raises -> None:
    var slider = Slider(0.5, 0, 1, _TRACK, step=0)
    var context = Context()
    var canvas = _canvas()
    with assert_raises(contains="step must be more than 0"):
        slider.update(context, canvas)


def test_a_value_out_of_range_is_left_alone_until_dragged() raises -> None:
    var slider = Slider(3, 0, 1, _TRACK)
    var context = Context()
    point_at(context, (80, 0))
    assert_false(_frame(slider, context))
    assert_false(_frame(slider, context))
    assert_equal(slider.value, 3.0)


def test_a_disabled_slider_cannot_be_dragged() raises -> None:
    var slider = Slider(0.5, 0, 1, _TRACK, enabled=False)
    var context = Context()
    var canvas = _canvas()
    point_at(context, (50, 0))
    press(context, (50, 0))
    slider.update(context, canvas)
    assert_false(slider.changed())
    assert_equal(slider.value, 0.5)


def _drawn(
    value: Float64,
    track: Style = Style(),
    handle: Style = Style(),
    handle_outline: Style = Style(),
) raises -> Canvas:
    """One frame of a slider at `value`, the pointer away from it."""
    var slider = Slider(
        value,
        0,
        1,
        _TRACK,
        track=track,
        handle=handle,
        handle_outline=handle_outline,
    )
    var context = Context()
    point_at(context, (140, 90))
    var canvas = _canvas()
    slider.update(context, canvas)
    canvas.draw(slider)
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
    var plain = _drawn(0, handle=Style(stroke=Color.RED))
    assert_equal(plain.color_at((-100 + 8.5, 0)), Color.RED)


def test_a_dragged_handle_is_tinted() raises -> None:
    var slider = Slider(0.5, 0, 1, _TRACK, handle=Style(stroke=Color.RED))
    var context = Context()
    point_at(context, (0, 0))
    press(context, (0, 0))
    var canvas = _canvas()
    slider.update(context, canvas)
    canvas.draw(slider)
    assert_true(canvas.color_at((0, 0)) != Color.RED)


def test_it_draws_as_the_ui_slider_does() raises -> None:
    var context = Context()
    point_at(context, (140, 90))
    var slider = Slider(0.3, 0, 1, _TRACK)
    var drawn = _canvas()
    slider.update(context, drawn)
    drawn.draw(slider)
    var ui = UI()
    var called = _canvas()
    var value = 0.3
    with ui.screen(context, called) as layer:
        layer.slider(value, 0, 1, _TRACK)
    var a = drawn.snapshot()
    var b = called.snapshot()
    for j in range(a.height()):
        for i in range(a.width()):
            assert_equal(a.pixel(i, j), b.pixel(i, j))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
