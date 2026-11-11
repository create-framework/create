from std.sys.info import CompilationTarget
from std.testing import TestSuite, assert_equal

from create.core.context import Context
from create.core.editable_text import EditableText
from create.input.key import Key
from create.core._events import apply_events
from create.render._viewport import Viewport
from create._window.event import Event, KeyDown, KeyUp, TextInput


def _type(mut field: EditableText, var events: List[Event]) raises:
    """Fold `events` as one frame and feed it to `field`."""
    var context = Context()
    _type(field, events^, context)


def _type(
    mut field: EditableText, var events: List[Event], mut context: Context
) raises:
    """Fold `events` as one frame of `context` and feed it to `field`."""
    _ = apply_events(events, Viewport(), context)
    field.update(context)


comptime _MACOS = CompilationTarget.is_macos()
# The platform's command and word modifiers, as `EditableText` reads them.
comptime _COMMAND = Key.LEFT_SUPER if _MACOS else Key.LEFT_CTRL
comptime _WORD = Key.LEFT_ALT if _MACOS else Key.LEFT_CTRL


def _with(modifier: Key, key: Key, label: Int = 0) -> List[Event]:
    """`key` typed with `modifier` held, then both let go."""
    return [
        KeyDown(modifier.value),
        KeyDown(key.value, label),
        KeyUp(key.value),
        KeyUp(modifier.value),
    ]


def test_starts_with_the_caret_after_its_text() raises -> None:
    var field = EditableText("abc")
    assert_equal(field.before_caret(), "abc")
    assert_equal(field.after_caret(), "")
    assert_equal(EditableText().text, "")


def test_update_appends_typed_text() raises -> None:
    var field = EditableText()
    _type(field, [TextInput("h"), TextInput("é")])
    assert_equal(field.text, "hé")
    assert_equal(field.before_caret(), "hé")


def test_typing_mid_string_inserts_at_the_caret() raises -> None:
    var field = EditableText("ac")
    _type(field, [KeyDown(Key.LEFT.value)])
    _type(field, [TextInput("b")])
    assert_equal(field.text, "abc")
    assert_equal(field.before_caret(), "ab")


def test_backspace_removes_a_whole_character() raises -> None:
    var field = EditableText("Zoë")
    _type(field, [KeyDown(Key.BACKSPACE.value)])
    assert_equal(field.text, "Zo")
    field.delete_backward()
    field.delete_backward()
    field.delete_backward()
    assert_equal(field.text, "")


def test_delete_removes_the_character_after_the_caret() raises -> None:
    var field = EditableText("éa")
    _type(field, [KeyDown(Key.HOME.value)])
    _type(field, [KeyDown(Key.DELETE.value)])
    assert_equal(field.text, "a")
    assert_equal(field.before_caret(), "")
    _type(field, [KeyDown(Key.END.value)])
    field.delete_forward()
    assert_equal(field.text, "a")


def test_caret_moves_by_characters_and_stops_at_the_ends() raises -> None:
    var field = EditableText("aé")
    field.move_left()
    assert_equal(field.before_caret(), "a")
    field.move_left()
    field.move_left()
    assert_equal(field.before_caret(), "")
    field.move_right()
    field.move_right()
    field.move_right()
    assert_equal(field.before_caret(), "aé")


def test_held_backspace_keeps_deleting() raises -> None:
    # A second KeyDown while held is an auto-repeat, which repeats the edit.
    var field = EditableText("abc")
    var context = Context()
    for _ in range(2):
        var events: List[Event] = [KeyDown(Key.BACKSPACE.value)]
        _ = apply_events(events, Viewport(), context)
        field.update(context)
    assert_equal(field.text, "a")


def test_reassigning_text_keeps_the_caret_inside_it() raises -> None:
    var field = EditableText("hello")
    field.text = "é"
    assert_equal(field.before_caret(), "é")
    field.text = ""
    assert_equal(field.before_caret(), "")
    _type(field, [TextInput("x")])
    assert_equal(field.text, "x")


def test_prints_as_source() raises -> None:
    assert_equal(String(EditableText("hi")), 'EditableText(text="hi")')
    assert_equal(
        String(EditableText("hi", max_length=8)),
        'EditableText(text="hi", max_length=8)',
    )


def test_a_frames_typing_lands_in_the_order_it_came() raises -> None:
    # "a", Left, "b" within one frame: b goes before a, as typed — not after
    # it, as applying all the text before all the keys would put it.
    var field = EditableText()
    _type(field, [TextInput("a"), KeyDown(Key.LEFT.value), TextInput("b")])
    assert_equal(field.text, "ba")
    assert_equal(field.before_caret(), "b")


def test_shift_extends_a_selection_that_typing_replaces() raises -> None:
    var field = EditableText("hello")
    _type(
        field,
        [
            KeyDown(Key.LEFT_SHIFT.value),
            KeyDown(Key.LEFT.value),
            KeyDown(Key.LEFT.value),
            KeyUp(Key.LEFT_SHIFT.value),
        ],
    )
    assert_equal(field.selected_text(), "lo")
    assert_equal(field.before_selection(), "hel")
    _type(field, [TextInput("p!")])
    assert_equal(field.text, "help!")
    assert_equal(field.selected_text(), "")


def test_a_move_without_shift_collapses_the_selection() raises -> None:
    var field = EditableText("abcd")
    field.select_all()
    field.move_left()
    assert_equal(field.selected_text(), "")
    assert_equal(field.before_caret(), "")
    field.select_all()
    field.move_right()
    assert_equal(field.before_caret(), "abcd")


def test_backspace_and_delete_take_the_selection() raises -> None:
    var field = EditableText("abcd")
    field.move_left(select=True)
    field.move_left(select=True)
    _type(field, [KeyDown(Key.BACKSPACE.value)])
    assert_equal(field.text, "ab")
    field.move_to_start(select=True)
    field.delete_forward()
    assert_equal(field.text, "")


def test_words_move_and_delete_as_one() raises -> None:
    var field = EditableText("café au lait")
    field.move_word_left()
    assert_equal(field.after_caret(), "lait")
    field.move_word_left()
    assert_equal(field.after_caret(), "au lait")
    field.move_word_right()
    assert_equal(field.before_caret(), "café au")
    field.delete_word_backward()
    assert_equal(field.text, "café  lait")
    field.move_to_start()
    field.delete_word_forward()
    assert_equal(field.text, "  lait")


def test_the_word_modifier_moves_by_words() raises -> None:
    var field = EditableText("one two")
    _type(field, _with(_WORD, Key.LEFT))
    assert_equal(field.after_caret(), "two")
    _type(field, _with(_WORD, Key.BACKSPACE))
    assert_equal(field.text, "two")


def test_home_and_end_with_shift_select() raises -> None:
    var field = EditableText("abc")
    _type(
        field,
        [
            KeyDown(Key.LEFT_SHIFT.value),
            KeyDown(Key.HOME.value),
            KeyUp(Key.LEFT_SHIFT.value),
        ],
    )
    assert_equal(field.selected_text(), "abc")


def test_copy_cut_and_paste_go_through_the_clipboard() raises -> None:
    var context = Context()
    var field = EditableText("hello world")
    _type(field, _with(_COMMAND, Key.A), context)
    assert_equal(field.selected_text(), "hello world")
    _type(field, _with(_COMMAND, Key.C), context)
    assert_equal(context.clipboard(), "hello world")

    field.move_to_end()
    field.move_word_left(select=True)
    _type(field, _with(_COMMAND, Key.X), context)
    assert_equal(context.clipboard(), "world")
    assert_equal(field.text, "hello ")
    field.select_all()

    context.clipboard("two\nlines")
    _type(field, _with(_COMMAND, Key.V), context)
    assert_equal(field.text, "two lines")


def test_shortcuts_follow_the_label_on_the_key() raises -> None:
    # On AZERTY the key labelled A sits where QWERTY has Q: select-all is
    # the key labelled A, wherever it is.
    var field = EditableText("abc")
    _type(field, _with(_COMMAND, Key.Q, label=ord("a")))
    assert_equal(field.selected_text(), "abc")


def test_max_length_cuts_typing_and_pasting_short() raises -> None:
    var context = Context()
    var field = EditableText("ab", max_length=4)
    _type(field, [TextInput("cdef")], context)
    assert_equal(field.text, "abcd")
    _type(field, [TextInput("x")], context)
    assert_equal(field.text, "abcd")

    # Replacing a selection frees its room first.
    field.move_left(select=True)
    field.move_left(select=True)
    context.clipboard("éèê")
    field.paste(context)
    assert_equal(field.text, "abéè")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
