"""Sharing the devices: `wants_mouse` and `wants_keyboard` say when a tree is
using them, several trees take turns at them through claims, and a disabled
part of a tree reacts to nothing."""
from std.testing import TestSuite, assert_equal, assert_false, assert_true

from create import *
from _input import next_frame, point_at, press, press_key, release


def _update(mut ui: UI, mut context: Context) raises:
    var canvas = Canvas(400, 300)
    ui.update(context, canvas)


def test_wants_mouse_over_a_widget_or_while_one_is_held() raises -> None:
    var ui = UI()
    _ = ui.add(Slider(0.5, 0, 1, Rectangle((0, 0), 200, 32)))
    var context = Context()
    point_at(context, (0, 100))
    _update(ui, context)
    assert_false(ui.wants_mouse(context))
    next_frame(context)
    point_at(context, (0, 0))
    press(context, (0, 0))
    _update(ui, context)
    assert_true(ui.wants_mouse(context))
    next_frame(context)
    point_at(context, (0, 120))  # dragged off it, still held
    _update(ui, context)
    assert_true(ui.wants_mouse(context))
    next_frame(context)
    release(context, (0, 120))
    _update(ui, context)
    next_frame(context)
    _update(ui, context)
    assert_false(ui.wants_mouse(context))


def test_a_tree_not_updated_lately_wants_nothing() raises -> None:
    var ui = UI()
    _ = ui.add(Button("OK", Rectangle((0, 0), 100, 40)))
    var context = Context()
    point_at(context, (0, 0))
    _update(ui, context)
    assert_true(ui.wants_mouse(context))
    next_frame(context)
    next_frame(context)
    assert_false(ui.wants_mouse(context))  # a menu that has closed


def test_wants_keyboard_follows_what_focus_takes_keys() raises -> None:
    var ui = UI()
    var ok = ui.add(Button("OK", Rectangle((0, 60), 100, 40)))
    _ = ui.add(TextField(rect=Rectangle((0, -60), 200, 40)))
    var context = Context()
    point_at(context, (0, 60))
    press(context, (0, 60))
    _update(ui, context)
    assert_true(ui.has_focus(ok))
    assert_false(ui.wants_keyboard(context))  # a click: the game's keys
    next_frame(context)
    point_at(context, (0, -60))
    press(context, (0, -60))
    _update(ui, context)
    assert_true(ui.wants_keyboard(context))  # a text field, even by click
    next_frame(context)
    press_key(context, Key.ESCAPE)
    _update(ui, context)
    assert_true(ui.wants_keyboard(context))  # Escape was the tree's
    next_frame(context)
    _update(ui, context)
    assert_false(ui.wants_keyboard(context))


def test_one_tab_focuses_one_field_across_trees() raises -> None:
    var first = UI()
    var second = UI()
    var a = first.add(TextField(rect=Rectangle((0, 60), 200, 40)))
    var b = second.add(TextField(rect=Rectangle((0, -60), 200, 40)))
    var context = Context()
    point_at(context, (0, 140))
    press_key(context, Key.TAB)
    _update(first, context)
    _update(second, context)
    assert_true(first.has_focus(a))
    assert_false(second.has_focus(b))  # the keyboard was taken


def test_a_click_in_one_tree_takes_the_keyboard_from_the_other() raises -> None:
    var first = UI()
    var second = UI()
    var a = first.add(TextField(rect=Rectangle((0, 60), 200, 40)))
    var b = second.add(TextField(rect=Rectangle((0, -60), 200, 40)))
    var context = Context()
    point_at(context, (0, 60))
    press(context, (0, 60))
    _update(first, context)
    _update(second, context)
    assert_true(first.has_focus(a))
    next_frame(context)
    release(context, (0, 60))
    point_at(context, (0, -60))
    press(context, (0, -60))
    _update(first, context)  # a click on nothing of its own: lets go
    _update(second, context)
    assert_false(first.has_focus(a))
    assert_true(second.has_focus(b))


def test_a_drag_in_one_tree_leaves_the_others_widgets_alone() raises -> None:
    var first = UI()
    var second = UI()
    var volume = first.add(Slider(0.5, 0, 1, Rectangle((0, 60), 200, 32)))
    var ok = second.add(Button("OK", Rectangle((0, -60), 100, 40)))
    var context = Context()
    point_at(context, (0, 60))
    press(context, (0, 60))
    _update(first, context)
    _update(second, context)
    next_frame(context)
    point_at(context, (0, -60))  # dragged over the other tree's button
    _update(first, context)
    _update(second, context)
    assert_true(first[volume].down())
    assert_false(second[ok].hovered())


def test_a_disabled_part_reacts_to_nothing_until_enabled() raises -> None:
    var ui = UI()
    var card = ui.add(Panel(Rectangle((0, 0), 300, 200)))
    var ok = ui.add(Button("OK", Rectangle((0, 0), 100, 40)), card)
    ui.enabled(card, False)
    var context = Context()
    point_at(context, (0, 0))
    press(context, (0, 0))
    _update(ui, context)
    next_frame(context)
    release(context, (0, 0))
    _update(ui, context)
    assert_false(ui[ok].released())
    assert_false(ui.has_focus(ok))
    assert_true(ui[ok].enabled)  # its own setting is kept
    ui.enabled(card, True)
    next_frame(context)
    press(context, (0, 0))
    release(context, (0, 0))
    _update(ui, context)
    assert_true(ui[ok].released())


def test_a_disabled_part_is_drawn_faded_and_lets_go_of_focus() raises -> None:
    var ui = UI()
    var row = ui.add(Row(rect=Rectangle((0, 0), 300, 40)))
    var ok = ui.add(Button("OK"), row)
    _ = ui.add(Label("Text"), row)
    var context = Context()
    point_at(context, (0, 140))
    ui.focus(ok)
    var bright = Canvas(400, 300, antialiasing=Antialiasing.OFF)
    ui.update(context, bright)
    bright.draw(ui)
    assert_true(ui.has_focus(ok))
    ui.enabled(row, False)
    var faded = Canvas(400, 300, antialiasing=Antialiasing.OFF)
    ui.update(context, faded)
    faded.draw(ui)
    assert_false(ui.has_focus(ok))
    var at = ui[ok].rect.position + Vector(-60, 0)
    assert_true(faded.color_at(at).a < bright.color_at(at).a)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
