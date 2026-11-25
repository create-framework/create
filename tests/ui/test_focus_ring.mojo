"""Focus rings: drawn around a widget focused from the keyboard or code,
following its shape, and not after a click."""
from std.testing import TestSuite, assert_equal, assert_false, assert_true

from create import *
from create.ui.ui import _ImmediateUI
from _input import next_frame, point_at, press, press_key, release

# 100 x 40 with round ends: the ring, 2 away and 3 thick, runs from x = 52
# to 55 on the right, and from y = 22 to 25 on top.
comptime _A = Rectangle((0, 0), 100, 40)


def _frame(mut ui: _ImmediateUI, mut context: Context) raises -> Canvas:
    var canvas = Canvas(200, 100, antialiasing=Antialiasing.OFF)
    canvas.background(Color.WHITE)
    with ui.screen(context, canvas) as layer:
        _ = layer.button("OK", _A)
    return canvas^


def test_tab_shows_a_ring_around_the_button() raises -> None:
    var ui = _ImmediateUI()
    var context = Context()
    _ = _frame(ui, context)
    next_frame(context)
    press_key(context, Key.TAB)
    var canvas = _frame(ui, context)
    var ring = ColorScheme.light().secondary
    assert_equal(canvas.color_at((53.5, 0)), ring)  # right of the round end
    assert_equal(canvas.color_at((0, 23.5)), ring)  # above the straight top
    assert_equal(canvas.color_at((51, 0)), Color.WHITE)  # the gap
    assert_equal(canvas.color_at((57, 0)), Color.WHITE)  # outside it


def test_the_ring_follows_the_round_end() raises -> None:
    var ui = _ImmediateUI()
    var context = Context()
    _ = _frame(ui, context)
    next_frame(context)
    press_key(context, Key.TAB)
    var canvas = _frame(ui, context)
    # the corner of a square ring would be here; a round one leaves it empty
    assert_equal(canvas.color_at((53.5, 23.5)), Color.WHITE)


def test_a_click_shows_no_ring() raises -> None:
    var ui = _ImmediateUI()
    var context = Context()
    point_at(context, _A.position)
    _ = _frame(ui, context)
    next_frame(context)
    press(context, _A.position)
    release(context, _A.position)
    var canvas = _frame(ui, context)
    assert_true(Bool(ui._focused))
    assert_equal(canvas.color_at((53.5, 0)), Color.WHITE)


def test_a_ring_is_drawn_over_a_neighbour() raises -> None:
    var ui = _ImmediateUI()
    var context = Context()
    var canvas = Canvas(200, 100, antialiasing=Antialiasing.OFF)
    for frame in range(2):
        if frame == 1:
            next_frame(context)
            press_key(context, Key.TAB)
        canvas = Canvas(200, 100, antialiasing=Antialiasing.OFF)
        with ui.screen(context, canvas) as layer:
            _ = layer.button("OK", _A)
            # a neighbour drawn later, under where the ring goes
            layer.draw(Rectangle((54, 0), 10, 10), Style(fill=Color.RED))
    assert_equal(canvas.color_at((53.5, 0)), ColorScheme.light().secondary)


def test_the_ui_can_change_the_ring() raises -> None:
    var ui = _ImmediateUI()
    var context = Context()
    var ring = FocusRing()
    ring.color = Color.RED
    ui.focus_ring(ring)
    var canvas = Canvas(200, 100, antialiasing=Antialiasing.OFF)
    for frame in range(2):
        if frame == 1:
            next_frame(context)
            press_key(context, Key.TAB)
        canvas = Canvas(200, 100, antialiasing=Antialiasing.OFF)
        with ui.screen(context, canvas) as layer:
            _ = layer.button("OK", _A)
    assert_equal(canvas.color_at((53.5, 0)), Color.RED)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
