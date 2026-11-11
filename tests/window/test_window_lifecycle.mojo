"""Headless lifecycle tests for `Window`. Requires `SDL_VIDEODRIVER=dummy`
(no real display) -- forced by this file's `main`.
"""

from std.os import setenv
from std.testing import TestSuite, assert_true, assert_false
from create._window import (
    Window,
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
from _raw_event import events_without_focus


def test_open_then_close() raises -> None:
    var w = Window("t", 100, 100)
    assert_true(w.is_open())
    w.close()
    assert_false(w.is_open())


def test_sequential_create_destroy() raises -> None:
    for _ in range(3):
        var w = Window("t", 64, 64)
        assert_true(w.is_open())


def test_maximized_opens_and_reports_a_size() raises -> None:
    """The dummy driver has no work area to maximize into, so the size it
    reports back is not pinned to anything -- what matters is that the flag
    reaches `SDL_CreateWindow`, the window opens, and the queried size is
    used in place of the request without tripping the teardown path."""
    var w = Window("t", 64, 64, maximized=True)
    assert_true(w.is_open())
    assert_true(w.width() > 0)
    assert_true(w.height() > 0)


def test_title_resizability_and_mode_change_after_opening() raises -> None:
    var w = Window("t", 64, 64)
    w.set_title("renamed")
    w.set_resizable(False)
    w.set_resizable(True)
    # Every mode from every other, ending windowed.
    w.set_mode(True, False, False)
    w.set_mode(False, True, False)
    w.set_mode(False, False, True)
    w.set_mode(False, False, False)
    assert_true(w.is_open())


def test_cursors_change_hide_and_free_with_the_window() raises -> None:
    """The dummy driver has no cursors, so each is refused: what matters is
    that nothing raises, and that a window whose cursors were asked for
    tears down cleanly, again and again."""
    var ids: List[Int] = [
        SYSTEM_CURSOR_ARROW,
        SYSTEM_CURSOR_CROSSHAIR,
        SYSTEM_CURSOR_HAND,
        SYSTEM_CURSOR_TEXT,
        SYSTEM_CURSOR_WAIT,
        SYSTEM_CURSOR_PROGRESS,
        SYSTEM_CURSOR_MOVE,
        SYSTEM_CURSOR_NOT_ALLOWED,
        SYSTEM_CURSOR_RESIZE_HORIZONTAL,
        SYSTEM_CURSOR_RESIZE_VERTICAL,
        SYSTEM_CURSOR_RESIZE_DIAGONAL_RISING,
        SYSTEM_CURSOR_RESIZE_DIAGONAL_FALLING,
    ]
    for _ in range(3):
        var w = Window("t", 64, 64)
        for id in ids:
            w.set_system_cursor(id)
            w.set_system_cursor(id)
        w.show_cursor(False)
        w.show_cursor(True)
        # The dummy driver has no pointer to lock: refused, never raised.
        w.lock_mouse(True)
        w.lock_mouse(False)
        assert_true(w.is_open())


def test_ticks_monotonic() raises -> None:
    var w = Window("t", 64, 64)
    var a = w.ticks()
    var b = w.ticks()
    assert_true(b >= a)


def test_events_empty_when_none_pending() raises -> None:
    var w = Window("t", 64, 64)
    var events = events_without_focus(w)
    assert_true(len(events) == 0)


def main() raises:
    # Every `Window` here expects SDL's dummy driver: no real window opens on
    # the desktop, and `GLWindow` is refused a context. `pixi run test` picks
    # the driver per display, so pin it before the first SDL call reads it.
    _ = setenv("SDL_VIDEODRIVER", "dummy", True)
    TestSuite.discover_tests[__functions_in_module()]().run()
