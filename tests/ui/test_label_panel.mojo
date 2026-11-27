"""`Label` and `Panel` as values, drawn with `canvas.draw` with no `UI`."""
from std.testing import TestSuite, assert_equal, assert_true

from create import *

comptime _PANEL = Rectangle((0, 0), 160, 80)
comptime _LINE = Rectangle((0, 10), 140, 24)


def _canvas() raises -> Canvas:
    return Canvas(200, 100, antialiasing=Antialiasing.OFF)


def _assert_same(mut a: Canvas, mut b: Canvas) raises:
    var x = a.snapshot()
    var y = b.snapshot()
    for j in range(x.height()):
        for i in range(x.width()):
            assert_equal(x.pixel(i, j), y.pixel(i, j))


def test_a_label_is_placed_by_its_alignment() raises -> None:
    var context = Context()
    var canvas = _canvas()
    var left = Label("Hi", _LINE, Align.LEFT, style=Style(font_size=20))
    left.update(context, canvas)
    canvas.draw(left)
    # inked near the left edge, and not at the far right
    var inked_left = False
    for x in range(-70, -55):
        inked_left = inked_left or canvas.color_at((Float64(x), 10.0)).a > 0
    assert_true(inked_left)
    assert_equal(canvas.color_at((60.0, 10.0)).a, 0)


def test_text_on_a_dark_panel_takes_its_content_color() raises -> None:
    var context = Context()
    var canvas = _canvas()
    var panel = Panel(_PANEL, style=Style(fill=Color.BLACK))
    panel.update(context, canvas)
    assert_equal(panel.surface_color(), Color.BLACK)
    assert_equal(panel.content_color(), Color.WHITE)
    var label = Label(
        "Hi",
        _LINE,
        Align.CENTER,
        style=Style(text_color=panel.content_color()),
    )
    label.update(context, canvas)
    canvas.draw(panel)
    canvas.draw(label)
    var lightest = 0
    for x in range(-20, 20):
        var c = canvas.color_at((Float64(x), 10.0))
        lightest = max(lightest, Int(c.r))
    assert_true(lightest > 200)


def test_a_label_sits_against_its_left_edge_unless_aligned() raises -> None:
    var context = Context()
    var left = Label("Hi", Rectangle((0, 0), 200, 40))
    var centred = Label("Hi", Rectangle((0, 0), 200, 40), Align.CENTER)
    var canvas = Canvas(300, 100, antialiasing=Antialiasing.OFF)
    left.update(context, canvas)
    centred.update(context, canvas)
    assert_equal(left._look.text_alignment, Align.LEFT)
    assert_equal(centred._look.text_alignment, Align.CENTER)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
