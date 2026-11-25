"""Changing the widget tree while it runs: `remove` takes a widget and what
is inside it out for good, and `visible` hides a part of the tree, which then
takes no room, reacts to nothing and loses focus, until it is shown again."""
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_true,
)

from create import *
from _input import next_frame, point_at, press, press_key, release

# The defaults: `spacing` 8, `control_height` 40.
comptime _GAP = 8.0
comptime _CONTROL = 40.0


def _canvas() raises -> Canvas:
    return Canvas(400, 300, antialiasing=Antialiasing.OFF)


def _click(mut ui: UI, mut context: Context, at: Point) raises:
    """Press and let go at `at` within one frame, then update the tree."""
    next_frame(context)
    point_at(context, at)
    press(context, at)
    release(context, at)
    var canvas = _canvas()
    ui.update(context, canvas)


def _tab(mut ui: UI, mut context: Context) raises:
    next_frame(context)
    press_key(context, Key.TAB)
    var canvas = _canvas()
    ui.update(context, canvas)
    next_frame(context)
    context.keyboard._key_up(Key.TAB)


def test_a_removed_widget_leaves_its_column_closed_up() raises -> None:
    var ui = UI()
    var list = ui.add(Column(Rectangle((0, 0), 200, 300)))
    var first = ui.add(Button("A"), list)
    var second = ui.add(Button("B"), list)
    var third = ui.add(Button("C"), list)
    ui.remove(second)
    var context = Context()
    var canvas = _canvas()
    ui.update(context, canvas)
    assert_equal(ui[first].rect.top(), 150.0)
    assert_equal(ui[third].rect.top(), 150.0 - _CONTROL - _GAP)


def test_removing_a_panel_removes_what_is_inside_it() raises -> None:
    var ui = UI()
    var card = ui.add(Panel(Rectangle((0, 0), 200, 100)))
    var ok = ui.add(Button("OK", Rectangle((0, 0), 100, 40)), card)
    var context = Context()
    _tab(ui, context)
    assert_true(ui.has_focus(ok))
    ui.remove(card)
    assert_false(Bool(ui._focused))  # the focus left with it
    var canvas = _canvas()
    canvas.background(Color.WHITE)
    ui.update(context, canvas)
    canvas.draw(ui)
    assert_equal(canvas.color_at((0, 0)), Color.WHITE)  # nothing drawn
    assert_equal(len(ui._free), 2)


def test_a_new_widget_takes_a_removed_ones_place_not_its_handle() raises -> (
    None
):
    var ui = UI()
    var old = ui.add(Button("Old", Rectangle((0, 0), 100, 40)))
    ui.remove(old)
    var new = ui.add(Button("New", Rectangle((0, 0), 100, 40)))
    assert_equal(new._index, old._index)  # the same place in the list
    assert_true(new != old)  # but a handle of its own
    assert_equal(ui[new].text, "New")


def test_a_hidden_widget_takes_no_room_and_comes_back() raises -> None:
    var ui = UI()
    var list = ui.add(Column(Rectangle((0, 0), 200, 300)))
    var first = ui.add(Button("A"), list)
    var second = ui.add(Button("B"), list)
    var third = ui.add(Button("C"), list)
    ui.visible(second, False)
    assert_false(ui.visible(second))
    var context = Context()
    var canvas = _canvas()
    ui.update(context, canvas)
    assert_equal(ui[third].rect.top(), 150.0 - _CONTROL - _GAP)
    ui.visible(second, True)
    ui.update(context, canvas)
    assert_equal(ui[second].rect.top(), 150.0 - _CONTROL - _GAP)
    assert_equal(ui[third].rect.top(), 150.0 - 2 * (_CONTROL + _GAP))
    assert_equal(ui[first].rect.top(), 150.0)


def test_a_hidden_part_is_not_drawn_or_clicked() raises -> None:
    var ui = UI()
    var card = ui.add(Panel(Rectangle((0, 0), 200, 100)))
    var ok = ui.add(Button("OK", Rectangle((0, 0), 100, 40)), card)
    ui.visible(card, False)
    var context = Context()
    _click(ui, context, (0, 0))
    assert_false(ui[ok].released())
    assert_false(ui.wants_mouse(context))
    var canvas = _canvas()
    canvas.background(Color.WHITE)
    canvas.draw(ui)
    assert_equal(canvas.color_at((0, 0)), Color.WHITE)


def test_a_button_hidden_as_it_is_clicked_reports_the_click_once() raises -> (
    None
):
    var ui = UI()
    var ok = ui.add(Button("OK", Rectangle((0, 0), 100, 40)))
    var context = Context()
    _click(ui, context, (0, 0))
    assert_true(ui[ok].released())
    ui.visible(ok, False)
    next_frame(context)
    var canvas = _canvas()
    ui.update(context, canvas)
    assert_false(ui[ok].released())  # not again, every frame it is hidden


def test_a_hidden_widget_loses_focus_and_tab_skips_it() raises -> None:
    var ui = UI()
    var first = ui.add(Button("A", Rectangle((0, 50), 100, 40)))
    var second = ui.add(Button("B", Rectangle((0, -50), 100, 40)))
    var context = Context()
    _tab(ui, context)
    assert_true(ui.has_focus(first))
    ui.visible(first, False)
    var canvas = _canvas()
    ui.update(context, canvas)
    assert_false(ui.has_focus(first))
    _tab(ui, context)
    assert_true(ui.has_focus(second))
    _tab(ui, context)
    assert_true(ui.has_focus(second))  # the only one shown
    ui.focus(first)
    assert_true(ui.has_focus(second))  # a hidden widget takes no focus


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
