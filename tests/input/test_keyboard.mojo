from std.testing import TestSuite, assert_equal, assert_false, assert_true
from create.input.keyboard import Keyboard
from create.input.key import Key
from create.core.context import Context
from create.render._viewport import Viewport
from create.core._events import apply_events
from create._window.event import Event, FocusLost, KeyDown, KeyUp, TextInput


def test_key_prints_as_its_constant() raises -> None:
    assert_equal(String(Key.PAGE_UP), "Key.PAGE_UP")
    assert_equal(String(Key.ZERO), "Key.ZERO")
    assert_equal(String(Key.SHIFT), "Key.SHIFT")
    assert_equal(String(Key(ord("/"))), "Key.SLASH")
    assert_equal(String(Key(0x0444)), "Key(1092)")
    assert_equal(String(Key.NONE), "Key.NONE")


def test_key_from_name() raises -> None:
    assert_equal(Key.from_name("page_up").value(), Key.PAGE_UP)
    assert_equal(Key.from_name("Left_Ctrl").value(), Key.LEFT_CTRL)
    assert_equal(Key.from_name("a").value(), Key.A)
    assert_false(Key.from_name("nonexistent_key"))
    assert_equal(Key.from_name("slash").value(), Key.SLASH)
    assert_equal(Key.from_name("/").value(), Key.SLASH)
    assert_equal(Key.from_name("7").value(), Key.SEVEN)
    assert_equal(Key.from_name("seven").value(), Key.SEVEN)
    assert_equal(Key.from_name("A").value(), Key.A)
    assert_false(Key.from_name(""))


def test_no_keys_down_initially() raises -> None:
    var keyboard = Keyboard()
    assert_equal(keyboard.down(Key(65)), False)
    assert_equal(keyboard.down(Key.A), False)


def test_key_down_by_keycode() raises -> None:
    var keyboard = Keyboard()
    keyboard._held.set(Key(65))
    assert_true(keyboard.down(Key(65)))
    assert_equal(keyboard.down(Key(66)), False)


def test_key_pressed_keycode() raises -> None:
    var keyboard = Keyboard()
    keyboard._pressed.set(Key(65))
    assert_true(keyboard.pressed(Key(65)))
    assert_equal(keyboard.pressed(Key(66)), False)


def test_key_released_keycode() raises -> None:
    var keyboard = Keyboard()
    keyboard._released.set(Key(65))
    assert_true(keyboard.released(Key(65)))
    assert_equal(keyboard.released(Key(66)), False)


def test_multiple_keys_held() raises -> None:
    var keyboard = Keyboard()
    keyboard._held.set(Key(ord("a")))
    keyboard._held.set(Key(ord("d")))
    assert_true(keyboard.down(Key.A))
    assert_true(keyboard.down(Key.D))
    assert_equal(keyboard.down(Key.W), False)


def test_named_key_escape() raises -> None:
    var keyboard = Keyboard()
    keyboard._held.set(Key.ESCAPE)
    assert_true(keyboard.down(Key.ESCAPE))


def test_named_key_space() raises -> None:
    var keyboard = Keyboard()
    keyboard._held.set(Key.SPACE)
    assert_true(keyboard.down(Key.SPACE))


def test_named_key_enter() raises -> None:
    var keyboard = Keyboard()
    keyboard._held.set(Key.ENTER)
    assert_true(keyboard.down(Key.ENTER))


def test_named_key_arrow_up() raises -> None:
    var keyboard = Keyboard()
    keyboard._held.set(Key.UP)
    assert_true(keyboard.down(Key.UP))


def test_named_key_ctrl_both_sides() raises -> None:
    var keyboard = Keyboard()
    keyboard._held.set(Key.LEFT_CTRL)
    assert_true(keyboard.down(Key.CTRL))
    keyboard._held.clear_all()
    keyboard._held.set(Key.RIGHT_CTRL)
    assert_true(keyboard.down(Key.CTRL))


def test_key_initial() raises -> None:
    var keyboard = Keyboard()
    assert_equal(keyboard.key, Key.NONE)


def test_key_is_the_most_recent_press_and_outlives_release() raises -> None:
    var context = Context()
    var events = List[Event]()
    events.append(KeyDown(Key.A.value))
    events.append(KeyDown(Key.B.value))
    events.append(KeyUp(Key.B.value))
    _ = apply_events(events, Viewport(), context)
    assert_equal(context.keyboard.key, Key.B)


def test_key_ignores_auto_repeat_of_a_held_key() raises -> None:
    var context = Context()
    var events = List[Event]()
    events.append(KeyDown(Key.A.value))
    events.append(KeyDown(Key.B.value))
    events.append(KeyDown(Key.A.value))
    _ = apply_events(events, Viewport(), context)
    assert_equal(context.keyboard.key, Key.B)


def test_key_typed_counts_a_press_and_each_auto_repeat() raises -> None:
    var context = Context()
    var events = List[Event]()
    events.append(KeyDown(Key.BACKSPACE.value))
    _ = apply_events(events, Viewport(), context)
    assert_true(context.keyboard.typed(Key.BACKSPACE))
    assert_true(context.keyboard.pressed(Key.BACKSPACE))

    # Held, then auto-repeated: typed again, but not a new press.
    events.clear()
    _ = apply_events(events, Viewport(), context)
    assert_false(context.keyboard.typed(Key.BACKSPACE))
    events.append(KeyDown(Key.BACKSPACE.value))
    _ = apply_events(events, Viewport(), context)
    assert_true(context.keyboard.typed(Key.BACKSPACE))
    assert_false(context.keyboard.pressed(Key.BACKSPACE))


def test_text_joins_a_frames_input_and_clears_the_next() raises -> None:
    var context = Context()
    var events = List[Event]()
    events.append(TextInput("h"))
    events.append(TextInput("é"))
    _ = apply_events(events, Viewport(), context)
    assert_equal(context.keyboard.text, "hé")

    events.clear()
    _ = apply_events(events, Viewport(), context)
    assert_equal(context.keyboard.text, "")


def test_keycodes_outside_ascii_and_named_keys() raises -> None:
    # AltGr's `MODE` (scancode 257 | 1 << 30), a Cyrillic letter's codepoint
    # and an extended key (1 << 29): all valid SDL keycodes a fixed-width
    # bitmask would index out of range.
    var context = Context()
    var events = List[Event]()
    for keycode in [(1 << 30) | 257, 0x0444, (1 << 29) | 1]:
        events.append(KeyDown(keycode))
    _ = apply_events(events, Viewport(), context)
    for keycode in [(1 << 30) | 257, 0x0444, (1 << 29) | 1]:
        assert_true(context.keyboard.down(Key(keycode)))
        assert_true(context.keyboard.pressed(Key(keycode)))

    events.clear()
    events.append(KeyUp((1 << 30) | 257))
    _ = apply_events(events, Viewport(), context)
    assert_false(context.keyboard.down(Key((1 << 30) | 257)))
    assert_true(context.keyboard.released(Key((1 << 30) | 257)))
    assert_true(context.keyboard.down(Key(0x0444)))


def test_named_key_shift_both_sides() raises -> None:
    var keyboard = Keyboard()
    keyboard._held.set(Key(1073742049))  # left shift
    assert_true(keyboard.down(Key.SHIFT))
    keyboard._held.clear_all()
    keyboard._held.set(Key(1073742053))  # right shift
    assert_true(keyboard.down(Key.SHIFT))


def test_named_key_left_shift_specific() raises -> None:
    var keyboard = Keyboard()
    keyboard._held.set(Key(1073742049))
    assert_true(keyboard.down(Key.LEFT_SHIFT))
    assert_equal(keyboard.down(Key.RIGHT_SHIFT), False)


def test_named_key_alt_both_sides() raises -> None:
    var keyboard = Keyboard()
    keyboard._held.set(Key(1073742050))  # left alt
    assert_true(keyboard.down(Key.ALT))
    keyboard._held.clear_all()
    keyboard._held.set(Key(1073742054))  # right alt
    assert_true(keyboard.down(Key.ALT))


def test_named_key_super_both_sides() raises -> None:
    var keyboard = Keyboard()
    keyboard._held.set(Key(1073742051))  # left super
    assert_true(keyboard.down(Key.SUPER))
    keyboard._held.clear_all()
    keyboard._held.set(Key(1073742055))  # right super
    assert_true(keyboard.down(Key.SUPER))


def test_named_key_arrow_down() raises -> None:
    var keyboard = Keyboard()
    keyboard._held.set(Key(1073741905))
    assert_true(keyboard.down(Key.DOWN))


def test_named_key_arrow_left() raises -> None:
    var keyboard = Keyboard()
    keyboard._held.set(Key(1073741904))
    assert_true(keyboard.down(Key.LEFT))


def test_named_key_arrow_right() raises -> None:
    var keyboard = Keyboard()
    keyboard._held.set(Key(1073741903))
    assert_true(keyboard.down(Key.RIGHT))


def test_named_key_home() raises -> None:
    var keyboard = Keyboard()
    keyboard._held.set(Key(1073741898))
    assert_true(keyboard.down(Key.HOME))


def test_named_key_end() raises -> None:
    var keyboard = Keyboard()
    keyboard._held.set(Key(1073741901))
    assert_true(keyboard.down(Key.END))


def test_named_key_page_up() raises -> None:
    var keyboard = Keyboard()
    keyboard._held.set(Key(1073741899))
    assert_true(keyboard.down(Key.PAGE_UP))


def test_named_key_page_down() raises -> None:
    var keyboard = Keyboard()
    keyboard._held.set(Key(1073741902))
    assert_true(keyboard.down(Key.PAGE_DOWN))


def test_named_key_insert() raises -> None:
    var keyboard = Keyboard()
    keyboard._held.set(Key(1073741897))
    assert_true(keyboard.down(Key.INSERT))


def test_named_key_backspace() raises -> None:
    var keyboard = Keyboard()
    keyboard._held.set(Key(8))
    assert_true(keyboard.down(Key.BACKSPACE))


def test_named_key_tab() raises -> None:
    var keyboard = Keyboard()
    keyboard._held.set(Key(9))
    assert_true(keyboard.down(Key.TAB))


def test_named_key_delete() raises -> None:
    var keyboard = Keyboard()
    keyboard._held.set(Key(127))
    assert_true(keyboard.down(Key.DELETE))


def test_named_key_caps_lock() raises -> None:
    var keyboard = Keyboard()
    keyboard._held.set(Key.CAPS_LOCK)
    assert_true(keyboard.down(Key.CAPS_LOCK))


def test_named_key_f1() raises -> None:
    var keyboard = Keyboard()
    keyboard._held.set(Key.F1)
    assert_true(keyboard.down(Key.F1))


def test_named_key_f12() raises -> None:
    var keyboard = Keyboard()
    keyboard._held.set(Key.F12)
    assert_true(keyboard.down(Key.F12))


def test_key_pressed_named_key() raises -> None:
    var keyboard = Keyboard()
    keyboard._pressed.set(Key.ESCAPE)
    assert_true(keyboard.pressed(Key.ESCAPE))
    assert_equal(keyboard.pressed(Key.SPACE), False)


def test_key_released_named_key() raises -> None:
    var keyboard = Keyboard()
    keyboard._released.set(Key.SPACE)
    assert_true(keyboard.released(Key.SPACE))
    assert_equal(keyboard.released(Key.ESCAPE), False)


def test_new_frame_clears_pressed_and_released() raises -> None:
    var keyboard = Keyboard()
    keyboard._pressed.set(Key(65))
    keyboard._released.set(Key(66))
    keyboard._new_frame()
    assert_equal(keyboard.pressed(Key(65)), False)
    assert_equal(keyboard.released(Key(66)), False)


def test_none_is_never_down() raises -> None:
    var keyboard = Keyboard()
    keyboard._held.set(Key.A)
    assert_false(keyboard.down(Key.NONE))


def test_new_frame_leaves_held_keys_alone() raises -> None:
    var keyboard = Keyboard()
    keyboard._held.set(Key(65))
    keyboard._new_frame()
    assert_true(keyboard.down(Key(65)))


def test_focus_lost_releases_held_keys() raises -> None:
    # Alt-tabbing away while holding a key: its release goes to another
    # window, so without this it would stay down until pressed again.
    var context = Context()
    var events: List[Event] = [KeyDown(Key.D.value), KeyDown(Key.SHIFT.value)]
    _ = apply_events(events, Viewport(), context)
    assert_true(context.keyboard.down(Key.D))

    events = [FocusLost()]
    _ = apply_events(events, Viewport(), context)
    assert_false(context.keyboard.down(Key.D))
    assert_true(context.keyboard.released(Key.D))

    _ = apply_events([], Viewport(), context)
    assert_false(context.keyboard.released(Key.D))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
