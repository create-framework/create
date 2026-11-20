"""Focus: at most one widget has it. A click on a widget gives it focus, a
click on no widget or Escape takes it away, and `take_focus` gives it from
code, the last widget to ask winning."""
from std.testing import TestSuite, assert_equal, assert_false, assert_true

from create import *
from _input import next_frame, point_at, press, press_key, release

comptime _A = Rectangle((-60, 0), 100, 40)
comptime _B = Rectangle((60, 0), 100, 40)


def _frame(
    mut ui: UI,
    mut context: Context,
    take: List[Bool] = [False, False],
    disabled: List[Bool] = [False, False],
    count: Int = 2,
) raises:
    """One frame of buttons at `_A` and `_B` (the first `count` of them)."""
    var canvas = Canvas(300, 100)
    var rects = [_A, _B]
    with ui.screen(context, canvas) as layer:
        for i in range(count):
            _ = layer.button(
                "OK", rects[i], take_focus=take[i], disabled=disabled[i]
            )


def _focused(ui: UI) -> Int:
    """Which of the buttons has focus, by the order they were called: -1 for
    none."""
    if not ui._focused:
        return -1
    for i in range(len(ui._hits)):
        if ui._hits[i].id == ui._focused.value():
            return i
    return -1


def _click(mut ui: UI, mut context: Context, at: Point) raises:
    next_frame(context)
    point_at(context, at)
    _frame(ui, context)
    next_frame(context)
    press(context, at)
    release(context, at)
    _frame(ui, context)


def test_a_click_gives_focus_and_a_click_elsewhere_moves_it() raises -> None:
    var ui = UI()
    var context = Context()
    _frame(ui, context)
    assert_equal(_focused(ui), -1)
    _click(ui, context, _A.position)
    assert_equal(_focused(ui), 0)
    _click(ui, context, _B.position)
    assert_equal(_focused(ui), 1)


def test_a_click_on_no_widget_takes_focus_away() raises -> None:
    var ui = UI()
    var context = Context()
    _frame(ui, context)
    _click(ui, context, _A.position)
    _click(ui, context, Point(0, 45))
    assert_equal(_focused(ui), -1)


def test_the_last_widget_to_take_focus_has_it() raises -> None:
    var ui = UI()
    var context = Context()
    _frame(ui, context, take=[True, True])
    assert_equal(_focused(ui), 1)
    assert_true(ui._focus_visible)  # from code: a ring will show
    next_frame(context)
    _frame(ui, context, take=[True, False])
    assert_equal(_focused(ui), 0)


def test_a_click_gives_focus_without_a_ring() raises -> None:
    var ui = UI()
    var context = Context()
    _frame(ui, context)
    _click(ui, context, _A.position)
    assert_false(ui._focus_visible)


def test_escape_takes_focus_away_and_keeps_the_key_that_frame() raises -> None:
    var ui = UI()
    var context = Context()
    _frame(ui, context, take=[True, False])
    assert_false(ui.wants_keyboard())  # a button doesn't take typing
    next_frame(context)
    press_key(context, Key.ESCAPE)
    _frame(ui, context)
    assert_equal(_focused(ui), -1)
    assert_true(ui.wants_keyboard())  # the Escape was the UI's
    next_frame(context)
    _frame(ui, context)
    assert_false(ui.wants_keyboard())


def test_a_disabled_widget_cannot_take_focus() raises -> None:
    var ui = UI()
    var context = Context()
    _frame(ui, context, take=[True, False], disabled=[True, False])
    assert_equal(_focused(ui), -1)


def test_a_widget_loses_focus_when_disabled() raises -> None:
    var ui = UI()
    var context = Context()
    _frame(ui, context, take=[True, False])
    next_frame(context)
    _frame(ui, context, disabled=[True, False])
    assert_equal(_focused(ui), -1)


def test_a_widget_loses_focus_when_no_longer_called() raises -> None:
    var ui = UI()
    var context = Context()
    _frame(ui, context, take=[False, True])
    next_frame(context)
    _frame(ui, context, count=1)  # `_B` isn't called
    next_frame(context)
    _frame(ui, context)
    assert_equal(_focused(ui), -1)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
