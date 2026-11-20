"""World layers: widgets drawn through the camera and transform current when
the block opens, and clicked where they appear."""
from std.testing import TestSuite, assert_equal, assert_false, assert_true

from create import *
from _input import next_frame, point_at, press, release


def _camera() -> Camera:
    """Looks at (100, 0), magnified twice."""
    var camera = Camera()
    camera.position = Point(100, 0)
    camera.zoom = 2
    return camera


# At (100, 0) in the world, 40 x 20: on screen at the centre, 80 x 40.
comptime _CHEST = Rectangle((100, 0), 40, 20)


def _world_click(mut ui: UI, at: Point) raises -> Bool:
    """Two frames of a world-layer button at `_CHEST`, clicked at the screen
    point `at` in the second: what it returned then."""
    var context = Context()
    point_at(context, at)
    var clicked = False
    for frame in range(2):
        if frame == 1:
            next_frame(context)
            press(context, at)
            release(context, at)
        var canvas = Canvas(200, 100)
        canvas.camera(_camera())
        with ui.world(context, canvas) as layer:
            clicked = layer.button("Open", _CHEST)
    return clicked


def test_a_world_button_is_clicked_where_it_appears() raises -> None:
    var ui = UI()
    assert_true(_world_click(ui, Point(30, 0)))  # world (115, 0): inside


def test_a_world_button_is_not_clicked_where_it_would_be_unzoomed() raises -> (
    None
):
    var ui = UI()
    # world (125, 0): outside, though inside the button's unzoomed size
    assert_false(_world_click(ui, Point(50, 0)))


def test_a_world_layer_draws_through_the_camera() raises -> None:
    var ui = UI()
    var context = Context()
    var canvas = Canvas(200, 100, antialiasing=Antialiasing.OFF)
    canvas.camera(_camera())
    with ui.world(context, canvas) as layer:
        layer.draw(_CHEST, Style(fill=Color.RED))
    assert_equal(canvas.color_at((35, 0)), Color.RED)  # zoomed: 80 wide
    assert_false(canvas.color_at((45, 0)) == Color.RED)


def _turned_click(mut ui: UI, at: Point) raises -> Bool:
    """A world-layer button at (50, 0), 60 x 20, inside a quarter turn: on
    screen it stands upright at (0, 50)."""
    var context = Context()
    point_at(context, at)
    var clicked = False
    for frame in range(2):
        if frame == 1:
            next_frame(context)
            press(context, at)
            release(context, at)
        var canvas = Canvas(200, 200)
        canvas.rotate(PI / 2)
        with ui.world(context, canvas) as layer:
            clicked = layer.button("Turned", Rectangle((50, 0), 60, 20))
    return clicked


def test_a_world_button_turns_with_the_transform() raises -> None:
    var ui = UI()
    assert_true(_turned_click(ui, Point(0, 70)))
    var other = UI()
    assert_false(_turned_click(other, Point(20, 50)))


def test_a_screen_layer_over_a_world_layer_takes_the_click() raises -> None:
    var ui = UI()
    var context = Context()
    var at = Point(0, 0)
    point_at(context, at)
    var world_clicked = False
    var screen_clicked = False
    for frame in range(2):
        if frame == 1:
            next_frame(context)
            press(context, at)
            release(context, at)
        var canvas = Canvas(200, 100)
        canvas.camera(_camera())
        with ui.world(context, canvas) as layer:
            world_clicked = layer.button("Open", _CHEST)
        with ui.screen(context, canvas) as layer:
            screen_clicked = layer.button("Menu", Rectangle((0, 0), 60, 30))
    assert_false(world_clicked)
    assert_true(screen_clicked)


def test_drawing_after_a_world_layer_covers_it() raises -> None:
    var ui = UI()
    var context = Context()
    var canvas = Canvas(200, 100, antialiasing=Antialiasing.OFF)
    with ui.world(context, canvas) as layer:
        layer.draw(Rectangle((0, 0), 40, 40), Style(fill=Color.RED))
    canvas.fill(Color.BLUE)
    canvas.stroke_enabled(False)
    canvas.rectangle((0, 0), 20, 20)
    assert_equal(canvas.color_at((0, 0)), Color.BLUE)
    assert_equal(canvas.color_at((15, 15)), Color.RED)


def test_a_transform_changed_inside_the_block_does_not_move_it() raises -> None:
    var ui = UI()
    var context = Context()
    var canvas = Canvas(200, 100, antialiasing=Antialiasing.OFF)
    with ui.world(context, canvas) as layer:
        layer.draw(Rectangle((0, 0), 20, 20), Style(fill=Color.RED))
        canvas.translate(Vector(60, 0))
    assert_equal(canvas.color_at((0, 0)), Color.RED)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
