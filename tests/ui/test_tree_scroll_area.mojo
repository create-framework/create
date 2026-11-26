"""`ScrollArea` in the widget tree: a window onto a taller column, its size,
its offset, and what it leaves undrawn and unclicked."""
from std.testing import TestSuite, assert_equal, assert_false, assert_true

from create import *
from _input import next_frame, point_at, press, release

# The defaults: `spacing` 8, `control_height` 40.
comptime _GAP = 8.0
comptime _CONTROL = 40.0
comptime _CONTENT = 4 * _CONTROL + 3 * _GAP
"""Four buttons and the gaps between them."""


def _list(
    mut ui: UI, window: WidgetHandle[ScrollArea]
) -> List[WidgetHandle[Button]]:
    """Four buttons in a column inside `window`."""
    var column = ui.add(Column(), window)
    var buttons = List[WidgetHandle[Button]]()
    for name in ["A", "B", "C", "D"]:
        buttons.append(ui.add(Button(name), column, width=100))
    return buttons^


def _laid_out(mut ui: UI) raises:
    var context = Context()
    point_at(context, (500, 500))
    var canvas = Canvas(400, 300)
    ui.update(context, canvas)


def test_max_height_caps_a_scroll_and_a_short_column_fits() raises -> None:
    var ui = UI()
    var capped = ui.add(ScrollArea(max_height=100))
    _ = _list(ui, capped)
    var roomy = ui.add(ScrollArea(max_height=500))
    _ = _list(ui, roomy)
    _laid_out(ui)
    assert_equal(ui[capped].rect.height, 100.0)
    assert_equal(ui[capped].rect.width, 100.0)
    assert_equal(ui[roomy].rect.height, _CONTENT)


def test_the_offset_moves_the_column_up() raises -> None:
    var ui = UI()
    var window = ui.add(ScrollArea(Rectangle((0, 0), 200, 100)))
    var buttons = _list(ui, window)
    _laid_out(ui)
    assert_equal(ui[buttons[0]].rect.top(), 50.0)
    ui[window].offset = 30
    _laid_out(ui)
    assert_equal(ui[buttons[0]].rect.top(), 80.0)
    assert_equal(ui[buttons[1]].rect.top(), 80.0 - _CONTROL - _GAP)


def test_the_offset_is_kept_within_the_column() raises -> None:
    var ui = UI()
    var window = ui.add(ScrollArea(Rectangle((0, 0), 200, 100)))
    var buttons = _list(ui, window)
    ui[window].offset = 1000
    _laid_out(ui)
    assert_equal(ui[window].offset, _CONTENT - 100)
    assert_equal(ui[buttons[3]].rect.bottom(), -50.0)  # the last at the foot
    ui[window].offset = -20
    _laid_out(ui)
    assert_equal(ui[window].offset, 0.0)


def test_a_widget_scrolled_out_of_view_is_not_clicked() raises -> None:
    var ui = UI()
    var window = ui.add(ScrollArea(Rectangle((0, 0), 200, 100)))
    var buttons = _list(ui, window)
    # C starts 96 down, below the window's foot at 50 down
    var at = Point(0.0, 50 - 2 * (_CONTROL + _GAP) - _CONTROL / 2)
    var context = Context()
    var canvas = Canvas(400, 300)
    point_at(context, at)
    press(context, at)
    ui.update(context, canvas)
    next_frame(context)
    release(context, at)
    ui.update(context, canvas)
    assert_false(ui[buttons[2]].released())
    assert_false(ui.wants_mouse(context))


def test_a_scroll_draws_only_inside_its_window() raises -> None:
    var ui = UI()
    var window = ui.add(ScrollArea(Rectangle((0, 0), 200, 100)))
    var buttons = _list(ui, window)
    var context = Context()
    point_at(context, (500, 500))
    var canvas = Canvas(400, 300, antialiasing=Antialiasing.OFF)
    ui.update(context, canvas)
    canvas.draw(ui)
    # C straddles the window's foot, at 50 down
    var c = ui[buttons[2]].rect
    assert_true(c.top() > -50 and c.bottom() < -50)
    var away = canvas.color_at((180, -48))  # beside the list
    assert_true(canvas.color_at((0, -48)) != away)  # in the window
    assert_equal(canvas.color_at((0, -60)), canvas.color_at((180, -60)))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
