"""`ScrollArea` in the widget tree: a window onto a taller column, its size,
its offset, and what it leaves undrawn and unclicked."""
from std.testing import TestSuite, assert_equal, assert_false, assert_true

from create import *
from _input import next_frame, point_at, press, press_key, release

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


comptime _BAR = 0.3 * _CONTROL
"""The scroll bar's width: a share of `control_height`."""


def test_the_wheel_over_a_scroll_area_scrolls_it() raises -> None:
    var ui = UI()
    var window = ui.add(ScrollArea(Rectangle((0, 0), 200, 100)))
    _ = _list(ui, window)
    var context = Context()
    var canvas = Canvas(400, 300)
    point_at(context, (180, 140))  # away from it
    context.mouse._scroll(Vector(0, -1))
    ui.update(context, canvas)
    assert_equal(ui[window].offset, 0.0)
    next_frame(context)
    point_at(context, (0, 0))
    context.mouse._scroll(Vector(0, -1))  # towards you: down the column
    ui.update(context, canvas)
    assert_equal(ui[window].offset, _CONTROL)
    assert_true(ui.wants_mouse(context))


def test_the_inner_of_two_scroll_areas_takes_the_wheel() raises -> None:
    var ui = UI()
    var outer = ui.add(ScrollArea(Rectangle((0, 0), 300, 200)))
    var column = ui.add(Column(), outer)
    var inner = ui.add(ScrollArea(max_height=100), column)
    _ = _list(ui, inner)
    _ = ui.add(Space(300), column)  # makes the outer column taller too
    var context = Context()
    var canvas = Canvas(400, 300)
    ui.update(context, canvas)
    next_frame(context)
    point_at(context, ui[inner].rect.position)
    context.mouse._scroll(Vector(0, -1))
    ui.update(context, canvas)
    assert_equal(ui[inner].offset, _CONTROL)
    assert_equal(ui[outer].offset, 0.0)


def test_dragging_the_thumb_scrolls_and_holds_the_mouse() raises -> None:
    var ui = UI()
    var window = ui.add(ScrollArea(Rectangle((0, 0), 200, 100)))
    var buttons = _list(ui, window)
    var context = Context()
    var canvas = Canvas(400, 300)
    ui.update(context, canvas)
    # the thumb starts at the top of the bar, down the window's right edge
    var x = 100 - _BAR / 2
    var start = Point(x, 50 - _BAR)
    next_frame(context)
    point_at(context, start)
    press(context, start)
    ui.update(context, canvas)
    next_frame(context)
    point_at(context, (300, start.y - 1000))  # far below, and off it
    ui.update(context, canvas)
    assert_equal(ui[window].offset, _CONTENT - 100)  # as far as it goes
    assert_equal(ui[buttons[3]].rect.bottom(), -50.0)  # placed this frame
    assert_true(ui.wants_mouse(context))  # held, though not over it
    release(context, (300, start.y - 1000))


def test_a_column_that_fits_has_no_bar_and_the_full_width() raises -> None:
    var ui = UI()
    var window = ui.add(ScrollArea(Rectangle((0, 0), 200, 250)))
    var list = ui.add(Column(), window)
    var a = ui.add(Button("A"), list)
    _laid_out(ui)
    assert_equal(ui[a].rect.width, 200.0)
    var tall = UI()
    var short = tall.add(ScrollArea(Rectangle((0, 0), 200, 100)))
    var column = tall.add(Column(), short)
    var b = tall.add(Button("B"), column)
    for _ in range(3):
        _ = tall.add(Button("More"), column)
    _laid_out(tall)
    assert_equal(tall[b].rect.width, 200.0 - _BAR)  # room for the bar


def test_ui_style_colours_the_thumb() raises -> None:
    var ui = UI()
    var window = ui.add(ScrollArea(Rectangle((0, 0), 200, 100)))
    _ = _list(ui, window)
    ui.style(scroll_area_thumb=Style(stroke=Color.RED))
    var context = Context()
    point_at(context, (180, 140))
    var canvas = Canvas(400, 300, antialiasing=Antialiasing.OFF)
    ui.update(context, canvas)
    canvas.draw(ui)
    assert_equal(canvas.color_at((100 - _BAR / 2, 40)), Color.RED)


def _tab(mut ui: UI, mut context: Context, shift: Bool = False) raises:
    """Press Tab, or Shift+Tab, for a frame."""
    next_frame(context)
    if shift:
        context.keyboard._key_down(Key.LEFT_SHIFT)
    press_key(context, Key.TAB)
    var canvas = Canvas(400, 300)
    ui.update(context, canvas)
    next_frame(context)
    context.keyboard._key_up(Key.TAB)
    if shift:
        context.keyboard._key_up(Key.LEFT_SHIFT)


def test_tab_scrolls_the_focused_widget_into_view() raises -> None:
    var ui = UI()
    var window = ui.add(ScrollArea(Rectangle((0, 0), 200, 100)))
    var buttons = _list(ui, window)
    var context = Context()
    point_at(context, (180, 140))
    for _ in range(3):  # A, B, then C, which starts below the window
        _tab(ui, context)
    assert_true(ui.has_focus(buttons[2]))
    # by the least: C's foot on the window's
    assert_equal(ui[buttons[2]].rect.bottom(), -50.0)
    assert_equal(ui[window].offset, 3 * _CONTROL + 2 * _GAP - 100)
    _tab(ui, context, shift=True)  # B: in view already
    assert_equal(ui[window].offset, 3 * _CONTROL + 2 * _GAP - 100)
    _tab(ui, context, shift=True)  # A: above the window, so back up
    assert_equal(ui[window].offset, 0.0)


def test_scroll_to_shows_a_widget_at_the_next_update() raises -> None:
    var ui = UI()
    var window = ui.add(ScrollArea(Rectangle((0, 0), 200, 100)))
    var buttons = _list(ui, window)
    _laid_out(ui)
    ui.scroll_to(buttons[3])
    assert_equal(ui[window].offset, 0.0)  # not until the update
    _laid_out(ui)
    assert_equal(ui[window].offset, _CONTENT - 100)
    assert_equal(ui[buttons[3]].rect.bottom(), -50.0)
    ui.scroll_to(buttons[2])  # in view: nothing moves
    _laid_out(ui)
    assert_equal(ui[window].offset, _CONTENT - 100)


def test_nested_scroll_areas_both_scroll_to_show_a_widget() raises -> None:
    var ui = UI()
    var outer = ui.add(ScrollArea(Rectangle((0, 0), 300, 120)))
    var column = ui.add(Column(), outer)
    _ = ui.add(Space(200), column)  # pushes the inner area out of view
    var inner = ui.add(ScrollArea(max_height=100), column)
    var buttons = _list(ui, inner)
    _laid_out(ui)
    ui.scroll_to(buttons[3])
    _laid_out(ui)
    assert_true(ui[inner].offset > 0)
    assert_true(ui[outer].offset > 0)
    var d = ui[buttons[3]].rect
    assert_true(d.bottom() >= -60 and d.top() <= 60)  # in the outer window


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
