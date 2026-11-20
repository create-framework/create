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
