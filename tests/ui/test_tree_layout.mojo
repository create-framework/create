"""Layout in the widget tree: a widget with no size takes the size it
prefers, a `Column` stacks, a `Row` sets side by side, a `Space` leaves room,
and a `Panel` places a column or row in its inside and, with no size of its
own, fits round it."""
from std.testing import (
    TestSuite,
    assert_almost_equal,
    assert_equal,
    assert_true,
)

from create import *
from _input import next_frame, point_at, press, release

# The defaults: `spacing` 8, `control_height` 40, a label's text 16.
comptime _GAP = 8.0
comptime _CONTROL = 40.0
comptime _LABEL = 24.0
"""A label's height: one and a half times its text's size."""


def _laid_out(mut ui: UI) raises:
    var context = Context()
    point_at(context, (500, 500))
    var canvas = Canvas(400, 300)
    ui.update(context, canvas)


def test_a_widget_with_no_size_takes_the_size_it_prefers() raises -> None:
    var ui = UI()
    var play = ui.add(Button("Play"))
    var placed = ui.add(Button("Placed", Rectangle((50, 50), 120, 30)))
    _laid_out(ui)
    var canvas = Canvas(10, 10)
    canvas.font_size(14)
    canvas.font_weight(FontWeight.MEDIUM)
    assert_almost_equal(ui[play].rect.width, canvas.text_width("Play") + 48)
    assert_equal(ui[play].rect.height, _CONTROL)
    assert_equal(ui[placed].rect, Rectangle((50, 50), 120, 30))  # kept


def test_a_column_stacks_from_the_top_across_its_width() raises -> None:
    var ui = UI()
    var list = ui.add(Column(Rectangle((0, 0), 200, 300)))
    var title = ui.add(Label("Title"), list)
    var first = ui.add(Button("A"), list)
    var second = ui.add(Slider(0.5, 0, 1), list)
    _laid_out(ui)
    assert_equal(ui[title].rect.top(), 150.0)
    assert_equal(ui[title].rect.height, _LABEL)
    assert_equal(ui[title].rect.width, 200.0)
    assert_equal(ui[first].rect.top(), 150.0 - _LABEL - _GAP)
    assert_equal(ui[first].rect.width, 200.0)
    assert_equal(ui[second].rect.top(), 150.0 - _LABEL - _GAP - _CONTROL - _GAP)


def test_a_space_leaves_room_in_a_column() raises -> None:
    var ui = UI()
    var list = ui.add(Column(Rectangle((0, 0), 200, 300)))
    _ = ui.add(Button("A"), list)
    _ = ui.add(Space(30), list)
    var after = ui.add(Button("B"), list)
    _laid_out(ui)
    assert_equal(ui[after].rect.top(), 150.0 - _CONTROL - _GAP - 30 - _GAP)


def test_a_row_shares_its_width_by_weight() raises -> None:
    var ui = UI()
    var line = ui.add(Row(1, 3, rect=Rectangle((0, 0), 408, 40)))
    var name = ui.add(Label("Volume"), line)
    var volume = ui.add(Slider(0.5, 0, 1), line)
    _laid_out(ui)
    assert_equal(ui[name].rect.width, 100.0)  # (408 - 8) / 4
    assert_equal(ui[volume].rect.width, 300.0)
    assert_equal(ui[name].rect.left(), -204.0)
    assert_equal(ui[volume].rect.right(), 204.0)


def test_a_row_with_no_weights_gives_equal_slots() raises -> None:
    var ui = UI()
    var line = ui.add(Row(rect=Rectangle((0, 0), 214, 40)))
    var buttons = List[WidgetHandle[Button]]()
    for name in ["A", "B", "C"]:
        buttons.append(ui.add(Button(name), line))
    _laid_out(ui)
    for handle in buttons:
        assert_equal(ui[handle].rect.width, 66.0)  # (214 - 2 * 8) / 3


def test_a_row_in_a_column_is_as_tall_as_its_tallest() raises -> None:
    var ui = UI()
    var list = ui.add(Column(Rectangle((0, 0), 200, 300)))
    var line = ui.add(Row(), list)
    var a = ui.add(Label("A"), line)
    _ = ui.add(Button("B"), line)
    var under = ui.add(Button("C"), list)
    _laid_out(ui)
    assert_equal(ui[a].rect.height, _CONTROL)  # the button's height
    assert_equal(ui[under].rect.top(), 150.0 - _CONTROL - _GAP)


def test_a_panel_with_no_size_fits_round_its_column() raises -> None:
    var ui = UI()
    var card = ui.add(Panel())
    var list = ui.add(Column(), card)
    var first = ui.add(Slider(0.5, 0, 1), list)
    _ = ui.add(Slider(0.5, 0, 1), list)
    _laid_out(ui)
    # two sliders, 200 by 40, a gap between, inset by twice the spacing
    var inset = 2 * 2 * _GAP
    assert_equal(ui[card].rect.width, 200.0 + inset)
    assert_equal(ui[card].rect.height, 2 * _CONTROL + _GAP + inset)
    assert_equal(ui[first].rect.top(), ui[card].rect.top() - inset / 2)
    assert_equal(ui[first].rect.left(), ui[card].rect.left() + inset / 2)


def test_a_sized_panel_places_its_column_in_its_inside() raises -> None:
    var ui = UI()
    var card = ui.add(Panel(Rectangle((0, 0), 300, 200)))
    var list = ui.add(Column(), card)
    var ok = ui.add(Button("OK"), list)
    _laid_out(ui)
    assert_equal(ui[card].rect.width, 300.0)
    assert_equal(ui[ok].rect.width, 300.0 - 4 * _GAP)
    assert_equal(ui[ok].rect.top(), 100.0 - 2 * _GAP)


def test_a_placed_widget_is_clicked_where_it_is_placed() raises -> None:
    var ui = UI()
    var list = ui.add(Column(Rectangle((0, 0), 200, 300)))
    _ = ui.add(Button("A"), list)
    var b = ui.add(Button("B"), list)
    var context = Context()
    var canvas = Canvas(400, 300)
    var at = Point(0.0, 150 - _CONTROL - _GAP - _CONTROL / 2)  # B's centre
    point_at(context, at)
    press(context, at)
    ui.update(context, canvas)
    next_frame(context)
    release(context, at)
    ui.update(context, canvas)
    assert_true(ui[b].released())


def test_a_widget_with_its_own_rect_keeps_it_in_a_column() raises -> None:
    var ui = UI()
    var list = ui.add(Column(Rectangle((0, 0), 200, 300)))
    var first = ui.add(Button("A"), list)
    var aside = ui.add(Button("Aside", Rectangle((150, -100), 80, 30)), list)
    var second = ui.add(Button("B"), list)
    _laid_out(ui)
    assert_equal(ui[aside].rect, Rectangle((150, -100), 80, 30))
    # it takes no room: B comes straight after A
    assert_equal(ui[second].rect.top(), ui[first].rect.bottom() - _GAP)


def test_a_column_with_its_own_rect_keeps_it_in_a_panel() raises -> None:
    var ui = UI()
    var card = ui.add(Panel(Rectangle((0, 0), 300, 200)))
    var list = ui.add(Column(Rectangle((50, 0), 100, 100)), card)
    var ok = ui.add(Button("OK"), list)
    _laid_out(ui)
    assert_equal(ui[list].rect, Rectangle((50, 0), 100, 100))
    assert_equal(ui[ok].rect.width, 100.0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
