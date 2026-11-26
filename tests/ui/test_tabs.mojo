"""`Tabs`: selecting by a click, the arrows and a gamepad, the indicator,
and switching pages with them."""
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

comptime _RECT = Rectangle((0, 0), 300, 40)
"""Three tabs, 100 wide each: their middles 100 left of the centre, at it
and 100 right of it."""


def _tabs() -> Tabs:
    return Tabs(["General", "Audio", "Video"], _RECT)


def _click(mut tabs: Tabs, mut context: Context, at: Point) raises:
    var canvas = Canvas(400, 300)
    next_frame(context)
    point_at(context, at)
    press(context, at)
    tabs.update(context, canvas)
    next_frame(context)
    release(context, at)
    tabs.update(context, canvas)


def test_a_click_on_a_tab_selects_it() raises -> None:
    var tabs = _tabs()
    var context = Context()
    _click(tabs, context, (100, 0))
    assert_equal(tabs.selected, 2)
    assert_true(tabs.changed())
    assert_equal(tabs.selected_text(), "Video")


def test_the_arrows_and_a_gamepad_move_the_selection() raises -> None:
    var ui = UI()
    var tabs = ui.add(_tabs())
    ui.focus(tabs)
    var context = Context()
    point_at(context, (300, 300))
    connect_pad(context)
    var canvas = Canvas(400, 300)
    var keys = [Key.RIGHT, Key.RIGHT, Key.RIGHT, Key.LEFT]
    var expected = [1, 2, 2, 1]  # stopping at the last tab
    for i in range(len(keys)):
        next_frame(context)
        press_key(context, keys[i])
        ui.update(context, canvas)
        context.keyboard._key_up(keys[i])
        assert_equal(ui[tabs].selected, expected[i])
        assert_true(ui.has_focus(tabs))
    next_frame(context)
    press_pad(context, GamepadButton.DPAD_LEFT)
    ui.update(context, canvas)
    assert_equal(ui[tabs].selected, 0)
    assert_true(ui[tabs].changed())


def test_the_selected_tab_has_the_indicator() raises -> None:
    var colors = ColorScheme.light()
    var tabs = _tabs()
    var context = Context()
    point_at(context, (300, 300))
    var canvas = Canvas(400, 300, antialiasing=Antialiasing.OFF)
    canvas.background(Color.WHITE)
    tabs.update(context, canvas)
    canvas.draw(tabs)
    assert_equal(canvas.color_at((-100, -19)), colors.primary)
    assert_equal(canvas.color_at((0, -19)), Color.WHITE)


def test_tabs_switch_pages_shown_with_ui_visible() raises -> None:
    var ui = UI()
    var card = ui.add(Panel(Rectangle((0, 0), 320, 240)))
    var column = ui.add(Column(), card)
    var tabs = ui.add(Tabs(["General", "Audio"]), column)
    var general = ui.add(Column(), column)
    var name = ui.add(Button("Name"), general)
    var audio = ui.add(Column(), column)
    var volume = ui.add(Slider(0.5, 0, 1), audio)
    ui.visible(audio, False)
    var context = Context()
    point_at(context, (300, 300))
    var canvas = Canvas(400, 300)
    ui.update(context, canvas)
    var page_top = ui[name].rect.top()
    ui[tabs].selected = 1  # as a click on Audio would
    ui.visible(general, ui[tabs].selected == 0)
    ui.visible(audio, ui[tabs].selected == 1)
    next_frame(context)
    ui.update(context, canvas)
    assert_equal(ui[volume].rect.top(), page_top)  # in the page's place
    assert_false(ui.visible(general))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
