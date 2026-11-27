"""`Button` as a value: updated, drawn with `canvas.draw` and asked what the
mouse did, with no `UI`."""
from std.testing import TestSuite, assert_equal, assert_false, assert_true

from create import *
from _input import next_frame, point_at, press, release

comptime _RECT = Rectangle((0, 0), 100, 40)
comptime _EDGE = Point(-45, 0)
"""Inside the button, clear of its text."""


def _canvas() raises -> Canvas:
    return Canvas(200, 100, antialiasing=Antialiasing.OFF)


def test_a_press_and_release_over_it_clicks_it_once() raises -> None:
    var button = Button("OK", _RECT)
    var context = Context()
    var canvas = _canvas()
    point_at(context, (0, 0))
    button.update(context, canvas)
    assert_true(button.hovered())
    assert_false(button.pressed() or button.down() or button.released())
    next_frame(context)
    press(context, (0, 0))
    button.update(context, canvas)
    assert_true(button.pressed())
    assert_true(button.down())
    assert_false(button.released())
    next_frame(context)
    button.update(context, canvas)
    assert_false(button.pressed())
    assert_true(button.down())
    next_frame(context)
    release(context, (0, 0))
    button.update(context, canvas)
    assert_true(button.released())
    assert_false(button.down())
    next_frame(context)
    button.update(context, canvas)
    assert_false(button.released())


def test_a_press_that_starts_elsewhere_is_not_a_click() raises -> None:
    var button = Button("OK", _RECT)
    var context = Context()
    var canvas = _canvas()
    press(context, (90, 40))
    button.update(context, canvas)
    assert_false(button.pressed())
    next_frame(context)
    point_at(context, (0, 0))
    release(context, (0, 0))
    button.update(context, canvas)
    assert_true(button.hovered())
    assert_false(button.released())


def test_a_release_away_from_it_is_not_a_click() raises -> None:
    var button = Button("OK", _RECT)
    var context = Context()
    var canvas = _canvas()
    point_at(context, (0, 0))
    press(context, (0, 0))
    button.update(context, canvas)
    next_frame(context)
    point_at(context, (90, 40))
    button.update(context, canvas)
    assert_true(button.down())  # held, wherever the pointer goes
    assert_false(button.hovered())
    next_frame(context)
    release(context, (90, 40))
    button.update(context, canvas)
    assert_false(button.released())
    assert_false(button.down())


def test_a_disabled_button_reacts_to_nothing() raises -> None:
    var button = Button("OK", _RECT, enabled=False)
    var context = Context()
    var canvas = _canvas()
    point_at(context, (0, 0))
    press(context, (0, 0))
    button.update(context, canvas)
    assert_false(button.hovered() or button.pressed() or button.down())
    next_frame(context)
    release(context, (0, 0))
    button.update(context, canvas)
    assert_false(button.released())


def test_it_looks_hovered_in_the_frame_it_is_hovered() raises -> None:
    var button = Button("OK", _RECT)
    var context = Context()
    var rest = _canvas()
    point_at(context, (90, 40))
    button.update(context, rest)
    rest.draw(button)
    var hovered = _canvas()
    point_at(context, (0, 0))
    button.update(context, hovered)
    hovered.draw(button)
    assert_true(rest.color_at(_EDGE) != hovered.color_at(_EDGE))


def test_under_a_camera_it_is_hit_where_it_is_drawn() raises -> None:
    var button = Button("OK", Rectangle((300, 0), 100, 40))
    var context = Context()
    var canvas = _canvas()
    canvas.camera(Camera(Point(300, 0)))  # the button at the screen's centre
    point_at(context, (0, 0))
    button.update(context, canvas)
    assert_true(button.hovered())


def test_a_turned_button_is_hit_through_its_rotation() raises -> None:
    var turned = Rectangle((0, 0), 100, 20, rotation=PI / 2)  # standing up
    var button = Button("OK", turned)
    var context = Context()
    var canvas = _canvas()
    point_at(context, (0, 40))
    button.update(context, canvas)
    assert_true(button.hovered())


def test_it_is_drawn_in_the_canvas_colours() raises -> None:
    var context = Context()
    point_at(context, (0, 90))  # away, so it isn't hovered
    for dark in [False, True]:
        var colors = ColorScheme.dark() if dark else ColorScheme.light()
        var button = Button("OK", _RECT)
        var canvas = _canvas()
        if dark:
            canvas.colors(colors)
        button.update(context, canvas)  # the light colours unless set
        canvas.draw(button)
        assert_equal(canvas.color_at(_EDGE), colors.primary)


def test_a_ready_made_style_follows_the_colours() raises -> None:
    var context = Context()
    point_at(context, (0, 90))  # away, so it isn't hovered
    var button = Button("OK", _RECT, style=Button.TONAL)
    var canvas = _canvas()
    canvas.colors(ColorScheme.dark())
    button.update(context, canvas)
    canvas.draw(button)
    assert_equal(canvas.color_at(_EDGE), ColorScheme.dark().primary_container)


def test_a_style_over_a_ready_made_one_keeps_the_rest() raises -> None:
    var context = Context()
    point_at(context, (0, 90))
    var button = Button(
        "OK", _RECT, style=Style(fill=Color.RED).over(Button.OUTLINED)
    )
    var canvas = _canvas()
    button.update(context, canvas)
    canvas.draw(button)
    assert_equal(canvas.color_at(_EDGE), Color.RED)
    assert_equal(
        button._look.text.text_color, ColorScheme.light().primary
    )  # the outlined button's text


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
