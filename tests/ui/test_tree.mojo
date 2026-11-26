"""The widget tree: handles reach its widgets, one `update` and one
`canvas.draw` run them all, only the topmost under the pointer reacts, and
the look is shared and passed down from a panel to what sits on it."""
from std.testing import TestSuite, assert_equal, assert_false, assert_true

from create import *
from _input import next_frame, point_at, press, release


def _canvas() raises -> Canvas:
    return Canvas(300, 200, antialiasing=Antialiasing.OFF)


def test_a_handle_reaches_its_widget() raises -> None:
    var ui = UI()
    var play = ui.add(Button("Play", Rectangle((0, 0), 100, 40)))
    var volume = ui.add(Slider(0.5, 0, 1, Rectangle((0, -60), 200, 32)))
    assert_equal(ui[play].text, "Play")
    ui[play].text = "Go"
    ui[volume].value = 0.25
    assert_equal(ui[play].text, "Go")
    assert_equal(ui[volume].value, 0.25)


def test_a_click_reaches_a_button_in_the_tree() raises -> None:
    var ui = UI()
    var play = ui.add(Button("Play", Rectangle((0, 0), 100, 40)))
    var context = Context()
    var canvas = _canvas()
    point_at(context, (0, 0))
    press(context, (0, 0))
    ui.update(context, canvas)
    next_frame(context)
    release(context, (0, 0))
    ui.update(context, canvas)
    assert_true(ui[play].released())


def test_only_the_topmost_of_two_overlapping_buttons_is_hovered() raises -> (
    None
):
    var ui = UI()
    var below = ui.add(Button("Below", Rectangle((0, 0), 100, 40)))
    var above = ui.add(Button("Above", Rectangle((30, 0), 100, 40)))
    var context = Context()
    var canvas = _canvas()
    point_at(context, (10, 0))  # over both
    ui.update(context, canvas)
    assert_true(ui[above].hovered())
    assert_false(ui[below].hovered())
    point_at(context, (-40, 0))  # over the one below alone
    ui.update(context, canvas)
    assert_true(ui[below].hovered())


def test_a_panel_covers_what_is_beneath_it_and_text_does_not() raises -> None:
    var ui = UI()
    var under = ui.add(Button("Under", Rectangle((0, 0), 100, 40)))
    _ = ui.add(Label("Text", Rectangle((0, 0), 100, 40)))
    var context = Context()
    var canvas = _canvas()
    point_at(context, (0, 0))
    ui.update(context, canvas)
    assert_true(ui[under].hovered())  # through the label
    _ = ui.add(Panel(Rectangle((0, 0), 200, 100)))
    ui.update(context, canvas)
    assert_false(ui[under].hovered())  # under the panel


def test_a_widget_in_a_panel_is_drawn_on_it_and_hovered() raises -> None:
    var ui = UI()
    var card = ui.add(Panel(Rectangle((0, 0), 200, 100)))
    var ok = ui.add(Button("OK", Rectangle((0, 0), 80, 40)), card)
    var context = Context()
    var canvas = _canvas()
    point_at(context, (0, 0))
    ui.update(context, canvas)
    assert_true(ui[ok].hovered())
    canvas.draw(ui)
    assert_true(
        canvas.color_at((-35, 0)) != ColorScheme.light().surface_container
    )


def test_text_on_a_dark_panel_takes_its_content_color() raises -> None:
    var ui = UI()
    var card = ui.add(
        Panel(Rectangle((0, 0), 200, 100), style=Style(fill=Color.BLACK))
    )
    _ = ui.add(Label("Hi", Rectangle((0, 0), 100, 40)), card)
    var context = Context()
    point_at(context, (140, 90))
    var canvas = _canvas()
    ui.update(context, canvas)
    canvas.draw(ui)
    var lightest = 0
    for x in range(-15, 15):
        lightest = max(lightest, Int(canvas.color_at((Float64(x), 0.0)).r))
    assert_true(lightest > 200)


def test_the_shared_style_and_colors_reach_every_widget() raises -> None:
    var ui = UI()
    ui.style(button=Style(fill=Color.RED))
    _ = ui.add(Button("A", Rectangle((-60, 0), 80, 40)))
    _ = ui.add(
        Button("B", Rectangle((60, 0), 80, 40), style=Style(fill=Color.BLUE))
    )
    var context = Context()
    point_at(context, (140, 90))
    var canvas = _canvas()
    ui.update(context, canvas)
    canvas.draw(ui)
    assert_equal(canvas.color_at((-95, 0)), Color.RED)
    assert_equal(canvas.color_at((25, 0)), Color.BLUE)  # its own style wins
    ui.colors(ColorScheme.dark())
    ui.style(button=Style())  # cleared
    var dark = _canvas()
    ui.update(context, dark)
    dark.draw(ui)
    assert_equal(dark.color_at((-95, 0)), ColorScheme.dark().primary)


def test_under_a_camera_the_tree_is_hit_where_it_is_drawn() raises -> None:
    var ui = UI()
    var play = ui.add(Button("Play", Rectangle((300, 0), 100, 40)))
    var context = Context()
    var canvas = _canvas()
    canvas.camera(Camera(Point(300, 0)))
    point_at(context, (0, 0))
    ui.update(context, canvas)
    assert_true(ui[play].hovered())


def test_one_update_and_draw_run_every_kind_of_widget() raises -> None:
    var ui = UI()
    var card = ui.add(Panel(Rectangle((0, 0), 280, 190)))
    _ = ui.add(Label("Settings", Rectangle((0, 80), 260, 24)), card)
    var name = ui.add(TextField(rect=Rectangle((0, 45), 260, 32)), card)
    _ = ui.add(Slider(0.5, 0, 1, Rectangle((0, 10), 260, 32)), card)
    var music = ui.add(Checkbox("Music", Rectangle((0, -25), 260, 32)), card)
    _ = ui.add(Button("OK", Rectangle((0, -60), 100, 32)), card)
    _ = ui.add(Picture(Image.solid(4, 4, Color.RED), (120, -80)), card)
    var context = Context()
    var canvas = _canvas()
    point_at(context, (-100, -25))
    press(context, (-100, -25))
    release(context, (-100, -25))
    ui.update(context, canvas)
    canvas.draw(ui)
    assert_true(ui[music].checked)
    assert_false(ui[name].focused())
    assert_equal(canvas.color_at((120, -80)), Color.RED)


def test_get_reads_several_widgets_in_one_expression() raises -> None:
    var ui = UI()
    var x = ui.add(Slider(3, 0, 10, Rectangle((0, 0), 200, 32)))
    var y = ui.add(Slider(4, 0, 10, Rectangle((0, -40), 200, 32)))
    assert_equal(Vector(ui.get(x).value, ui.get(y).value), Vector(3, 4))
    var copy = ui.get(x)
    copy.value = 9
    assert_equal(ui[x].value, 3.0)  # a copy: the UI's widget is unchanged


def test_each_style_call_keeps_the_kinds_it_leaves_out() raises -> None:
    var ui = UI()
    ui.style(button=Style(fill=Color.RED))
    ui.style(label=Style(font_size=30))
    assert_equal(ui._styles[].button.fill.value(), Color.RED)
    assert_equal(ui._styles[].label.font_size.value(), 30.0)
    ui.style(button=Style())
    assert_false(Bool(ui._styles[].button.fill))
    assert_equal(ui._styles[].label.font_size.value(), 30.0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
