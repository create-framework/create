"""`ProgressBar`: how far it fills, alone and in a `UI`."""
from std.testing import TestSuite, assert_equal

from create import *


def _drawn(var bar: ProgressBar) raises -> Canvas:
    """`bar` updated and drawn on its own, without antialiasing."""
    var context = Context()
    var canvas = Canvas(400, 300, antialiasing=Antialiasing.OFF)
    bar.update(context, canvas)
    canvas.draw(bar)
    return canvas^


comptime _BAR = Rectangle((0, 0), 200, 20)
"""From 100 left of the middle to 100 right."""


def test_it_fills_as_far_as_its_value() raises -> None:
    var colors = ColorScheme.light()
    var half = _drawn(ProgressBar(0.5, _BAR))
    assert_equal(half.color_at((-50, 0)), colors.primary)
    assert_equal(half.color_at((50, 0)), colors.secondary_container)
    var empty = _drawn(ProgressBar(0, _BAR))
    assert_equal(empty.color_at((-90, 0)), colors.secondary_container)


def test_a_value_past_its_ends_fills_it_no_further() raises -> None:
    var colors = ColorScheme.light()
    var over = _drawn(ProgressBar(2, _BAR))
    assert_equal(over.color_at((90, 0)), colors.primary)
    var under = _drawn(ProgressBar(-1, _BAR))
    assert_equal(under.color_at((-90, 0)), colors.secondary_container)
    assert_equal(ProgressBar(2, _BAR).fraction(), 1.0)
    assert_equal(ProgressBar(-1, _BAR).fraction(), 0.0)


def test_a_maximum_below_the_minimum_runs_it_the_other_way() raises -> None:
    var bar = ProgressBar(0.25, _BAR, minimum=1, maximum=0)
    assert_equal(bar.fraction(), 0.75)
    var colors = ColorScheme.light()
    var canvas = _drawn(bar^)
    assert_equal(canvas.color_at((40, 0)), colors.primary)
    assert_equal(canvas.color_at((80, 0)), colors.secondary_container)


def test_a_ui_sizes_it_and_styles_it() raises -> None:
    var ui = UI()
    var loading = ui.add(ProgressBar(1))
    ui.style(progress_bar_indicator=Style(stroke=Color.RED))
    var context = Context()
    var canvas = Canvas(400, 300, antialiasing=Antialiasing.OFF)
    ui.update(context, canvas)
    canvas.draw(ui)
    assert_equal(ui[loading].rect.width, 200.0)
    assert_equal(ui[loading].rect.height, 20.0)  # half `control_height`
    assert_equal(canvas.color_at((0, 0)), Color.RED)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
