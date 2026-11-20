"""Style and theme scopes, and panels: a `ui.style` block styles its widgets
under each call's own style, a `ui.theme` block draws them in another theme,
and a panel draws a surface beneath what is inside it and sets the colour of
text on it."""
from std.testing import TestSuite, assert_equal, assert_false, assert_true

from create import *
from _input import next_frame, point_at, press, press_key, release

comptime _A = Rectangle((0, 0), 100, 40)
comptime _BESIDE = Point(30, 0)  # on the button, clear of its text


def _canvas() raises -> Canvas:
    return Canvas(300, 200, antialiasing=Antialiasing.OFF)


def test_a_style_block_styles_its_widgets_and_a_call_beats_it() raises -> None:
    var ui = UI()
    var context = Context()
    var inside = _canvas()
    var called = _canvas()
    var outside = _canvas()
    with ui.screen(context, inside) as layer:
        with layer.style(button=ButtonStyle(container_color=Color.RED)):
            _ = layer.button("OK", _A)
    with ui.screen(context, called) as layer:
        with layer.style(button=ButtonStyle(container_color=Color.RED)):
            _ = layer.button(
                "OK", _A, style=ButtonStyle(container_color=Color.BLUE)
            )
    with ui.screen(context, outside) as layer:
        _ = layer.button("OK", _A)
    assert_equal(inside.color_at(_BESIDE), Color.RED)
    assert_equal(called.color_at(_BESIDE), Color.BLUE)
    assert_equal(outside.color_at(_BESIDE), ui.theme().colors.primary)


def test_nested_style_blocks_merge_field_by_field() raises -> None:
    var ui = UI()
    var context = Context()
    var canvas = _canvas()
    canvas.background(Color.WHITE)
    with ui.screen(context, canvas) as layer:
        with layer.style(button=ButtonStyle(container_color=Color.RED)):
            with layer.style(button=ButtonStyle(corner_radius=0)):
                _ = layer.button("OK", _A)
    assert_equal(canvas.color_at(_BESIDE), Color.RED)  # from the outer block
    assert_equal(canvas.color_at((49, 19)), Color.RED)  # a square corner


def test_a_theme_block_draws_in_its_theme() raises -> None:
    var ui = UI()
    var context = Context()
    var canvas = _canvas()
    with ui.screen(context, canvas) as layer:
        with layer.theme(Theme.dark()):
            _ = layer.button("OK", _A)
            assert_equal(
                layer.theme().colors.primary, Theme.dark().colors.primary
            )
        assert_equal(layer.theme().colors.primary, Theme.light().colors.primary)
    assert_equal(canvas.color_at(_BESIDE), Theme.dark().colors.primary)


def test_a_panel_is_drawn_beneath_what_is_inside_it() raises -> None:
    var ui = UI()
    var context = Context()
    var canvas = _canvas()
    with ui.screen(context, canvas) as layer:
        with layer.panel(Rectangle((0, 0), 200, 120)):
            _ = layer.button("OK", _A)
    var colors = ui.theme().colors
    assert_equal(canvas.color_at(_BESIDE), colors.primary)
    assert_equal(canvas.color_at((0, 45)), colors.surface_container)


def test_text_on_a_panel_takes_its_content_colour() raises -> None:
    var ui = UI()
    var context = Context()
    var canvas = _canvas()
    var colors = ui.theme().colors
    with ui.screen(context, canvas) as layer:
        assert_equal(layer.content_color(), colors.on_surface)
        with layer.panel(_A, style=PanelStyle(color=colors.primary)):
            assert_equal(layer.content_color(), colors.on_primary)
            with layer.panel(_A, style=PanelStyle(color=Color.BLACK)):
                assert_equal(layer.content_color(), Color.WHITE)
            assert_equal(layer.content_color(), colors.on_primary)
        assert_equal(layer.content_color(), colors.on_surface)


def test_a_panel_covers_what_is_beneath_and_a_click_on_it_clears_focus() raises -> (
    None
):
    var ui = UI()
    var context = Context()
    var below_clicked = False
    for frame in range(3):
        if frame == 1:
            next_frame(context)
            press_key(context, Key.TAB)  # focus the button beneath
        elif frame == 2:
            next_frame(context)
            press(context, _A.position)
            release(context, _A.position)
        else:
            point_at(context, _A.position)
        var canvas = _canvas()
        with ui.screen(context, canvas) as layer:
            below_clicked = layer.button("Below", _A)
            with layer.panel(Rectangle((0, 0), 200, 120)):
                pass
    assert_false(below_clicked)
    assert_false(Bool(ui._focused))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
