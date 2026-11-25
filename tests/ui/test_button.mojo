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


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
