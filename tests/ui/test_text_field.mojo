"""`TextField` as a value: a click gives it focus, typing reaches only the
field with focus, Enter submits, and it switches `text_input` as its focus
comes and goes, with no `UI`."""
from std.testing import TestSuite, assert_equal, assert_false, assert_true

from create import *
from _input import next_frame, point_at, press, press_key, release

comptime _FIRST = Rectangle((0, 40), 300, 40)
comptime _SECOND = Rectangle((0, -40), 300, 40)
comptime _TOP_EDGE = Point(0.0, 59.5)
"""On the first field's outline, along its top."""


struct _Form:
    """Two standalone text fields."""

    var context: Context
    var fields: List[TextField]

    def __init__(out self):
        self.context = Context()
        self.fields = [TextField(_FIRST), TextField(_SECOND)]

    def frame(mut self) raises:
        var canvas = Canvas(400, 200)
        for ref field in self.fields:
            field.update(self.context, canvas)
            canvas.draw(field)

    def click(mut self, at: Point) raises:
        next_frame(self.context)
        point_at(self.context, at)
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
    assert_equal(form.fields[0].text(), "ab")
    assert_equal(form.fields[1].text(), "")
    assert_true(form.fields[0].changed())
    form.click(_SECOND.position)  # clicking one unfocuses the other
    assert_false(form.fields[0].focused())
    assert_true(form.fields[1].focused())
    form.type("c")
    assert_equal(form.fields[0].text(), "ab")
    assert_equal(form.fields[1].text(), "c")
    assert_false(form.fields[0].changed())


def test_enter_submits_the_focused_field() raises -> None:
    var form = _Form()
    form.click(_FIRST.position)
    form.type("ok")
    form.key(Key.ENTER)
    assert_true(form.fields[0].submitted())
    assert_false(form.fields[1].submitted())
    assert_equal(form.fields[0].text(), "ok")
    next_frame(form.context)
    form.frame()
    assert_false(form.fields[0].submitted())


def test_a_click_elsewhere_or_escape_takes_focus_away() raises -> None:
    var form = _Form()
    form.click(_FIRST.position)
    form.click((0, 95))  # nowhere
    assert_false(form.fields[0].focused())
    form.click(_FIRST.position)
    form.key(Key.ESCAPE)
    assert_false(form.fields[0].focused())


def test_a_click_places_the_caret() raises -> None:
    var form = _Form()
    form.fields[0].set_text("hello")
    form.frame()
    assert_false(form.fields[0].changed())  # the program set it
    # the field's left edge plus its padding: before the first character
    form.click((_FIRST.position.x - _FIRST.width / 2 + 12, 40))
    form.type("X")
    assert_equal(form.fields[0].text(), "Xhello")


def test_text_input_follows_focus_and_is_otherwise_left_alone() raises -> None:
    var form = _Form()
    form.context.text_input(False)  # a game that switched typing off
    form.frame()
    assert_false(form.context.text_input())  # no field has focus: untouched
    form.click(_FIRST.position)
    assert_true(form.context.text_input())
    form.click(_SECOND.position)  # focus moves from one field to the other
    next_frame(form.context)
    form.frame()
    assert_true(form.context.text_input())
    form.click((0, 95))
    assert_false(form.context.text_input())


def test_a_disabled_field_ignores_typing() raises -> None:
    var form = _Form()
    form.fields[0].enabled = False
    form.click(_FIRST.position)
    form.type("ab")
    assert_false(form.fields[0].focused())
    assert_equal(form.fields[0].text(), "")


def test_editing_methods_edit_it_and_count_as_a_change() raises -> None:
    var form = _Form()
    form.fields[0].set_text("hello")
    form.frame()
    form.fields[0].select_all()
    form.fields[0].delete_backward()
    form.fields[0].insert("bye")
    assert_equal(form.fields[0].text(), "bye")
    next_frame(form.context)
    form.frame()
    assert_true(form.fields[0].changed())


def test_max_length_caps_typing() raises -> None:
    var form = _Form()
    form.fields[0].max_length(3)
    form.click(_FIRST.position)
    form.type("abcdef")
    assert_equal(form.fields[0].text(), "abc")


def _field(
    focused: Bool,
    container: Style = Style(),
    focused_container: Style = Style(),
    caret: Style = Style(),
) raises -> Canvas:
    """One frame of an empty field, focused or not, unsmoothed."""
    var context = Context()
    point_at(context, (0, -90))
    var canvas = Canvas(400, 200, antialiasing=Antialiasing.OFF)
    var field = TextField(
        _FIRST,
        container=container,
        focused_container=focused_container,
        caret=caret,
    )
    field.focus(focused)
    field.update(context, canvas)
    canvas.draw(field)
    return canvas^


def test_the_caret_takes_its_own_style() raises -> None:
    # an empty field's caret sits at its left side, inside the padding
    var canvas = _field(True, caret=Style(stroke=Color.RED, stroke_thickness=4))
    assert_equal(canvas.color_at((-139.5, 40)), Color.RED)
    assert_equal(canvas.color_at((-136.5, 40)), Color.RED)


def test_focus_doubles_the_outline_in_primary() raises -> None:
    var colors = ColorScheme.light()
    var resting = _field(False)
    var focused = _field(True)
    assert_equal(resting.color_at(_TOP_EDGE), colors.outline)
    assert_equal(focused.color_at(_TOP_EDGE), colors.primary)
    assert_equal(focused.color_at((0, 58.5)), colors.primary)
    assert_true(resting.color_at((0, 58.5)) != colors.outline)


def test_the_focused_look_is_layered_over_the_container() raises -> None:
    var canvas = _field(
        True,
        container=Style(fill=Color.WHITE, stroke=Color.BLUE),
        focused_container=Style(stroke=Color.RED),
    )
    assert_equal(canvas.color_at(_TOP_EDGE), Color.RED)
    assert_equal(canvas.color_at((0, 50)), Color.WHITE)


def test_focus_taken_away_by_the_program_switches_typing_off() raises -> None:
    var field = TextField(_FIRST)
    var context = Context()
    var canvas = Canvas(400, 200)
    field.focus()
    field.update(context, canvas)
    assert_true(context.text_input())
    context.text_input(False)  # a game switches typing off for its keys
    next_frame(context)
    field.update(context, canvas)
    assert_true(context.text_input())  # the focused field switches it back
    field.focus(False)
    next_frame(context)
    field.update(context, canvas)
    assert_false(context.text_input())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
