"""`Dropdown`: opening, choosing and closing by the mouse, its list drawn
over everything in a `UI`, scrolling a long list, and opening upwards."""
from std.testing import TestSuite, assert_equal, assert_false, assert_true

from create import *
from _input import next_frame, point_at, press, release

comptime _FIELD = Rectangle((0, 50), 200, 40)
"""Its field: from 30 to 70 up. The open list below it has its items' middles
at 2, 38 down and 78 down."""


def _item(i: Int) -> Point:
    """The middle of the open list's item counted `i` from the top."""
    return Point(0, 2 - 40 * Float64(i))


def _options() -> List[String]:
    return ["Small", "Medium", "Large"]


def _click(mut ui: UI, mut context: Context, at: Point) raises:
    """Press and let go of the mouse at `at`, a frame each."""
    var canvas = Canvas(400, 300)
    next_frame(context)
    point_at(context, at)
    press(context, at)
    ui.update(context, canvas)
    next_frame(context)
    release(context, at)
    ui.update(context, canvas)


def test_a_click_opens_it_and_a_click_on_an_item_chooses_it() raises -> None:
    var ui = UI()
    var size = ui.add(Dropdown(_options(), _FIELD))
    var context = Context()
    _click(ui, context, _FIELD.position)
    assert_true(ui[size].is_open())
    _click(ui, context, _item(2))
    assert_false(ui[size].is_open())
    assert_equal(ui[size].selected, 2)
    assert_equal(ui[size].selected_text(), "Large")


def test_a_click_elsewhere_closes_it_and_reaches_nothing_else() raises -> None:
    var ui = UI()
    var size = ui.add(Dropdown(_options(), _FIELD))
    var ok = ui.add(Button("OK", Rectangle((0, -120), 100, 40)))
    var context = Context()
    _click(ui, context, _FIELD.position)
    _click(ui, context, (0, -120))  # on the button
    assert_false(ui[size].is_open())
    assert_equal(ui[size].selected, 0)
    assert_false(ui[ok].released())
    _click(ui, context, (0, -120))  # now it reaches the button
    assert_true(ui[ok].released())


def test_its_list_draws_outside_a_scroll_area_s_window() raises -> None:
    var ui = UI()
    var window = ui.add(ScrollArea(Rectangle((0, 50), 220, 60)))
    var column = ui.add(Column(), window)
    var size = ui.add(Dropdown(_options()), column)
    var context = Context()
    _click(ui, context, (0, 50))
    assert_true(ui[size].is_open())
    var canvas = Canvas(400, 300, antialiasing=Antialiasing.OFF)
    canvas.background(Color.WHITE)
    point_at(context, (180, 140))
    next_frame(context)
    ui.update(context, canvas)
    canvas.draw(ui)
    # the list's last item lies far below the window, which ends 20 up
    var list = ui[size]._popup().value()
    assert_true(list.bottom() < 0)
    assert_true(canvas.color_at((0, list.bottom() + 10)) != Color.WHITE)


def test_the_wheel_scrolls_a_long_list() raises -> None:
    var ui = UI()
    var options = List[String]()
    for i in range(20):
        options.append(String("Level ", i + 1))
    var level = ui.add(Dropdown(options^, _FIELD, max_items=4))
    var context = Context()
    _click(ui, context, _FIELD.position)
    var canvas = Canvas(400, 300)
    next_frame(context)
    point_at(context, _item(1))
    context.mouse._scroll(Vector(0, -1))
    ui.update(context, canvas)
    assert_equal(ui[level]._scroll, 40.0)  # an item's height
    _click(ui, context, _item(0))
    assert_equal(ui[level].selected, 1)  # the second, scrolled to the top


def test_its_list_opens_upwards_near_the_canvas_s_foot() raises -> None:
    var ui = UI()
    var size = ui.add(Dropdown(_options(), Rectangle((0, -110), 200, 40)))
    var context = Context()
    _click(ui, context, (0, -110))
    var list = ui[size]._popup().value()
    assert_true(list.bottom() > -90)  # above the field, which ends 90 up


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
