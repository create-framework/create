"""`ui.text_field`: typing reaches only the focused field, Enter submits,
clicking places the caret, and the UI switches `text_input` as focus comes
and goes."""
from std.testing import (
    TestSuite,
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
)

from create import *
from _input import next_frame, point_at, press, press_key, release

comptime _FIRST = Rectangle((0, 40), 300, 40)
comptime _SECOND = Rectangle((0, -40), 300, 40)


struct _Form:
    """Two text fields, the first optionally disabled."""

    var ui: UI
    var context: Context
    var texts: List[String]
    var changed: List[Bool]
    var submitted: List[Bool]
    var disable_first: Bool

    def __init__(out self):
        self.ui = UI()
        self.context = Context()
        self.texts = ["", ""]
        self.changed = [False, False]
        self.submitted = [False, False]
        self.disable_first = False

    def frame(mut self) raises:
        var canvas = Canvas(400, 200)
        var rects = [_FIRST, _SECOND]
        with self.ui.screen(self.context, canvas) as layer:
            for i in range(2):
                layer.text_field(
                    self.texts[i],
                    rects[i],
                    disabled=self.disable_first and i == 0,
                )
                self.changed[i] = layer.changed()
                self.submitted[i] = layer.submitted()

    def click(mut self, at: Point) raises:
        next_frame(self.context)
        point_at(self.context, at)
        self.frame()
        next_frame(self.context)
        press(self.context, at)
        release(self.context, at)
        self.frame()

    def type(mut self, text: String) raises:
        next_frame(self.context)
        self.context.keyboard._type_text(text)
        self.frame()

    def key(mut self, key: Key) raises:
        next_frame(self.context)
        press_key(self.context, key)
        self.frame()


def test_typing_reaches_only_the_focused_field() raises -> None:
    var form = _Form()
    form.frame()
    form.click(_FIRST.position)
    form.type("ab")
    assert_equal(form.texts[0], "ab")
    assert_equal(form.texts[1], "")
    assert_true(form.changed[0])
    form.click(_SECOND.position)
    form.type("c")
    assert_equal(form.texts[0], "ab")
    assert_equal(form.texts[1], "c")
    assert_false(form.changed[0])


def test_a_field_with_focus_wants_the_keyboard() raises -> None:
    var form = _Form()
    form.frame()
    form.click(_FIRST.position)
    assert_true(form.ui.wants_keyboard())  # even from a click
    form.click(Point(0, 95))  # nowhere
    next_frame(form.context)
    form.frame()
    assert_false(form.ui.wants_keyboard())


def test_enter_submits_the_focused_field() raises -> None:
    var form = _Form()
    form.frame()
    form.click(_FIRST.position)
    form.type("ok")
    form.key(Key.ENTER)
    assert_true(form.submitted[0])
    assert_false(form.submitted[1])
    assert_equal(form.texts[0], "ok")
    next_frame(form.context)
    form.frame()
    assert_false(form.submitted[0])


def test_a_click_places_the_caret() raises -> None:
    var form = _Form()
    form.texts[0] = "hello"
    form.frame()
    # the field's left edge plus its padding: before the first character
    form.click(Point(_FIRST.position.x - _FIRST.width / 2 + 12, 40))
    form.type("X")
    assert_equal(form.texts[0], "Xhello")


def test_tab_reaches_a_field_and_typing_follows() raises -> None:
    var form = _Form()
    form.frame()
    form.key(Key.TAB)
    form.type("a")
    form.key(Key.TAB)
    form.type("z")
    assert_equal(form.texts[0], "a")
    assert_equal(form.texts[1], "z")
    form.key(Key.TAB)  # round to the first
    form.type("b")
    assert_equal(form.texts[0], "ab")
    assert_equal(form.texts[1], "z")


def test_tab_and_typing_in_one_frame_land_in_the_new_field() raises -> None:
    var form = _Form()
    form.frame()
    form.click(_FIRST.position)
    next_frame(form.context)
    press_key(form.context, Key.TAB)
    form.context.keyboard._type_text("q")
    form.frame()
    assert_equal(form.texts[0], "")
    assert_equal(form.texts[1], "q")


def test_text_input_follows_focus_and_is_otherwise_left_alone() raises -> None:
    var form = _Form()
    form.context.text_input(False)  # a game that switched typing off
    form.frame()
    assert_false(form.context.text_input())  # no field has focus: untouched
    form.click(_FIRST.position)
    assert_true(form.context.text_input())
    form.click(Point(0, 95))
    next_frame(form.context)
    form.frame()
    assert_false(form.context.text_input())
    form.context.text_input(True)  # the game's own use
    next_frame(form.context)
    form.frame()
    assert_true(form.context.text_input())


def test_a_disabled_field_ignores_typing() raises -> None:
    var form = _Form()
    form.disable_first = True
    form.frame()
    form.click(_FIRST.position)
    form.type("ab")
    assert_equal(form.texts[0], "")


def test_the_editor_edits_the_field_at_its_next_call() raises -> None:
    var ui = UI()
    var context = Context()
    var canvas = Canvas(400, 200)
    var name = String("Ada Lovelace")
    for frame in range(2):
        if frame == 1:
            next_frame(context)
        with ui.screen(context, canvas) as layer:
            layer.text_field(name, _FIRST)
            if frame == 1:
                assert_true(layer.changed())
                break
            var editor = layer.text_editor()
            assert_equal(editor.before_caret(), "Ada Lovelace")
            editor.move_word_left()
            editor.move_word_left(select=True)
            assert_equal(editor.selected_text(), "Ada ")
            editor.delete_backward()
            editor.move_to_end()
            editor.insert("!")
            assert_equal(name, "Ada Lovelace")  # not until the next call
    assert_equal(name, "Lovelace!")


def test_the_editor_needs_a_text_field_called_last() raises -> None:
    var ui = UI()
    var context = Context()
    var canvas = Canvas(400, 200)
    var name = String("Ada")
    with ui.screen(context, canvas) as layer:
        with assert_raises():
            _ = layer.text_editor()
        layer.text_field(name, _FIRST)
        _ = layer.button("OK", _SECOND)
        with assert_raises():
            _ = layer.text_editor()


def test_text_the_program_changes_is_what_the_field_shows() raises -> None:
    var form = _Form()
    form.frame()
    form.click(_FIRST.position)
    form.type("abc")
    form.texts[0] = ""  # emptied by the program, as after submitting
    form.type("d")
    assert_equal(form.texts[0], "d")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
