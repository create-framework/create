"""What both windowed loops do once a frame is presented, whatever window
they present through. Separate from `_step.mojo`, which the headless loops
import and which must not pull in a window."""

from std.time import sleep

from create._window import (
    NativeWindow,
    SYSTEM_CURSOR_ARROW,
    SYSTEM_CURSOR_CROSSHAIR,
    SYSTEM_CURSOR_HAND,
    SYSTEM_CURSOR_MOVE,
    SYSTEM_CURSOR_NOT_ALLOWED,
    SYSTEM_CURSOR_PROGRESS,
    SYSTEM_CURSOR_RESIZE_DIAGONAL_FALLING,
    SYSTEM_CURSOR_RESIZE_DIAGONAL_RISING,
    SYSTEM_CURSOR_RESIZE_HORIZONTAL,
    SYSTEM_CURSOR_RESIZE_VERTICAL,
    SYSTEM_CURSOR_TEXT,
    SYSTEM_CURSOR_WAIT,
)
from create.core.context import Context
from create.core.cursor import Cursor
from create.core.window_mode import WindowMode


struct _AppliedWindow(Movable):
    """What the window was last told, so a dial is sent to it only when the
    program changes it — not every frame."""

    var title: String
    var resizable: Bool
    var cursor: Cursor
    var mouse_locked: Bool
    var text_input: Bool
    var clipboard_writes: Int
    var mode: WindowMode

    def __init__(out self, context: Context):
        """Seeded from the dials as `run` set them, which the window was
        opened with."""
        self.title = context._title
        self.resizable = context._resizable
        # Seeded before `create` runs, from the default: the arrow a new
        # window shows.
        self.cursor = context._cursor
        # A new window leaves the pointer free.
        self.mouse_locked = False
        # A window starts taking text as it opens.
        self.text_input = True
        self.clipboard_writes = context._clipboard_writes
        self.mode = context._window_mode


def _apply_window_dials[
    W: NativeWindow
](mut win: W, mut applied: _AppliedWindow, context: Context) raises:
    """Send the window the title, resizability, cursor, pointer lock, text
    input and clipboard the program set, if they changed. Called before presenting, so the change shows with the
    frame it was made in."""
    if context._title != applied.title:
        win.set_title(context._title)
        applied.title = context._title
    if context._resizable != applied.resizable:
        win.set_resizable(context._resizable)
        applied.resizable = context._resizable
    var cursor = context._cursor
    if cursor != applied.cursor:
        if cursor == Cursor.HIDDEN:
            win.show_cursor(False)
        else:
            if applied.cursor == Cursor.HIDDEN:
                win.show_cursor(True)
            win.set_system_cursor(_system_cursor(cursor))
        applied.cursor = cursor
    if context._lock_mouse != applied.mouse_locked:
        win.lock_mouse(context._lock_mouse)
        applied.mouse_locked = context._lock_mouse
    if context._text_input != applied.text_input:
        win.set_text_input(context._text_input)
        applied.text_input = context._text_input
    if context._clipboard_writes != applied.clipboard_writes:
        win.set_clipboard(context._clipboard)
        applied.clipboard_writes = context._clipboard_writes


def _system_cursor(cursor: Cursor) -> Int:
    """`cursor` as the window layer's system cursor id; an unnamed value
    falls back to the arrow. Not for `Cursor.HIDDEN`, which is no cursor."""
    if cursor == Cursor.CROSSHAIR:
        return SYSTEM_CURSOR_CROSSHAIR
    if cursor == Cursor.HAND:
        return SYSTEM_CURSOR_HAND
    if cursor == Cursor.TEXT:
        return SYSTEM_CURSOR_TEXT
    if cursor == Cursor.WAIT:
        return SYSTEM_CURSOR_WAIT
    if cursor == Cursor.PROGRESS:
        return SYSTEM_CURSOR_PROGRESS
    if cursor == Cursor.MOVE:
        return SYSTEM_CURSOR_MOVE
    if cursor == Cursor.NOT_ALLOWED:
        return SYSTEM_CURSOR_NOT_ALLOWED
    if cursor == Cursor.RESIZE_HORIZONTAL:
        return SYSTEM_CURSOR_RESIZE_HORIZONTAL
    if cursor == Cursor.RESIZE_VERTICAL:
        return SYSTEM_CURSOR_RESIZE_VERTICAL
    if cursor == Cursor.RESIZE_DIAGONAL_RISING:
        return SYSTEM_CURSOR_RESIZE_DIAGONAL_RISING
    if cursor == Cursor.RESIZE_DIAGONAL_FALLING:
        return SYSTEM_CURSOR_RESIZE_DIAGONAL_FALLING
    return SYSTEM_CURSOR_ARROW


def _apply_window_mode[
    W: NativeWindow
](mut win: W, mut applied: _AppliedWindow, context: Context) raises:
    """Switch the window's mode if the program changed it. Called after
    presenting: the frame just shown was drawn for the old size, and the
    loop reads the new one at the top of the next."""
    var mode = context._window_mode
    if mode == applied.mode:
        return
    win.set_mode(
        fullscreen=mode == WindowMode.FULLSCREEN,
        borderless=mode == WindowMode.BORDERLESS,
        maximized=mode == WindowMode.MAXIMIZED,
    )
    applied.mode = mode


def _finish_frame[
    W: NativeWindow
](mut win: W, context: Context, frame_start: Int) raises:
    """Hand this frame's `context.rumble` calls to the pads, then sleep off
    whatever is left of the target frame duration, if any."""
    for rumble in context._rumbles:
        win.rumble_gamepad(
            rumble.id,
            rumble.low_frequency,
            rumble.high_frequency,
            rumble.seconds,
        )
    if context._max_frame_rate <= 0:
        return
    var worked_ms = win.ticks() - frame_start
    var target_ms = 1000.0 / Float64(context._max_frame_rate)
    var remaining_ms = target_ms - Float64(worked_ms)
    if remaining_ms > 0.0:
        sleep(remaining_ms / 1000.0)
