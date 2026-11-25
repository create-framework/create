"""Focus in the widget tree: a click, Tab, a gamepad or code gives it, keys
and buttons act on the focused widget, typing reaches a focused field, and
a ring shows focus from anything but a click."""
from std.testing import (
    TestSuite,
    assert_almost_equal,
    assert_equal,
    assert_false,
    assert_true,
)

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


struct _Panel:
    """Three buttons in a row, the second possibly disabled, a slider under
    them, and a text field under that."""

    var ui: UI
    var context: Context
    var buttons: List[WidgetHandle[Button]]
    var slider: WidgetHandle[Slider]
    var field: WidgetHandle[TextField]

    def __init__(out self) raises:
        self.ui = UI()
        self.context = Context()
        self.buttons = []
        for i in range(3):
            var x = -120 + 120 * Float64(i)
            self.buttons.append(
                self.ui.add(Button("OK", Rectangle(Point(x, 60), 100.0, 40.0)))
            )
        self.slider = self.ui.add(Slider(0.5, 0, 1, Rectangle((0, 0), 200, 32)))
        self.field = self.ui.add(TextField(Rectangle((0, -60), 200, 40)))
        point_at(self.context, (0, 95))  # on nothing
        connect_pad(self.context)

    def frame(mut self) raises -> Canvas:
        var canvas = Canvas(400, 200, antialiasing=Antialiasing.OFF)
        canvas.background(Color.WHITE)
        self.ui.update(self.context, canvas)
        canvas.draw(self.ui)
        return canvas^

    def key(mut self, key: Key, shift: Bool = False) raises:
        next_frame(self.context)
        if shift:
            self.context.keyboard._key_down(Key.LEFT_SHIFT)
        press_key(self.context, key)
        _ = self.frame()
        next_frame(self.context)
        if shift:
            self.context.keyboard._key_up(Key.LEFT_SHIFT)
        self.context.keyboard._key_up(key)

    def pad(mut self, button: GamepadButton) raises:
        next_frame(self.context)
        press_pad(self.context, button)
        _ = self.frame()

    def click(mut self, at: Point) raises:
        next_frame(self.context)
        point_at(self.context, at)
        press(self.context, at)
        release(self.context, at)
        _ = self.frame()

    def focused(self) -> Int:
        """Which widget has focus: the buttons 0 to 2, the slider 3, the
        field 4; -1 for none."""
        for i in range(3):
            if self.ui.has_focus(self.buttons[i]):
                return i
        if self.ui.has_focus(self.slider):
            return 3
        if self.ui.has_focus(self.field):
            return 4
        return -1


def test_tab_goes_through_the_widgets_and_wraps_round() raises -> None:
    var panel = _Panel()
    _ = panel.frame()
    for expected in [0, 1, 2, 3, 4, 0]:
        panel.key(Key.TAB)
        assert_equal(panel.focused(), expected)
    panel.key(Key.TAB, shift=True)
    assert_equal(panel.focused(), 4)


def test_tab_skips_a_disabled_widget() raises -> None:
    var panel = _Panel()
    panel.ui[panel.buttons[1]].enabled = False
    _ = panel.frame()
    panel.key(Key.TAB)
    panel.key(Key.TAB)
    assert_equal(panel.focused(), 2)


def test_enter_and_space_press_the_focused_button() raises -> None:
    var panel = _Panel()
    _ = panel.frame()
    panel.key(Key.TAB)
    panel.key(Key.ENTER)
    assert_true(panel.ui[panel.buttons[0]].released())
    assert_false(panel.ui[panel.buttons[1]].released())
    panel.key(Key.SPACE)
    assert_true(panel.ui[panel.buttons[0]].released())


def test_keys_do_nothing_after_a_click() raises -> None:
    var panel = _Panel()
    _ = panel.frame()
    var at = panel.ui[panel.buttons[0]].rect.position
    panel.click(at)
    assert_equal(panel.focused(), 0)  # focused, so Tab goes on from it
    panel.key(Key.ENTER)
    assert_false(panel.ui[panel.buttons[0]].released())  # the game's Enter


def test_the_arrows_and_home_and_end_move_a_focused_slider() raises -> None:
    var panel = _Panel()
    _ = panel.frame()
    for _ in range(4):
        panel.key(Key.TAB)
    assert_equal(panel.focused(), 3)
    panel.key(Key.RIGHT)
    assert_almost_equal(panel.ui[panel.slider].value, 0.55)
    assert_true(panel.ui[panel.slider].changed())
    panel.key(Key.HOME)
    assert_equal(panel.ui[panel.slider].value, 0.0)
    panel.key(Key.END)
    assert_equal(panel.ui[panel.slider].value, 1.0)


def test_escape_and_a_click_on_nothing_take_focus_away() raises -> None:
    var panel = _Panel()
    _ = panel.frame()
    panel.key(Key.TAB)
    panel.key(Key.ESCAPE)
    assert_equal(panel.focused(), -1)
    panel.key(Key.TAB)
    panel.click((0, 95))
    assert_equal(panel.focused(), -1)


def test_typing_reaches_a_field_tab_reached() raises -> None:
    var panel = _Panel()
    panel.context.text_input(False)
    _ = panel.frame()
    for _ in range(5):
        panel.key(Key.TAB)
    assert_equal(panel.focused(), 4)
    assert_true(panel.context.text_input())  # switched on for the field
    next_frame(panel.context)
    panel.context.keyboard._type_text("hi")
    _ = panel.frame()
    assert_equal(panel.ui[panel.field].text(), "hi")
    panel.key(Key.ESCAPE)
    assert_false(panel.context.text_input())


def test_a_disabled_widget_loses_focus() raises -> None:
    var panel = _Panel()
    _ = panel.frame()
    panel.key(Key.TAB)
    panel.ui[panel.buttons[0]].enabled = False
    next_frame(panel.context)
    _ = panel.frame()
    assert_equal(panel.focused(), -1)


def test_code_gives_focus_with_its_ring() raises -> None:
    var panel = _Panel()
    panel.ui.focus(panel.buttons[2])
    var canvas = panel.frame()
    assert_equal(panel.focused(), 2)
    var ring = ColorScheme.light().secondary
    var right = panel.ui[panel.buttons[2]].rect.right()
    assert_equal(canvas.color_at((right + 3.5, 60)), ring)


def test_a_click_shows_no_ring() raises -> None:
    var panel = _Panel()
    _ = panel.frame()
    var at = panel.ui[panel.buttons[2]].rect.position
    panel.click(at)
    next_frame(panel.context)
    point_at(panel.context, (0, 95))
    var canvas = panel.frame()
    var right = panel.ui[panel.buttons[2]].rect.right()
    assert_equal(canvas.color_at((right + 3.5, 60)), Color.WHITE)


def test_the_dpad_moves_focus_by_where_widgets_are() raises -> None:
    var panel = _Panel()
    _ = panel.frame()
    panel.pad(GamepadButton.DPAD_DOWN)  # from nothing: the first
    assert_equal(panel.focused(), 0)
    panel.pad(GamepadButton.DPAD_RIGHT)
    assert_equal(panel.focused(), 1)
    panel.pad(GamepadButton.DPAD_DOWN)
    assert_equal(panel.focused(), 3)  # the slider, below
    panel.pad(GamepadButton.DPAD_RIGHT)  # steps the slider, keeps focus
    assert_equal(panel.focused(), 3)
    assert_almost_equal(panel.ui[panel.slider].value, 0.55)
    panel.pad(GamepadButton.DPAD_UP)
    panel.pad(GamepadButton.SOUTH)
    assert_true(panel.ui[panel.buttons[1]].released())
    panel.pad(GamepadButton.EAST)
    assert_equal(panel.focused(), -1)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
