from std.testing import TestSuite, assert_equal, assert_false, assert_true
from create.input.mouse import Mouse
from create.input.mouse_button import MouseButton
from create.math.point2d import Point2D
from create.math.vector2d import Vector2D
from create.core.context import Context
from create.core._events import apply_events
from create.render._viewport import Viewport
from create._window.event import (
    Event,
    FocusLost,
    MouseButtonDown,
    MouseMoved,
    MouseWheel,
)


def test_initial_mouse_position() raises -> None:
    var mouse = Mouse()
    assert_equal(mouse.position.x, 0.0)
    assert_equal(mouse.position.y, 0.0)


def test_initial_mouse_not_pressed() raises -> None:
    var mouse = Mouse()
    assert_equal(mouse.down(), False)


def test_mouse_button_initial() raises -> None:
    var mouse = Mouse()
    assert_equal(mouse.button, MouseButton.NONE)


def test_initial_wheel_and_press_pos_zero() raises -> None:
    var mouse = Mouse()
    assert_equal(mouse.wheel.x, 0.0)
    assert_equal(mouse.wheel.y, 0.0)
    assert_equal(mouse.press_position.x, 0.0)
    assert_equal(mouse.press_position.y, 0.0)


def test_none_is_never_down() raises -> None:
    var mouse = Mouse()
    mouse._held = -1
    mouse._pressed = -1
    assert_false(mouse.down(MouseButton.NONE))
    assert_false(mouse.pressed(MouseButton.NONE))


def test_mouse_button_prints_as_source() raises -> None:
    assert_equal(String(MouseButton.RIGHT), "MouseButton.RIGHT")
    assert_equal(String(MouseButton.NONE), "MouseButton.NONE")
    assert_equal(String(MouseButton(8)), "MouseButton(8)")


def test_no_mouse_buttons_down_initially() raises -> None:
    var mouse = Mouse()
    assert_equal(mouse.down(), False)
    assert_equal(mouse.down(MouseButton.MIDDLE), False)
    assert_equal(mouse.pressed(), False)
    assert_equal(mouse.released(), False)


def test_mouse_down_default_button() raises -> None:
    var mouse = Mouse()
    mouse._held |= 1 << 1
    assert_true(mouse.down())
    assert_equal(mouse.down(MouseButton.MIDDLE), False)


def test_mouse_down_specific_button() raises -> None:
    var mouse = Mouse()
    mouse._held |= 1 << 3
    assert_true(mouse.down(MouseButton.RIGHT))
    assert_equal(mouse.down(MouseButton.LEFT), False)


def test_multiple_mouse_buttons_held_independently() raises -> None:
    var mouse = Mouse()
    mouse._held |= 1 << 1
    mouse._held |= 1 << 2
    assert_true(mouse.down(MouseButton.LEFT))
    assert_true(mouse.down(MouseButton.MIDDLE))
    assert_equal(mouse.down(MouseButton.RIGHT), False)


def test_mouse_pressed_button() raises -> None:
    var mouse = Mouse()
    mouse._pressed |= 1 << 2
    assert_true(mouse.pressed(MouseButton.MIDDLE))
    assert_equal(mouse.pressed(MouseButton.LEFT), False)


def test_mouse_released_button() raises -> None:
    var mouse = Mouse()
    mouse._released |= 1 << 1
    assert_true(mouse.released())
    assert_equal(mouse.released(MouseButton.MIDDLE), False)


def test_new_frame_clears_wheel_and_edge_buttons() raises -> None:
    var mouse = Mouse()
    mouse.wheel = Vector2D(3.0, -2.0)
    mouse._pressed |= 1 << 1
    mouse._released |= 1 << 2
    mouse._new_frame()
    assert_equal(mouse.wheel.x, 0.0)
    assert_equal(mouse.wheel.y, 0.0)
    assert_equal(mouse.pressed(MouseButton.LEFT), False)
    assert_equal(mouse.released(MouseButton.MIDDLE), False)


def test_new_frame_leaves_held_state_alone() raises -> None:
    # A button held across the frame boundary is not an edge — only the
    # pressed/released bits and the per-frame wheel delta reset.
    var mouse = Mouse()
    mouse._held |= 1 << 1
    mouse._new_frame()
    assert_true(mouse.down(MouseButton.LEFT))


def test_set_mouse_records_the_position() raises -> None:
    var mouse = Mouse()
    mouse._move(Point2D(12.5, -30.25))
    assert_equal(mouse.position.x, 12.5)
    assert_equal(mouse.position.y, -30.25)


def test_mouse_is_a_position_and_the_wheel_a_displacement() raises -> None:
    # The split this type distinction exists for: a drag is the difference
    # between two locations, which is a Vector2D, while the wheel already is
    # one.
    var mouse = Mouse()
    mouse.press_position = Point2D(10.0, 20.0)
    mouse._move(Point2D(13.0, 24.0))
    var drag: Vector2D = mouse.position - mouse.press_position
    assert_equal(drag, Vector2D(3.0, 4.0))
    assert_equal(mouse.press_position + drag, mouse.position)
    mouse.wheel = Vector2D(0.0, -1.0)
    assert_equal(mouse.wheel.magnitude(), 1.0)


def test_wheel_adds_up_a_frames_scrolls() raises -> None:
    var context = Context()
    var events: List[Event] = [
        MouseWheel(0.0, 0.25),
        MouseWheel(0.0, 0.5),
        MouseWheel(1.0, 0.0),
    ]
    _ = apply_events(events, Viewport(), context)
    assert_equal(context.mouse.wheel, Vector2D(1.0, 0.75))

    _ = apply_events([], Viewport(), context)
    assert_equal(context.mouse.wheel, Vector2D(0.0, 0.0))


def test_position_keeps_its_fraction() raises -> None:
    var context = Context()
    var events: List[Event] = [MouseMoved(10.5, 20.25)]
    _ = apply_events(events, Viewport(), context)
    assert_equal(context.mouse.position, Point2D(10.5, -20.25))


def test_focus_lost_releases_held_buttons() raises -> None:
    var context = Context()
    var events: List[Event] = [MouseButtonDown(MouseButton.LEFT.value, 0, 0)]
    _ = apply_events(events, Viewport(), context)
    assert_true(context.mouse.down())

    events = [FocusLost()]
    _ = apply_events(events, Viewport(), context)
    assert_false(context.mouse.down())
    assert_true(context.mouse.released())


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
