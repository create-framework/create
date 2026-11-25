"""Drawing in a layer: `ui.draw` lands in call order when the block ends,
above everything drawn before then, plain canvas calls in the block
included."""
from std.testing import TestSuite, assert_equal

from create import *


def _canvas() raises -> Canvas:
    return Canvas(64, 64, antialiasing=Antialiasing.OFF)


def test_layer_drawing_lands_in_call_order() raises -> None:
    var ui = UI()
    var context = Context()
    var canvas = _canvas()
    with ui.screen(context, canvas) as layer:
        layer.draw(Rectangle((0, 0), 40, 40), Style(fill=Color.RED))
        layer.draw(Circle((0, 0), 5), Style(fill=Color.BLUE))
    assert_equal(canvas.color_at((0, 0)), Color.BLUE)
    assert_equal(canvas.color_at((15, 15)), Color.RED)


def test_a_canvas_call_in_the_block_draws_beneath_the_layer() raises -> None:
    var ui = UI()
    var context = Context()
    var canvas = _canvas()
    with ui.screen(context, canvas) as layer:
        layer.draw(Circle((0, 0), 10), Style(fill=Color.BLUE))
        canvas.fill(Color.GREEN)
        canvas.rectangle((0, 0), 40, 40)
    assert_equal(canvas.color_at((0, 0)), Color.BLUE)
    assert_equal(canvas.color_at((15, 15)), Color.GREEN)


def test_a_screen_layer_ignores_the_camera() raises -> None:
    var ui = UI()
    var context = Context()
    var canvas = _canvas()
    var camera = Camera()
    camera.position = Point(20, 0)
    canvas.camera(camera)
    with ui.screen(context, canvas) as layer:
        layer.draw(Circle((0, 0), 5), Style(fill=Color.BLUE))
    assert_equal(canvas.color_at((0, 0)), Color.BLUE)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
