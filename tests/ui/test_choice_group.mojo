"""`ChoiceGroup`: choosing by a click, the arrows and a gamepad, and how it
is drawn."""
from std.testing import TestSuite, assert_equal, assert_false, assert_true

from create import *
from _input import (
    connect_pad,
    next_frame,
    point_at,
    press,
    press_key,
    press_pad,
    release,
)

comptime _RECT = Rectangle((0, 0), 200, 120)
"""Three options, 40 tall each: their middles 40 above the centre, at it
and 40 below it, their circles 90 left of it."""


def _group() -> ChoiceGroup:
    return ChoiceGroup(["Easy", "Normal", "Hard"], _RECT, selected=1)


def _click(
    mut group: ChoiceGroup, mut context: Context, down: Point, up: Point
) raises:
    """Press the mouse at `down` and let go at `up`, a frame each."""
    var canvas = Canvas(400, 300)
    next_frame(context)
    point_at(context, down)
    press(context, down)
    group.update(context, canvas)
    next_frame(context)
    point_at(context, up)
    release(context, up)
    group.update(context, canvas)


def test_a_click_on_an_option_chooses_it() raises -> None:
    var group = _group()
    var context = Context()
    _click(group, context, (0, -40), (0, -40))
    assert_equal(group.selected, 2)
    assert_true(group.changed())
    assert_equal(group.selected_text(), "Hard")


def test_a_press_and_a_release_on_different_options_choose_none() raises:
    var group = _group()
    var context = Context()
    _click(group, context, (0, 40), (0, -40))
    assert_equal(group.selected, 1)
    assert_false(group.changed())


def _in_a_ui(
    mut ui: UI, mut context: Context
) raises -> WidgetHandle[ChoiceGroup]:
    var handle = ui.add(_group())
    ui.focus(handle)
    point_at(context, (300, 300))
    connect_pad(context)
    return handle


def test_the_arrows_move_the_choice_and_stop_at_the_ends() raises -> None:
    var ui = UI()
    var context = Context()
    var group = _in_a_ui(ui, context)
    var canvas = Canvas(400, 300)
    for expected in [2, 2, 1, 0, 0]:
        next_frame(context)
        var key = Key.DOWN if expected == 2 else Key.UP
        press_key(context, key)
        ui.update(context, canvas)
        context.keyboard._key_up(key)
        assert_equal(ui[group].selected, expected)
        assert_true(ui.has_focus(group))  # the arrows don't move focus away


def test_a_gamepad_push_moves_the_choice() raises -> None:
    var ui = UI()
    var context = Context()
    var group = _in_a_ui(ui, context)
    var canvas = Canvas(400, 300)
    next_frame(context)
    press_pad(context, GamepadButton.DPAD_UP)
    ui.update(context, canvas)
    assert_equal(ui[group].selected, 0)
    assert_true(ui[group].changed())
    assert_true(ui.has_focus(group))


def test_its_ring_goes_round_the_chosen_option() raises -> None:
    var group = _group()
    assert_equal(group._ring().position, Point(-90, 0))
    group.selected = 0
    assert_equal(group._ring().position, Point(-90, 40))


def test_the_chosen_option_has_a_dot() raises -> None:
    var colors = ColorScheme.light()
    var group = ChoiceGroup(["Easy", "Normal", "Hard"], _RECT, selected=0)
    var context = Context()
    point_at(context, (300, 300))
    var canvas = Canvas(400, 300, antialiasing=Antialiasing.OFF)
    canvas.background(Color.WHITE)
    group.update(context, canvas)
    canvas.draw(group)
    assert_equal(canvas.color_at((-90, 40)), colors.primary)  # the dot
    assert_equal(canvas.color_at((-90, 0)), Color.WHITE)  # an empty circle


def test_a_halo_shows_behind_the_option_under_the_pointer() raises -> None:
    var group = _group()
    var context = Context()
    point_at(context, (-90, -40))  # on Hard's circle
    var canvas = Canvas(400, 300, antialiasing=Antialiasing.OFF)
    canvas.background(Color.WHITE)
    group.update(context, canvas)
    canvas.draw(group)
    assert_true(canvas.color_at((-90, -40)) != Color.WHITE)  # in Hard's halo
    assert_equal(canvas.color_at((-90, 40)), Color.WHITE)  # Easy: none


def test_a_ui_measures_an_option_a_control_tall() raises -> None:
    var ui = UI()
    var group = ui.add(ChoiceGroup(["A", "B", "C", "D"]))
    var context = Context()
    point_at(context, (300, 300))
    var canvas = Canvas(400, 300)
    ui.update(context, canvas)
    assert_equal(ui[group].rect.height, 4 * 40.0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
