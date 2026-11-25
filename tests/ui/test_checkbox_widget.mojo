"""`Checkbox` as a value: a click ticks or unticks it, `changed()` says so
in that frame, and each part is drawn in a style of its own."""
from std.testing import TestSuite, assert_equal, assert_false, assert_true

from create import *
from _input import next_frame, point_at, press, release

comptime _ROW = Rectangle((0, 0), 200, 32)
comptime _BOX = Point(-91, 0)
"""The box's centre: 18 across, against the row's left edge."""
comptime _TICK = _BOX + Vector(-1.5, -4.0)
"""A point on the tick."""


def _drawn(var checkbox: Checkbox) raises -> Canvas:
    """One frame of `checkbox`, the pointer away from it, unsmoothed."""
    var context = Context()
    point_at(context, (140, 45))
    var canvas = Canvas(300, 100, antialiasing=Antialiasing.OFF)
    checkbox.update(context, canvas)
    canvas.draw(checkbox)
    return canvas^


def _click(mut checkbox: Checkbox, mut context: Context, at: Point) raises:
    """Press and let go at `at`, over two frames, updating `checkbox` in
    each."""
    var canvas = Canvas(300, 100)
    next_frame(context)
    point_at(context, at)
    press(context, at)
    checkbox.update(context, canvas)
    next_frame(context)
    release(context, at)
    checkbox.update(context, canvas)


def test_a_click_ticks_and_unticks_it() raises -> None:
    var checkbox = Checkbox("Music", _ROW)
    var context = Context()
    _click(checkbox, context, (40, 0))  # on its text: the whole row counts
    assert_true(checkbox.checked)
    assert_true(checkbox.changed())
    next_frame(context)
    checkbox.update(context, Canvas(300, 100))
    assert_false(checkbox.changed())  # only in the frame it changed
    _click(checkbox, context, _BOX)
    assert_false(checkbox.checked)
    assert_true(checkbox.changed())


def test_a_press_alone_changes_nothing() raises -> None:
    var checkbox = Checkbox("Music", _ROW)
    var context = Context()
    point_at(context, _BOX)
    press(context, _BOX)
    checkbox.update(context, Canvas(300, 100))
    assert_true(checkbox.pressed())
    assert_false(checkbox.checked or checkbox.changed())


def test_a_disabled_checkbox_stays_as_it_is() raises -> None:
    var checkbox = Checkbox("Music", _ROW, checked=True, enabled=False)
    var context = Context()
    _click(checkbox, context, _BOX)
    assert_true(checkbox.checked)
    assert_false(checkbox.changed())


def test_an_empty_box_is_an_outline() raises -> None:
    var colors = ColorScheme.light()
    var canvas = _drawn(Checkbox("Music", _ROW))
    assert_equal(
        canvas.color_at(_BOX + Vector(-8.5, 0.0)), colors.on_surface_variant
    )
    assert_equal(canvas.color_at(_BOX), Color.TRANSPARENT)


def test_a_ticked_box_is_filled_and_ticked() raises -> None:
    var colors = ColorScheme.light()
    var canvas = _drawn(Checkbox("Music", _ROW, checked=True))
    assert_equal(canvas.color_at(_BOX + Vector(-7, 7)), colors.primary)
    assert_equal(canvas.color_at(_TICK), colors.on_primary)


def test_each_part_takes_its_own_style() raises -> None:
    var ticked = _drawn(
        Checkbox(
            "Music",
            _ROW,
            checked=True,
            checked_box=Style(fill=Color.GREEN),
            tick=Style(stroke=Color.RED),
        )
    )
    assert_equal(ticked.color_at(_BOX + Vector(-7, 7)), Color.GREEN)
    assert_equal(ticked.color_at(_TICK), Color.RED)
    var empty = _drawn(
        Checkbox("Music", _ROW, checked_box=Style(fill=Color.GREEN))
    )
    assert_equal(empty.color_at(_BOX), Color.TRANSPARENT)


def test_the_ticked_box_takes_the_boxs_corners() raises -> None:
    var corner = _BOX + Vector(-8.5, 8.5)
    var square = _drawn(
        Checkbox("Music", _ROW, checked=True, box=Style(corner_radius=0))
    )
    assert_equal(square.color_at(corner), ColorScheme.light().primary)


def test_it_draws_as_the_ui_checkbox_does() raises -> None:
    var context = Context()
    point_at(context, (140, 45))
    var drawn = Canvas(300, 100, antialiasing=Antialiasing.OFF)
    var checkbox = Checkbox("Music", _ROW, checked=True)
    checkbox.update(context, drawn)
    drawn.draw(checkbox)
    var ui = UI()
    var called = Canvas(300, 100, antialiasing=Antialiasing.OFF)
    var on = True
    with ui.screen(context, called) as layer:
        layer.checkbox("Music", on, _ROW)
    var a = drawn.snapshot()
    var b = called.snapshot()
    for j in range(a.height()):
        for i in range(a.width()):
            assert_equal(a.pixel(i, j), b.pixel(i, j))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
