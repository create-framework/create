"""Keyboard navigation: Tab and Shift+Tab move focus in the order widgets
were called, Enter and Space press the focused widget, and the arrows move a
focused slider. Keys act only on focus from the keyboard or code, not on
focus from a click."""
from std.testing import (
    TestSuite,
    assert_almost_equal,
    assert_equal,
    assert_false,
    assert_true,
)

from create import *
from _input import next_frame, point_at, press, press_key, release


struct _Panel:
    """Three buttons, the second one possibly disabled, and a slider."""

    var ui: UI
    var context: Context
    var clicked: List[Bool]
    var value: Float64
    var changed: Bool
    var count: Int
    var disable_second: Bool

    def __init__(out self):
        self.ui = UI()
        self.context = Context()
        self.clicked = [False, False, False]
        self.value = 0.5
        self.changed = False
        self.count = 3
        self.disable_second = False

    def frame(mut self) raises:
        var canvas = Canvas(400, 200)
        with self.ui.screen(self.context, canvas) as layer:
            for i in range(self.count):
                self.clicked[i] = layer.button(
                    "OK",
                    Rectangle(Point(-120 + 120 * Float64(i), 40), 100.0, 40.0),
                    disabled=self.disable_second and i == 1,
                )
            layer.slider(self.value, 0, 1, Rectangle((0, -40), 200, 32))
            self.changed = layer.changed()

    def key(mut self, key: Key, shift: Bool = False) raises:
        next_frame(self.context)
        if shift:
            self.context.keyboard._key_down(Key.LEFT_SHIFT)
        press_key(self.context, key)
        self.frame()
        if shift:
            next_frame(self.context)
            self.context.keyboard._key_up(Key.LEFT_SHIFT)

    def focused(self) -> Int:
        """Which widget has focus, by call order: the slider is 3; -1 for
        none."""
        if not self.ui._focused:
            return -1
        for i in range(len(self.ui._hits)):
            if self.ui._hits[i].id == self.ui._focused.value():
                return i
        return -1


def test_tab_moves_focus_in_call_order_and_wraps() raises -> None:
    var p = _Panel()
    p.frame()
    p.key(Key.TAB)
    assert_equal(p.focused(), 0)
    assert_true(p.ui._focus_visible)
    assert_true(p.ui.wants_keyboard())
    p.key(Key.TAB)
    assert_equal(p.focused(), 1)
    p.key(Key.TAB)
    p.key(Key.TAB)
    assert_equal(p.focused(), 3)  # the slider
    p.key(Key.TAB)
    assert_equal(p.focused(), 0)  # round to the first


def test_shift_tab_goes_back() raises -> None:
    var p = _Panel()
    p.frame()
    p.key(Key.TAB, shift=True)
    assert_equal(p.focused(), 3)  # from nothing, to the last
    p.key(Key.TAB, shift=True)
    assert_equal(p.focused(), 2)


def test_tab_skips_a_disabled_widget() raises -> None:
    var p = _Panel()
    p.disable_second = True
    p.frame()
    p.key(Key.TAB)
    p.key(Key.TAB)
    assert_equal(p.focused(), 2)


def test_a_widget_no_longer_called_drops_out_of_the_order() raises -> None:
    var p = _Panel()
    p.frame()
    p.count = 1  # only the first button and the slider
    next_frame(p.context)
    p.frame()
    p.key(Key.TAB)
    p.key(Key.TAB)
    assert_equal(p.focused(), 1)  # the slider, second in call order now


def test_enter_and_space_press_the_focused_button() raises -> None:
    var p = _Panel()
    p.frame()
    p.key(Key.TAB)
    p.key(Key.ENTER)
    assert_true(p.clicked[0])
    p.key(Key.SPACE)
    assert_true(p.clicked[0])
    next_frame(p.context)
    p.frame()
    assert_false(p.clicked[0])


def test_arrows_move_the_focused_slider() raises -> None:
    var p = _Panel()
    p.frame()
    for _ in range(4):
        p.key(Key.TAB)
    p.key(Key.RIGHT)
    assert_true(p.changed)
    assert_almost_equal(p.value, 0.55)
    p.key(Key.DOWN)
    assert_almost_equal(p.value, 0.5)
    p.key(Key.END)
    assert_equal(p.value, 1.0)
    p.key(Key.RIGHT)
    assert_false(p.changed)  # already at the end
    p.key(Key.HOME)
    assert_equal(p.value, 0.0)


def test_arrow_steps_land_exactly_on_the_steps() raises -> None:
    var p = _Panel()
    p.value = 1.0
    p.frame()
    for _ in range(4):
        p.key(Key.TAB)
    p.key(Key.LEFT)
    p.key(Key.LEFT)
    assert_equal(p.value, 0.9)  # not 0.8999999999999999
    p.value = 0.53  # off the grid, as a drag can leave it
    p.key(Key.RIGHT)
    assert_almost_equal(p.value, 0.6)  # the next step after the nearest


def test_keys_do_not_act_on_focus_from_a_click() raises -> None:
    var p = _Panel()
    var at = Point(-120, 40)
    point_at(p.context, at)
    p.frame()
    next_frame(p.context)
    press(p.context, at)
    release(p.context, at)
    p.frame()
    assert_equal(p.focused(), 0)
    p.key(Key.SPACE)
    assert_false(p.clicked[0])  # Space is the game's
    assert_false(p.ui.wants_keyboard())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
