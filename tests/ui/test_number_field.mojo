"""`NumberField`: typing a number, stepping it with the buttons, the arrows
and a gamepad, and keeping it within its range."""
from std.testing import TestSuite, assert_equal, assert_false, assert_true

from create import *
from _input import (
    connect_pad,
    next_frame,
    point_at,
    press,
    press_key,
    press_pad,
    release,
)

comptime _RECT = Rectangle((0, 0), 216, 40)
"""Its text from 108 left of the centre to 12 right of it, then the −
button centred 40 right of it and the + button 88 right of it."""
comptime _FIELD = Point(-50, 0)
comptime _MINUS = Point(40, 0)
comptime _PLUS = Point(88, 0)


struct _Driver:
    """A number field on its own, and the input that drives it."""

    var field: NumberField
    var context: Context

    def __init__(out self, var field: NumberField):
        self.field = field^
        self.context = Context()
        point_at(self.context, (300, 300))

    def frame(mut self) raises:
        var canvas = Canvas(400, 300)
        self.field.update(self.context, canvas)

    def click(mut self, at: Point) raises:
        next_frame(self.context)
        point_at(self.context, at)
        press(self.context, at)
        self.frame()
        next_frame(self.context)
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
        self.context.keyboard._key_up(key)


def test_a_typed_number_counts_on_enter() raises -> None:
    var driver = _Driver(NumberField(2, 1, 8, _RECT))
    driver.click(_FIELD)
    driver.key(Key.BACKSPACE)
    driver.type("5")
    assert_equal(driver.field.value, 2.0)  # not until Enter
    driver.key(Key.ENTER)
    assert_equal(driver.field.value, 5.0)
    assert_true(driver.field.changed())


def test_text_that_isnt_a_number_puts_the_value_back() raises -> None:
    var driver = _Driver(NumberField(2, 1, 8, _RECT))
    driver.click(_FIELD)
    driver.key(Key.BACKSPACE)
    driver.type("lots")
    driver.key(Key.ENTER)
    assert_equal(driver.field.value, 2.0)
    assert_false(driver.field.changed())


def test_a_typed_number_is_kept_in_range_and_rounded() raises -> None:
    var driver = _Driver(NumberField(0.5, 0, 1, _RECT, decimals=1))
    driver.click(_FIELD)
    for _ in range(3):
        driver.key(Key.BACKSPACE)
    driver.type("7")
    driver.key(Key.ENTER)
    assert_equal(driver.field.value, 1.0)  # kept to the maximum
    for _ in range(3):
        driver.key(Key.BACKSPACE)
    driver.type("0.26")
    driver.key(Key.ENTER)
    assert_equal(driver.field.value, 0.3)  # rounded to one place


def test_leaving_the_field_takes_what_was_typed() raises -> None:
    var driver = _Driver(NumberField(2, 1, 8, _RECT))
    driver.click(_FIELD)
    driver.key(Key.BACKSPACE)
    driver.type("6")
    driver.click((180, 140))  # somewhere else
    assert_equal(driver.field.value, 6.0)


def test_the_buttons_step_it_and_stop_at_the_ends() raises -> None:
    var driver = _Driver(NumberField(7, 1, 8, _RECT))
    driver.click(_PLUS)
    assert_equal(driver.field.value, 8.0)
    assert_true(driver.field.changed())
    driver.click(_PLUS)
    assert_equal(driver.field.value, 8.0)
    driver.click(_MINUS)
    assert_equal(driver.field.value, 7.0)


def test_the_arrows_and_a_gamepad_step_it_in_a_ui() raises -> None:
    var ui = UI()
    var players = ui.add(NumberField(2, 1, 8, _RECT))
    ui.focus(players)
    var context = Context()
    point_at(context, (300, 300))
    connect_pad(context)
    var canvas = Canvas(400, 300)
    next_frame(context)
    press_key(context, Key.UP)
    ui.update(context, canvas)
    context.keyboard._key_up(Key.UP)
    assert_equal(ui[players].value, 3.0)
    assert_true(ui.has_focus(players))  # the arrow didn't move focus
    next_frame(context)
    press_pad(context, GamepadButton.DPAD_DOWN)
    ui.update(context, canvas)
    assert_equal(ui[players].value, 2.0)
    assert_true(ui.has_focus(players))


def test_a_disabled_field_ignores_its_buttons() raises -> None:
    var driver = _Driver(NumberField(2, 1, 8, _RECT, enabled=False))
    driver.click(_PLUS)
    assert_equal(driver.field.value, 2.0)
    assert_false(driver.field._plus.enabled and driver.field._plus.hovered())


def test_a_value_set_by_the_program_is_shown_but_no_change() raises -> None:
    var driver = _Driver(NumberField(2, 1, 8, _RECT, decimals=2))
    driver.field.value = 4.5
    driver.frame()
    assert_equal(driver.field._field.text(), "4.50")
    assert_false(driver.field.changed())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
