"""Gamepad navigation: the d-pad and left stick move focus to the nearest
widget in that direction, the south button presses, the east button backs
out, and left and right step a focused slider."""
from std.testing import (
    TestSuite,
    assert_almost_equal,
    assert_equal,
    assert_false,
    assert_true,
)

from create import *
from create.ui.ui import _ImmediateUI
from _input import connect_pad, next_frame, press_pad

# A 2 x 2 grid, called in a shuffled order, so moving by direction can't
# lean on the call order.
comptime _ORDER = [3, 0, 2, 1]


def _grid_rect(i: Int) -> Rectangle:
    """0 top left, 1 top right, 2 bottom left, 3 bottom right."""
    var x = -60.0 if i % 2 == 0 else 60.0
    var y = 40.0 if i < 2 else -40.0
    return Rectangle(Point(x, y), 100.0, 40.0)


struct _Grid:
    var ui: _ImmediateUI
    var context: Context
    var clicked: List[Bool]
    var first: Bool

    def __init__(out self, player: Optional[Int] = None):
        self.ui = _ImmediateUI(player=player)
        self.context = Context()
        self.clicked = [False, False, False, False]
        self.first = True
        connect_pad(self.context, 1)
        connect_pad(self.context, 2)

    def frame(mut self) raises:
        var canvas = Canvas(300, 200)
        with self.ui.screen(self.context, canvas) as layer:
            for i in materialize[_ORDER]():
                self.clicked[i] = layer.button(
                    "OK", _grid_rect(i), take_focus=self.first and i == 0
                )
        self.first = False

    def pad(mut self, button: GamepadButton, id: Int = 1) raises:
        next_frame(self.context)
        press_pad(self.context, button, id)
        self.frame()

    def focused(self) -> Int:
        """Which grid cell has focus: -1 for none."""
        if not self.ui._focused:
            return -1
        for k in range(len(self.ui._hits)):
            if self.ui._hits[k].id == self.ui._focused.value():
                return materialize[_ORDER]()[k]
        return -1


def test_the_d_pad_moves_focus_by_direction() raises -> None:
    var grid = _Grid()
    grid.frame()  # focus on the top left, from code
    assert_equal(grid.focused(), 0)
    grid.pad(GamepadButton.DPAD_RIGHT)
    assert_equal(grid.focused(), 1)
    grid.pad(GamepadButton.DPAD_DOWN)
    assert_equal(grid.focused(), 3)
    grid.pad(GamepadButton.DPAD_LEFT)
    assert_equal(grid.focused(), 2)
    grid.pad(GamepadButton.DPAD_UP)
    assert_equal(grid.focused(), 0)
    grid.pad(GamepadButton.DPAD_UP)
    assert_equal(grid.focused(), 0)  # nothing above: stays


def test_from_no_focus_a_push_focuses_the_first_widget() raises -> None:
    var grid = _Grid()
    grid.first = False
    grid.frame()
    grid.pad(GamepadButton.DPAD_DOWN)
    assert_equal(grid.focused(), 3)  # first in call order


def test_the_stick_moves_focus_once_per_push() raises -> None:
    var grid = _Grid()
    grid.frame()
    next_frame(grid.context)
    grid.context._gamepads._axis_moved(1, 0, 0.9)  # left stick right
    grid.frame()
    assert_equal(grid.focused(), 1)
    next_frame(grid.context)
    grid.frame()  # still held: no second move
    assert_equal(grid.focused(), 1)


def test_south_presses_and_east_backs_out() raises -> None:
    var grid = _Grid()
    grid.frame()
    grid.pad(GamepadButton.SOUTH)
    assert_true(grid.clicked[0])
    grid.pad(GamepadButton.EAST)
    assert_equal(grid.focused(), -1)


def test_a_ui_for_one_player_ignores_the_other_pads() raises -> None:
    var grid = _Grid(player=1)  # the second pad to connect
    grid.frame()
    grid.pad(GamepadButton.DPAD_RIGHT, id=1)  # player 0's pad
    assert_equal(grid.focused(), 0)
    grid.pad(GamepadButton.DPAD_RIGHT, id=2)
    assert_equal(grid.focused(), 1)


def test_gamepad_focus_leaves_the_keyboard_to_the_game() raises -> None:
    var grid = _Grid()
    grid.first = False
    grid.frame()
    grid.pad(GamepadButton.DPAD_DOWN)
    assert_true(grid.ui._focus_visible)  # a ring shows
    assert_false(grid.ui.wants_keyboard(grid.context))


def test_left_and_right_step_a_focused_slider() raises -> None:
    var ui = _ImmediateUI()
    var context = Context()
    connect_pad(context, 1)
    var value = 0.5
    for frame in range(3):
        if frame == 1:
            next_frame(context)
            press_pad(context, GamepadButton.DPAD_RIGHT)
        elif frame == 2:
            next_frame(context)
            press_pad(context, GamepadButton.DPAD_LEFT)
            press_pad(context, GamepadButton.DPAD_LEFT)
        var canvas = Canvas(300, 200)
        with ui.screen(context, canvas) as layer:
            layer.slider(
                value, 0, 1, Rectangle((0, 0), 200, 32), take_focus=frame == 0
            )
        if frame == 1:
            assert_almost_equal(value, 0.55)
    assert_almost_equal(value, 0.5)
    assert_true(Bool(ui._focused))  # stepping kept focus on it


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
