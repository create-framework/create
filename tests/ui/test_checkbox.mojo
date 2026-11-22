"""`ui.checkbox`'s parts: the box, the ticked box, the tick and the label,
each drawn in a `Style` of its own."""
from std.testing import TestSuite, assert_equal, assert_true

from create import *

comptime _ROW = Rectangle((0, 0), 200, 32)
comptime _BOX = Point(-91, 0)
"""The box's centre: 18 across, against the row's left edge."""


def _drawn(
    checked: Bool,
    box: Style = Style(),
    checked_box: Style = Style(),
    tick: Style = Style(),
) raises -> Canvas:
    """One frame of a checkbox, in the parts' styles, unsmoothed."""
    var ui = UI()
    var context = Context()
    var canvas = Canvas(300, 100, antialiasing=Antialiasing.OFF)
    var shown = checked
    with ui.screen(context, canvas) as layer:
        layer.checkbox(
            "Music",
            shown,
            _ROW,
            box=box,
            checked_box=checked_box,
            tick=tick,
        )
    return canvas^


def test_an_empty_box_is_an_outline() raises -> None:
    var colors = ColorScheme.light()
    var canvas = _drawn(False)
    assert_equal(
        canvas.color_at(_BOX + Vector(-8.5, 0.0)), colors.on_surface_variant
    )
    assert_equal(canvas.color_at(_BOX), Color.TRANSPARENT)


def test_a_ticked_box_is_filled_and_ticked() raises -> None:
    var colors = ColorScheme.light()
    var canvas = _drawn(True)
    assert_equal(canvas.color_at(_BOX + Vector(-7, 7)), colors.primary)
    assert_equal(canvas.color_at(_BOX + Vector(-1.5, -4.0)), colors.on_primary)


def test_the_tick_takes_its_own_style() raises -> None:
    var canvas = _drawn(True, tick=Style(stroke=Color.RED))
    assert_equal(canvas.color_at(_BOX + Vector(-1.5, -4.0)), Color.RED)


def test_a_square_box_and_its_ticked_form() raises -> None:
    var corner = _BOX + Vector(-8.5, 8.5)
    var round = _drawn(True)
    assert_true(round.color_at(corner) != ColorScheme.light().primary)
    # the ticked box takes the box's corners
    var square = _drawn(True, box=Style(corner_radius=0))
    assert_equal(square.color_at(corner), ColorScheme.light().primary)


def test_a_ticked_box_can_be_styled_apart() raises -> None:
    var canvas = _drawn(True, checked_box=Style(fill=Color.GREEN))
    assert_equal(canvas.color_at(_BOX + Vector(-7, 7)), Color.GREEN)
    var empty = _drawn(False, checked_box=Style(fill=Color.GREEN))
    assert_equal(empty.color_at(_BOX), Color.TRANSPARENT)


def test_a_style_block_reaches_every_checkbox() raises -> None:
    var ui = UI()
    var context = Context()
    var canvas = Canvas(300, 100, antialiasing=Antialiasing.OFF)
    var on = True
    with ui.screen(context, canvas) as layer:
        with layer.style(checkbox_tick=Style(stroke=Color.RED)):
            layer.checkbox("Music", on, _ROW)
    assert_equal(canvas.color_at(_BOX + Vector(-1.5, -4.0)), Color.RED)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
