"""Tooltips: shown after the pointer rests on a widget, hidden by a press,
shown for focus from the keyboard, and drawn over everything."""
from std.testing import TestSuite, assert_equal, assert_false, assert_true

from create import *
from _input import next_frame, point_at, press, release

comptime _BUTTON = Rectangle((0, 0), 120, 40)


def _frame(mut ui: UI, mut context: Context, time: Float64) raises:
    """A frame at `time` seconds by the real clock."""
    next_frame(context)
    context.time.real_elapsed = time
    var canvas = Canvas(400, 300)
    ui.update(context, canvas)


def test_it_shows_once_the_pointer_has_rested_a_moment() raises -> None:
    var ui = UI()
    var play = ui.add(Button("Play", _BUTTON))
    ui.tooltip(play, String("Start a new game"))
    var context = Context()
    point_at(context, (0, 0))
    _frame(ui, context, 0.0)
    assert_false(Bool(ui._tip))
    _frame(ui, context, 0.4)
    assert_false(Bool(ui._tip))
    _frame(ui, context, 0.6)
    assert_true(Bool(ui._tip))
    assert_equal(ui._tip.value().text, "Start a new game")
    point_at(context, (180, 140))  # away
    _frame(ui, context, 0.7)
    assert_false(Bool(ui._tip))


def test_a_press_hides_it_until_the_pointer_leaves() raises -> None:
    var ui = UI()
    var play = ui.add(Button("Play", _BUTTON))
    ui.tooltip(play, String("Start a new game"))
    var context = Context()
    point_at(context, (0, 0))
    _frame(ui, context, 0.0)
    _frame(ui, context, 0.6)
    assert_true(Bool(ui._tip))
    var canvas = Canvas(400, 300)
    next_frame(context)
    press(context, (0, 0))
    ui.update(context, canvas)
    next_frame(context)
    release(context, (0, 0))
    ui.update(context, canvas)
    _frame(ui, context, 2.0)
    assert_false(Bool(ui._tip))  # still on it, but hidden
    point_at(context, (180, 140))
    _frame(ui, context, 2.1)
    point_at(context, (0, 0))
    _frame(ui, context, 2.2)
    _frame(ui, context, 2.8)
    assert_true(Bool(ui._tip))  # back after resting again


def test_it_shows_at_once_for_focus_from_the_keyboard() raises -> None:
    var ui = UI()
    var play = ui.add(Button("Play", _BUTTON))
    ui.tooltip(play, String("Start a new game"))
    ui.focus(play)
    var context = Context()
    point_at(context, (180, 140))
    _frame(ui, context, 0.0)
    assert_true(Bool(ui._tip))


def test_none_takes_it_away() raises -> None:
    var ui = UI()
    var play = ui.add(Button("Play", _BUTTON))
    ui.tooltip(play, String("Start a new game"))
    ui.tooltip(play, None)
    assert_false(Bool(ui.tooltip(play)))
    ui.focus(play)
    var context = Context()
    _frame(ui, context, 0.0)
    assert_false(Bool(ui._tip))


def test_it_is_drawn_over_everything_outside_a_scroll_area() raises -> None:
    var ui = UI()
    var window = ui.add(ScrollArea(Rectangle((0, 0), 200, 60)))
    var column = ui.add(Column(), window)
    var play = ui.add(Button("Play"), column)
    ui.tooltip(play, String("Start a new game"))
    ui.focus(play)
    var context = Context()
    point_at(context, (180, 140))
    next_frame(context)
    var canvas = Canvas(400, 300, antialiasing=Antialiasing.OFF)
    canvas.background(Color.WHITE)
    ui.update(context, canvas)
    canvas.draw(ui)
    var tip = ui._tip.value().rect
    assert_true(tip.bottom() < -34)  # past the window, which ends 30 down
    var fill = ui.colors().on_surface
    assert_equal(canvas.color_at((tip.left() + 2, tip.bottom() + 2)), fill)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
