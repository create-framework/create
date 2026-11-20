"""Feeding the mouse in a UI test, as the run loop would between frames."""

from create import *


def next_frame(mut context: Context):
    """Start a new frame: clear last frame's presses and releases."""
    context._new_input_frame()
    context._frame_count += 1


def point_at(mut context: Context, position: Point):
    context.mouse._move(position)


def press(mut context: Context, position: Point):
    context.mouse._button_down(MouseButton.LEFT, position)


def release(mut context: Context, position: Point):
    context.mouse._button_up(MouseButton.LEFT, position)


def press_key(mut context: Context, key: Key):
    context.keyboard._key_down(key)


def connect_pad(mut context: Context, id: Int = 1):
    context._gamepads._connect(id, "Test pad")


def press_pad(mut context: Context, button: GamepadButton, id: Int = 1):
    """Press and let go of `button` within the frame: its press reads this
    frame, and nothing stays held."""
    context._gamepads._button_down(id, button)
    context._gamepads._button_up(id, button)
