"""`ui.column`, `ui.row` and `ui.space`: a widget called without a rect takes
the next slot of the stack around it."""
from std.testing import (
    TestSuite,
    assert_almost_equal,
    assert_equal,
    assert_raises,
    assert_true,
)

from create import *
from _input import next_frame, point_at, press, release

comptime _COLUMN = Rectangle((0, 0), 200, 300)
"""A column whose top is at y = 150."""


def _assert_rect(
    got: Rectangle, x: Float64, y: Float64, width: Float64, height: Float64
) raises -> None:
    assert_almost_equal(got.position.x, x, atol=1e-9)
    assert_almost_equal(got.position.y, y, atol=1e-9)
    assert_almost_equal(got.width, width, atol=1e-9)
    assert_almost_equal(got.height, height, atol=1e-9)


def _placed(ui: UI) -> List[Rectangle]:
    """Where this frame's buttons went, in call order."""
    var rects = List[Rectangle]()
    for hit in ui._hits:
        if hit.focusable:
            rects.append(hit.rect)
    return rects^


def test_a_column_stacks_widgets_down_its_width() raises -> None:
    var ui = UI()
    var context = Context()
    var canvas = Canvas(400, 400)
    with ui.screen(context, canvas) as layer:
        with layer.column(_COLUMN):
            _ = layer.button("One")
            _ = layer.button("Two")
    var rects = _placed(ui)
    _assert_rect(rects[0], 0, 130, 200, 40)
    _assert_rect(rects[1], 0, 82, 200, 40)  # 8 below the first


def test_the_uis_spacing_and_control_height_lay_out_a_column() raises -> None:
    var ui = UI()
    ui.spacing(20)
    ui.control_height(30)
    var context = Context()
    var canvas = Canvas(400, 400)
    with ui.screen(context, canvas) as layer:
        with layer.column(_COLUMN):
            _ = layer.button("One")
            _ = layer.button("Two")
            layer.space()  # twice the spacing, 40
            _ = layer.button("Three")
    var rects = _placed(ui)
    _assert_rect(rects[0], 0, 135, 200, 30)
    _assert_rect(rects[1], 0, 85, 200, 30)  # 20 below the first
    _assert_rect(rects[2], 0, -5, 200, 30)  # 20 + 40 below the second


def test_a_gap_given_replaces_the_uis() raises -> None:
    var ui = UI()
    var context = Context()
    var canvas = Canvas(400, 400)
    with ui.screen(context, canvas) as layer:
        with layer.column(_COLUMN, gap=0):
            _ = layer.button("One")
            _ = layer.button("Two")
    _assert_rect(_placed(ui)[1], 0, 90, 200, 40)


def test_a_label_is_as_tall_as_its_text_needs() raises -> None:
    var ui = UI()
    var context = Context()
    var canvas = Canvas(400, 400)
    with ui.screen(context, canvas) as layer:
        with layer.column(_COLUMN):
            layer.label("Body")  # 16 high, so 24
            _ = layer.button("After body")
            layer.label("Title", style=Style(font_size=22))  # 22 high, so 33
            _ = layer.button("After title")
    var rects = _placed(ui)
    _assert_rect(rects[0], 0, 98, 200, 40)  # 150 - 24 - 8 - 20
    _assert_rect(rects[1], 0, 9, 200, 40)  # 78 - 8 - 33 - 8 - 20


def test_a_row_splits_its_width_by_its_weights() raises -> None:
    var ui = UI()
    var context = Context()
    var canvas = Canvas(500, 400)
    with ui.screen(context, canvas) as layer:
        with layer.column(Rectangle((0, 0), 408, 300)):
            with layer.row(1, 3):
                _ = layer.button("Narrow")
                _ = layer.button("Wide")
    var rects = _placed(ui)
    _assert_rect(rects[0], -154, 130, 100, 40)
    _assert_rect(rects[1], 54, 130, 300, 40)


def test_a_row_of_equal_columns() raises -> None:
    var ui = UI()
    var context = Context()
    var canvas = Canvas(500, 400)
    with ui.screen(context, canvas) as layer:
        with layer.row(
            columns=4, rect=Rectangle((0, 0), 424, 50), gap=8, height=10
        ):
            for _ in range(4):
                _ = layer.button("Go")
    var rects = _placed(ui)
    assert_equal(len(rects), 4)
    for i in range(4):
        _assert_rect(rects[i], -162 + 108 * Float64(i), 0, 100, 50)


def test_a_rows_height_is_given_or_the_controls() raises -> None:
    var ui = UI()
    var context = Context()
    var canvas = Canvas(400, 400)
    with ui.screen(context, canvas) as layer:
        with layer.column(_COLUMN):
            with layer.row(columns=1, height=60):
                _ = layer.button("Tall")
            with layer.row(columns=1):
                _ = layer.button("Usual")
    var rects = _placed(ui)
    _assert_rect(rects[0], 0, 120, 200, 60)
    _assert_rect(rects[1], 0, 62, 200, 40)  # 150 - 60 - 8 - 20


def test_a_rect_given_wins_and_takes_no_slot() raises -> None:
    var ui = UI()
    var context = Context()
    var canvas = Canvas(400, 400)
    with ui.screen(context, canvas) as layer:
        with layer.column(_COLUMN):
            _ = layer.button("Placed", Rectangle((100, -100), 50, 20))
            _ = layer.button("Stacked")
    var rects = _placed(ui)
    _assert_rect(rects[0], 100, -100, 50, 20)
    _assert_rect(rects[1], 0, 130, 200, 40)


def test_a_column_fills_the_panel_around_it() raises -> None:
    var ui = UI()
    var context = Context()
    var canvas = Canvas(400, 400)
    with ui.screen(context, canvas) as layer:
        with layer.panel(Rectangle((10, 0), 300, 200)):
            with layer.column():  # inset by 16: 268 wide, its top at 84
                _ = layer.button("Inside")
    _assert_rect(_placed(ui)[0], 10, 64, 268, 40)


def test_a_column_fills_a_rows_slot() raises -> None:
    var ui = UI()
    var context = Context()
    var canvas = Canvas(500, 400)
    with ui.screen(context, canvas) as layer:
        with layer.row(columns=2, rect=Rectangle((0, 0), 408, 200)):
            with layer.column():
                _ = layer.button("Left, top")
                _ = layer.button("Left, below")
            _ = layer.button("Right")
    var rects = _placed(ui)
    _assert_rect(rects[0], -104, 80, 200, 40)
    _assert_rect(rects[1], -104, 32, 200, 40)
    _assert_rect(rects[2], 104, 0, 200, 200)


def test_a_column_in_a_column_takes_the_rest() raises -> None:
    var ui = UI()
    var context = Context()
    var canvas = Canvas(400, 400)
    with ui.screen(context, canvas) as layer:
        with layer.column(_COLUMN):
            _ = layer.button("Above")
            with layer.column(gap=0):
                _ = layer.button("Inner")
                _ = layer.button("Inner")
    var rects = _placed(ui)
    _assert_rect(rects[1], 0, 82, 200, 40)
    _assert_rect(rects[2], 0, 42, 200, 40)


def test_space_leaves_part_of_a_column_empty() raises -> None:
    var ui = UI()
    var context = Context()
    var canvas = Canvas(400, 400)
    with ui.screen(context, canvas) as layer:
        with layer.column(_COLUMN):
            _ = layer.button("Above")
            layer.space(20)
            _ = layer.button("Below")
            layer.space()  # twice the spacing, 16
            _ = layer.button("Further")
    var rects = _placed(ui)
    _assert_rect(rects[1], 0, 62, 200, 40)
    _assert_rect(rects[2], 0, -2, 200, 40)  # its top at 34 - 16


def test_a_placed_button_is_clicked_where_it_is_drawn() raises -> None:
    var ui = UI()
    var context = Context()
    var canvas = Canvas(400, 400)
    var spot = Point(0, 82)  # the second button's centre
    var clicked = List[Bool]()
    for frame in range(2):
        if frame == 1:
            next_frame(context)
            press(context, spot)
            release(context, spot)
        else:
            point_at(context, spot)
        clicked.clear()
        with ui.screen(context, canvas) as layer:
            with layer.column(_COLUMN):
                clicked.append(layer.button("One"))
                clicked.append(layer.button("Two"))
    assert_equal(clicked, [False, True])


def test_a_placed_widget_keeps_its_id_from_frame_to_frame() raises -> None:
    var ui = UI()
    var context = Context()
    var canvas = Canvas(400, 400)
    var ids = List[UInt64]()
    for _ in range(2):
        with ui.screen(context, canvas) as layer:
            with layer.column(_COLUMN):
                _ = layer.button("Same")
        ids.append(ui._hits[0].id)
        next_frame(context)
    assert_equal(ids[0], ids[1])


def test_a_widget_without_a_rect_outside_a_stack_raises() raises -> None:
    var ui = UI()
    var context = Context()
    var canvas = Canvas(400, 400)
    with ui.screen(context, canvas) as layer:
        with assert_raises(contains="ui.button: give it a rect"):
            _ = layer.button("Lost")
        with layer.panel(_COLUMN):
            with assert_raises(contains="ui.label: give it a rect"):
                layer.label("Lost in a panel")


def test_a_column_without_a_rect_outside_a_panel_raises() raises -> None:
    var ui = UI()
    var context = Context()
    var canvas = Canvas(400, 400)
    with ui.screen(context, canvas) as layer:
        with assert_raises(contains="ui.column: give it a rect"):
            with layer.column():
                pass


def test_a_widget_past_a_rows_last_slot_raises() raises -> None:
    var ui = UI()
    var context = Context()
    var canvas = Canvas(400, 400)
    with ui.screen(context, canvas) as layer:
        with layer.column(_COLUMN):
            with layer.row(1, 1):
                _ = layer.button("One")
                _ = layer.button("Two")
                with assert_raises(contains="has 2 slots"):
                    _ = layer.button("Three")


def test_a_row_needs_weights_or_columns_but_not_both() raises -> None:
    var ui = UI()
    var context = Context()
    var canvas = Canvas(400, 400)
    with ui.screen(context, canvas) as layer:
        with layer.column(_COLUMN):
            with assert_raises(contains="not both"):
                with layer.row(1, 3, columns=2):
                    pass
            with assert_raises(contains="weights of its slots"):
                with layer.row():
                    pass


def test_space_outside_a_column_raises() raises -> None:
    var ui = UI()
    var context = Context()
    var canvas = Canvas(400, 400)
    with ui.screen(context, canvas) as layer:
        with assert_raises(contains="ui.space"):
            layer.space()
        with layer.row(columns=2, rect=_COLUMN):
            with assert_raises(contains="ui.space"):
                layer.space()


def test_the_stacks_close_with_their_blocks() raises -> None:
    var ui = UI()
    var context = Context()
    var canvas = Canvas(400, 400)
    with ui.screen(context, canvas) as layer:
        with layer.panel(_COLUMN):
            with layer.column():
                with layer.row(columns=1):
                    pass
        assert_equal(len(ui._layouts), 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
