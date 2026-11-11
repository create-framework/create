# The windowed loops send the window dials only when the program changes
# them. Driven through a stand-in window, so no display is needed.

from std.testing import TestSuite, assert_equal

from create import *
from create._window import NativeWindow
from create._window.event import Event
from create.core._window_loop import (
    _AppliedWindow,
    _apply_window_dials,
    _apply_window_mode,
)
from create._window import SYSTEM_CURSOR_ARROW, SYSTEM_CURSOR_CROSSHAIR


struct CountingWindow(NativeWindow):
    """Counts what it is told, and remembers the last of it."""

    var titles: Int
    var resizes: Int
    var title: String
    var resizable: Bool
    var modes: Int
    var fullscreen: Bool
    var cursors: Int
    var cursor: Int
    var visibility_changes: Int
    var cursor_visible: Bool
    var locks: Int
    var mouse_locked: Bool
    var text_input_changes: Int
    var text_input: Bool
    var clipboard_writes: Int
    var clipboard_text: String

    def __init__(out self):
        self.titles = 0
        self.resizes = 0
        self.title = ""
        self.resizable = True
        self.modes = 0
        self.fullscreen = False
        self.cursors = 0
        self.cursor = SYSTEM_CURSOR_ARROW
        self.visibility_changes = 0
        self.cursor_visible = True
        self.locks = 0
        self.mouse_locked = False
        self.text_input_changes = 0
        self.text_input = True
        self.clipboard_writes = 0
        self.clipboard_text = ""

    def is_open(self) -> Bool:
        return True

    def close(mut self):
        pass

    def ticks(self) raises -> Int:
        return 0

    def rumble_gamepad(
        self,
        id: Int,
        low_frequency: Float64,
        high_frequency: Float64,
        seconds: Float64,
    ) raises:
        pass

    def events(mut self) raises -> List[Event]:
        return []

    def set_title(mut self, title: String) raises:
        self.titles += 1
        self.title = title

    def set_resizable(mut self, enabled: Bool) raises:
        self.resizes += 1
        self.resizable = enabled

    def set_mode(
        mut self, fullscreen: Bool, borderless: Bool, maximized: Bool
    ) raises:
        self.modes += 1
        self.fullscreen = fullscreen

    def set_system_cursor(mut self, id: Int) raises:
        self.cursors += 1
        self.cursor = id

    def show_cursor(mut self, visible: Bool) raises:
        self.visibility_changes += 1
        self.cursor_visible = visible

    def lock_mouse(mut self, enabled: Bool) raises:
        self.locks += 1
        self.mouse_locked = enabled

    def set_text_input(mut self, enabled: Bool) raises:
        self.text_input_changes += 1
        self.text_input = enabled

    def clipboard(self) raises -> String:
        return self.clipboard_text

    def set_clipboard(mut self, text: String) raises:
        self.clipboard_writes += 1
        self.clipboard_text = text


def test_an_unchanged_dial_is_not_sent() raises -> None:
    var context = Context()
    context.title("Game")
    var applied = _AppliedWindow(context)
    var win = CountingWindow()
    for _ in range(3):
        context.title("Game")
        _apply_window_dials(win, applied, context)
    assert_equal(win.titles, 0)
    assert_equal(win.resizes, 0)
    assert_equal(win.cursors, 0)
    assert_equal(win.visibility_changes, 0)


def test_a_changed_cursor_is_sent_once() raises -> None:
    var context = Context()
    var applied = _AppliedWindow(context)
    var win = CountingWindow()
    for _ in range(3):
        context.cursor(Cursor.CROSSHAIR)
        _apply_window_dials(win, applied, context)
    assert_equal(win.cursors, 1)
    assert_equal(win.cursor, SYSTEM_CURSOR_CROSSHAIR)
    assert_equal(win.visibility_changes, 0, "it was never hidden")


def test_a_hidden_cursor_is_hidden_and_shown_again_with_its_shape() raises -> (
    None
):
    var context = Context()
    var applied = _AppliedWindow(context)
    var win = CountingWindow()
    context.cursor(Cursor.HIDDEN)
    _apply_window_dials(win, applied, context)
    _apply_window_dials(win, applied, context)
    assert_equal(win.visibility_changes, 1)
    assert_equal(win.cursor_visible, False)
    assert_equal(win.cursors, 0, "hiding sets no shape")
    context.cursor(Cursor.CROSSHAIR)
    _apply_window_dials(win, applied, context)
    assert_equal(win.visibility_changes, 2)
    assert_equal(win.cursor_visible, True)
    assert_equal(win.cursors, 1)
    assert_equal(win.cursor, SYSTEM_CURSOR_CROSSHAIR)


def test_an_unnamed_cursor_falls_back_to_the_arrow() raises -> None:
    var context = Context()
    var applied = _AppliedWindow(context)
    var win = CountingWindow()
    win.cursor = -1
    context.cursor(Cursor(99))
    _apply_window_dials(win, applied, context)
    assert_equal(win.cursor, SYSTEM_CURSOR_ARROW)


def test_a_changed_dial_is_sent_once() raises -> None:
    var context = Context()
    context.title("Game")
    var applied = _AppliedWindow(context)
    var win = CountingWindow()
    context.title("Game — level 2")
    context.resizable(False)
    _apply_window_dials(win, applied, context)
    _apply_window_dials(win, applied, context)
    assert_equal(win.titles, 1)
    assert_equal(win.title, "Game — level 2")
    assert_equal(win.resizes, 1)
    assert_equal(win.resizable, False)


def test_a_mode_change_is_sent_once_and_only_by_the_mode_step() raises -> None:
    var context = Context()
    var applied = _AppliedWindow(context)
    var win = CountingWindow()
    context.window_mode(WindowMode.FULLSCREEN)
    _apply_window_dials(win, applied, context)
    assert_equal(win.modes, 0, "not before presenting")
    _apply_window_mode(win, applied, context)
    _apply_window_mode(win, applied, context)
    assert_equal(win.modes, 1)
    assert_equal(win.fullscreen, True)


def test_a_mouse_lock_is_sent_once_and_released() raises -> None:
    var context = Context()
    var applied = _AppliedWindow(context)
    var win = CountingWindow()
    _apply_window_dials(win, applied, context)
    assert_equal(win.locks, 0, "a new window's pointer is already free")
    for _ in range(3):
        context.lock_mouse(True)
        _apply_window_dials(win, applied, context)
    assert_equal(win.locks, 1)
    assert_equal(win.mouse_locked, True)
    context.lock_mouse(False)
    _apply_window_dials(win, applied, context)
    assert_equal(win.locks, 2)
    assert_equal(win.mouse_locked, False)


def test_text_input_is_switched_only_when_changed() raises -> None:
    var context = Context()
    var applied = _AppliedWindow(context)
    var win = CountingWindow()
    _apply_window_dials(win, applied, context)
    assert_equal(win.text_input_changes, 0, "a new window already takes text")
    for _ in range(3):
        context.text_input(False)
        _apply_window_dials(win, applied, context)
    assert_equal(win.text_input_changes, 1)
    assert_equal(win.text_input, False)
    context.text_input(True)
    _apply_window_dials(win, applied, context)
    assert_equal(win.text_input_changes, 2)
    assert_equal(win.text_input, True)


def test_each_clipboard_write_is_sent_once() raises -> None:
    var context = Context()
    var applied = _AppliedWindow(context)
    var win = CountingWindow()
    _apply_window_dials(win, applied, context)
    assert_equal(win.clipboard_writes, 0)
    context.clipboard("copied")
    _apply_window_dials(win, applied, context)
    _apply_window_dials(win, applied, context)
    assert_equal(win.clipboard_writes, 1)
    assert_equal(win.clipboard_text, "copied")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
