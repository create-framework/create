"""`Dropdown`: opening, choosing and closing by the mouse, its list drawn
over everything in a `UI`, scrolling a long list, and opening upwards."""
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

comptime _FIELD = Rectangle((0, 50), 200, 40)
"""Its field: from 30 to 70 up. The open list below it has its items' middles
at 2, 38 down and 78 down."""


def _item(i: Int) -> Point:
    """The middle of the open list's item counted `i` from the top."""
    return Point(0, 2 - 40 * Float64(i))


def _options() -> List[String]:
    return ["Small", "Medium", "Large"]


def _click(mut ui: UI, mut context: Context, at: Point) raises:
    """Press and let go of the mouse at `at`, a frame each."""
    var canvas = Canvas(400, 300)
    next_frame(context)
    point_at(context, at)
    press(context, at)
    ui.update(context, canvas)
    next_frame(context)
    release(context, at)
    ui.update(context, canvas)


def test_a_click_opens_it_and_a_click_on_an_item_chooses_it() raises -> None:
    var ui = UI()
    var size = ui.add(Dropdown(_options(), _FIELD))
    var context = Context()
    _click(ui, context, _FIELD.position)
    assert_true(ui[size].is_open())
    _click(ui, context, _item(2))
    assert_false(ui[size].is_open())
    assert_equal(ui[size].selected, 2)
    assert_equal(ui[size].selected_text(), "Large")


def test_a_click_elsewhere_closes_it_and_reaches_nothing_else() raises -> None:
    var ui = UI()
    var size = ui.add(Dropdown(_options(), _FIELD))
    var ok = ui.add(Button("OK", Rectangle((0, -120), 100, 40)))
    var context = Context()
    _click(ui, context, _FIELD.position)
    _click(ui, context, (0, -120))  # on the button
    assert_false(ui[size].is_open())
    assert_equal(ui[size].selected, 0)
    assert_false(ui[ok].released())
    _click(ui, context, (0, -120))  # now it reaches the button
    assert_true(ui[ok].released())


def test_its_list_draws_outside_a_scroll_area_s_window() raises -> None:
    var ui = UI()
    var window = ui.add(ScrollArea(Rectangle((0, 50), 220, 60)))
    var column = ui.add(Column(), window)
    var size = ui.add(Dropdown(_options()), column)
    var context = Context()
    _click(ui, context, (0, 50))
    assert_true(ui[size].is_open())
    var canvas = Canvas(400, 300, antialiasing=Antialiasing.OFF)
    canvas.background(Color.RED)
    point_at(context, (180, 140))
    next_frame(context)
    ui.update(context, canvas)
    canvas.draw(ui)
    # the list's last item lies far below the window, which ends 20 up
    var list = ui[size]._popup().value()
    assert_true(list.bottom() < 0)
    assert_true(canvas.color_at((0, list.bottom() + 10)) != Color.RED)


def test_the_wheel_scrolls_a_long_list() raises -> None:
    var ui = UI()
    var options = List[String]()
    for i in range(20):
        options.append(String("Level ", i + 1))
    var level = ui.add(Dropdown(options^, _FIELD, max_items=4))
    var context = Context()
    _click(ui, context, _FIELD.position)
    var canvas = Canvas(400, 300)
    next_frame(context)
    point_at(context, _item(1))
    context.mouse._scroll(Vector(0, -1))
    ui.update(context, canvas)
    assert_equal(ui[level]._scroll, 40.0)  # an item's height
    _click(ui, context, _item(0))
    assert_equal(ui[level].selected, 1)  # the second, scrolled to the top


def test_the_wheel_over_its_list_leaves_a_scroll_area_round_it() raises -> None:
    var ui = UI()
    var window = ui.add(ScrollArea(Rectangle((0, 50), 220, 100)))
    var column = ui.add(Column(), window)
    var options = List[String]()
    for i in range(20):
        options.append(String("Level ", i + 1))
    var level = ui.add(Dropdown(options^, max_items=4), column)
    for name in ["A", "B", "C", "D"]:
        _ = ui.add(Button(name), column)
    var context = Context()
    var canvas = Canvas(400, 300)
    point_at(context, (180, 140))
    ui.update(context, canvas)
    _click(ui, context, ui.get(level).rect.position)
    assert_true(ui[level].is_open())
    var list = ui[level]._popup().value()
    next_frame(context)
    point_at(context, list.position)
    context.mouse._scroll(Vector(0, -1))
    ui.update(context, canvas)
    assert_equal(ui[level]._scroll, 40.0)  # the list scrolls
    assert_equal(ui[window].offset, 0.0)  # and the window round it doesn't
    # Away from the list, the wheel still reaches only the open dropdown.
    next_frame(context)
    point_at(context, (0, 90))
    context.mouse._scroll(Vector(0, -1))
    ui.update(context, canvas)
    assert_equal(ui[window].offset, 0.0)


def test_its_list_opens_upwards_near_the_canvas_s_foot() raises -> None:
    var ui = UI()
    var size = ui.add(Dropdown(_options(), Rectangle((0, -110), 200, 40)))
    var context = Context()
    _click(ui, context, (0, -110))
    var list = ui[size]._popup().value()
    assert_true(list.bottom() > -90)  # above the field, which ends 90 up


struct _Keys:
    """A `UI` with a dropdown and a button after it, focus on the dropdown,
    and the keyboard and a gamepad to drive it."""

    var ui: UI
    var size: WidgetHandle[Dropdown]
    var after: WidgetHandle[Button]
    var context: Context

    def __init__(out self, var options: List[String]) raises:
        self.ui = UI()
        self.size = self.ui.add(Dropdown(options^, _FIELD))
        self.after = self.ui.add(Button("OK", Rectangle((0, -120), 100, 40)))
        self.ui.focus(self.size)
        self.context = Context()
        point_at(self.context, (180, 140))
        connect_pad(self.context)
        self.frame()

    def frame(mut self) raises:
        var canvas = Canvas(400, 300)
        self.ui.update(self.context, canvas)

    def key(mut self, key: Key) raises:
        next_frame(self.context)
        press_key(self.context, key)
        self.frame()
        self.context.keyboard._key_up(key)

    def pad(mut self, button: GamepadButton) raises:
        next_frame(self.context)
        press_pad(self.context, button)
        self.frame()


def test_the_keys_open_it_move_the_mark_and_choose() raises -> None:
    var keys = _Keys(_options())
    keys.key(Key.ENTER)
    assert_true(keys.ui[keys.size].is_open())
    keys.key(Key.DOWN)
    keys.key(Key.DOWN)
    assert_equal(keys.ui[keys.size].selected, 0)  # only marked so far
    keys.key(Key.ENTER)
    assert_false(keys.ui[keys.size].is_open())
    assert_equal(keys.ui[keys.size].selected, 2)
    assert_true(keys.ui[keys.size].changed())
    assert_true(keys.ui.has_focus(keys.size))


def test_a_gamepad_opens_it_moves_the_mark_and_chooses() raises -> None:
    var keys = _Keys(_options())
    keys.pad(GamepadButton.SOUTH)
    assert_true(keys.ui[keys.size].is_open())
    keys.pad(GamepadButton.DPAD_DOWN)
    assert_true(keys.ui.has_focus(keys.size))  # the push moved no focus
    keys.pad(GamepadButton.SOUTH)
    assert_equal(keys.ui[keys.size].selected, 1)
    assert_false(keys.ui[keys.size].is_open())


def test_escape_and_the_east_button_close_it_keeping_focus() raises -> None:
    var keys = _Keys(_options())
    keys.key(Key.ENTER)
    keys.key(Key.DOWN)
    keys.key(Key.ESCAPE)
    assert_false(keys.ui[keys.size].is_open())
    assert_equal(keys.ui[keys.size].selected, 0)  # nothing chosen
    assert_true(keys.ui.has_focus(keys.size))
    keys.pad(GamepadButton.SOUTH)
    keys.pad(GamepadButton.EAST)
    assert_false(keys.ui[keys.size].is_open())
    assert_true(keys.ui.has_focus(keys.size))


def test_tab_closes_it_and_moves_on() raises -> None:
    var keys = _Keys(_options())
    keys.key(Key.ENTER)
    keys.key(Key.TAB)
    assert_true(keys.ui.has_focus(keys.after))
    keys.frame()
    assert_false(keys.ui[keys.size].is_open())


def test_the_mark_scrolls_a_long_list() raises -> None:
    var options = List[String]()
    for i in range(20):
        options.append(String("Level ", i + 1))
    var keys = _Keys(options^)
    keys.ui[keys.size].max_items = 4
    keys.key(Key.ENTER)
    for _ in range(6):
        keys.key(Key.DOWN)
    assert_equal(keys.ui[keys.size]._highlight, 6)
    # the seventh item's foot at the list's: 3 items' heights scrolled
    assert_equal(keys.ui[keys.size]._scroll, 3 * 40.0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
