"""Several UIs in one program take turns at the keyboard and mouse: one Tab
focuses one field, one keystroke reaches one field, and a drag in one UI
leaves the other's widgets alone."""
from std.testing import TestSuite, assert_equal, assert_false, assert_true

from create import *
from _input import next_frame, point_at, press, press_key, release

comptime _LEFT = Rectangle((-100, 0), 160, 40)
comptime _RIGHT = Rectangle((100, 0), 160, 40)


struct _Split:
    """A text field in each of two UIs, sharing one context."""

    var left: UI
    var right: UI
    var context: Context
    var left_text: String
    var right_text: String
    var open_right: Bool

    def __init__(out self):
        self.left = UI()
        self.right = UI()
        self.context = Context()
        self.left_text = ""
        self.right_text = ""
        self.open_right = True

    def frame(mut self) raises:
        var canvas = Canvas(400, 100)
        with self.left.screen(self.context, canvas) as ui:
            ui.text_field(self.left_text, _LEFT)
        if self.open_right:
            with self.right.screen(self.context, canvas) as ui:
                ui.text_field(self.right_text, _RIGHT)

    def key(mut self, key: Key) raises:
        next_frame(self.context)
        press_key(self.context, key)
        self.frame()

    def type(mut self, text: String) raises:
        next_frame(self.context)
        self.context.keyboard._type_text(text)
        self.frame()

    def click(mut self, at: Point) raises:
        next_frame(self.context)
        point_at(self.context, at)
        self.frame()
        next_frame(self.context)
        press(self.context, at)
        release(self.context, at)
        self.frame()


def test_one_tab_focuses_one_field_across_uis() raises -> None:
    var split = _Split()
    split.frame()
    split.key(Key.TAB)
    split.type("x")
    assert_equal(split.left_text, "x")
    assert_equal(split.right_text, "")


def test_a_click_in_one_ui_takes_the_keyboard_from_the_other() raises -> None:
    var split = _Split()
    split.frame()
    split.click(_LEFT.position)
    split.type("a")
    split.click(_RIGHT.position)
    split.type("b")
    assert_equal(split.left_text, "a")
    assert_equal(split.right_text, "b")
    assert_false(Bool(split.left._focused))


def test_a_ui_that_stops_opening_layers_lets_go_of_the_keyboard() raises -> (
    None
):
    var split = _Split()
    split.frame()
    split.click(_RIGHT.position)
    split.open_right = False  # its scene is hidden; its claim isn't renewed
    next_frame(split.context)
    split.frame()
    split.key(Key.TAB)
    split.type("z")
    assert_equal(split.left_text, "z")


def test_a_drag_in_one_ui_leaves_the_others_widgets_alone() raises -> None:
    var top = UI()
    var bottom = UI()
    var context = Context()
    var value = 0.5
    var clicked = False
    var track = Rectangle((0, 30), 200, 32)
    var button = Rectangle((0, -30), 120, 40)
    point_at(context, track.position)
    for frame in range(4):
        if frame == 1:
            next_frame(context)
            press(context, track.position)  # take hold of the slider
        elif frame == 2:
            next_frame(context)
            point_at(context, button.position)  # drag over the other UI
        elif frame == 3:
            next_frame(context)
            release(context, button.position)  # and let go on its button
        var canvas = Canvas(300, 120)
        with top.screen(context, canvas) as ui:
            ui.slider(value, 0, 1, track)
        with bottom.screen(context, canvas) as ui:
            clicked = ui.button("OK", button)
        if frame == 2:
            assert_false(Bool(bottom._hot))  # not hovered under the drag
    assert_false(clicked)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
