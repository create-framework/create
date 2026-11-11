from std.testing import (
    TestSuite,
    assert_almost_equal,
    assert_equal,
    assert_false,
    assert_true,
)
from create.core.context import Context
from create.input.gamepad import Gamepad
from create.input.gamepad_button import GamepadButton
from create.core._events import apply_events
from create.render._viewport import Viewport
from create._window.event import (
    Event,
    GamepadAdded,
    GamepadAxisMoved,
    GamepadButtonDown,
    GamepadButtonUp,
    GamepadRemoved,
    FocusLost,
)
from create.math.vector2d import Vector2D


def _frame(mut context: Context, var events: List[Event]):
    _ = apply_events(events, Viewport(), context)


def test_no_gamepad_reads_disconnected_and_idle() raises -> None:
    var context = Context()
    var pad = context.gamepad()
    assert_false(pad.connected)
    assert_false(pad.down(GamepadButton.SOUTH))
    assert_equal(pad.left_stick, Vector2D.ZERO)
    assert_equal(pad.button, GamepadButton.NONE)
    assert_false(pad.down(GamepadButton.NONE))
    assert_false(context.gamepad(3).connected)
    assert_false(context.gamepad(-1).connected)


def test_added_gamepad_takes_slot_zero() raises -> None:
    var context = Context()
    _frame(context, [Event(GamepadAdded(42, "Pad 42"))])
    assert_true(context.gamepad().connected)
    assert_false(context.gamepad(1).connected)


def test_button_down_pressed_released_lifecycle() raises -> None:
    var context = Context()
    _frame(
        context,
        [
            Event(GamepadAdded(1, "Pad 1")),
            Event(GamepadButtonDown(1, GamepadButton.START.value)),
        ],
    )
    var pad = context.gamepad()
    assert_true(pad.down(GamepadButton.START))
    assert_true(pad.pressed(GamepadButton.START))
    assert_equal(pad.button, GamepadButton.START)

    _frame(context, [])
    pad = context.gamepad()
    assert_true(pad.down(GamepadButton.START))
    assert_false(pad.pressed(GamepadButton.START))

    _frame(context, [Event(GamepadButtonUp(1, GamepadButton.START.value))])
    pad = context.gamepad()
    assert_false(pad.down(GamepadButton.START))
    assert_true(pad.released(GamepadButton.START))
    assert_equal(pad.button, GamepadButton.START)

    _frame(context, [])
    assert_false(context.gamepad().released(GamepadButton.START))


def test_events_reach_the_pad_they_name() raises -> None:
    var context = Context()
    _frame(
        context,
        [
            Event(GamepadAdded(10, "Pad 10")),
            Event(GamepadAdded(20, "Pad 20")),
            Event(GamepadButtonDown(20, GamepadButton.SOUTH.value)),
            Event(GamepadButtonDown(99, GamepadButton.EAST.value)),
        ],
    )
    assert_false(context.gamepad(0).down(GamepadButton.SOUTH))
    assert_true(context.gamepad(1).down(GamepadButton.SOUTH))
    assert_false(context.gamepad(0).down(GamepadButton.EAST))
    assert_false(context.gamepad(1).down(GamepadButton.EAST))


def test_stick_is_y_up() raises -> None:
    var context = Context()
    # SDL reports pushing up as negative y.
    _frame(
        context,
        [Event(GamepadAdded(1, "Pad 1")), Event(GamepadAxisMoved(1, 1, -1.0))],
    )
    var stick = context.gamepad().left_stick
    assert_almost_equal(stick.x, 0.0)
    assert_almost_equal(stick.y, 1.0)


def test_stick_inside_dead_zone_reads_zero() raises -> None:
    var context = Context()
    _frame(
        context,
        [
            Event(GamepadAdded(1, "Pad 1")),
            Event(GamepadAxisMoved(1, 2, 0.15)),
            Event(GamepadAxisMoved(1, 3, 0.1)),
        ],
    )
    assert_equal(context.gamepad().right_stick, Vector2D.ZERO)


def test_stick_rescales_past_dead_zone() raises -> None:
    var context = Context()
    var half = Gamepad.STICK_DEAD_ZONE + (1.0 - Gamepad.STICK_DEAD_ZONE) / 2
    _frame(
        context,
        [Event(GamepadAdded(1, "Pad 1")), Event(GamepadAxisMoved(1, 0, half))],
    )
    assert_almost_equal(context.gamepad().left_stick.x, 0.5)


def test_diagonal_stick_capped_at_unit_length() raises -> None:
    var context = Context()
    _frame(
        context,
        [
            Event(GamepadAdded(1, "Pad 1")),
            Event(GamepadAxisMoved(1, 0, 1.0)),
            Event(GamepadAxisMoved(1, 1, 1.0)),
        ],
    )
    var stick = context.gamepad().left_stick
    assert_almost_equal(stick.magnitude(), 1.0)
    assert_true(stick.x > 0 and stick.y < 0)


def test_triggers() raises -> None:
    var context = Context()
    _frame(
        context,
        [
            Event(GamepadAdded(1, "Pad 1")),
            Event(GamepadAxisMoved(1, 4, 0.25)),
            Event(GamepadAxisMoved(1, 5, 1.0)),
        ],
    )
    assert_equal(context.gamepad().left_trigger, 0.25)
    assert_equal(context.gamepad().right_trigger, 1.0)


def test_removed_pad_frees_its_slot_and_others_stay() raises -> None:
    var context = Context()
    _frame(
        context,
        [Event(GamepadAdded(1, "Pad 1")), Event(GamepadAdded(2, "Pad 2"))],
    )
    _frame(
        context,
        [
            Event(GamepadButtonDown(1, GamepadButton.SOUTH.value)),
            Event(GamepadRemoved(1)),
        ],
    )
    assert_false(context.gamepad(0).connected)
    assert_false(context.gamepad(0).down(GamepadButton.SOUTH))
    assert_true(context.gamepad(1).connected)

    _frame(
        context,
        [
            Event(GamepadAdded(3, "Pad 3")),
            Event(GamepadButtonDown(3, GamepadButton.EAST.value)),
        ],
    )
    assert_true(context.gamepad(0).connected)
    assert_true(context.gamepad(0).down(GamepadButton.EAST))
    assert_false(context.gamepad(2).connected)


def test_duplicate_add_keeps_one_slot() raises -> None:
    var context = Context()
    _frame(
        context,
        [Event(GamepadAdded(5, "Pad 5")), Event(GamepadAdded(5, "Pad 5"))],
    )
    assert_false(context.gamepad(1).connected)


def test_connect_edge_lasts_one_frame_and_carries_the_name() raises -> None:
    var context = Context()
    _frame(context, [Event(GamepadAdded(4, "Pad 4"))])
    var pad = context.gamepad()
    assert_true(pad.connected_this_frame)
    assert_false(pad.disconnected_this_frame)
    assert_equal(pad.name, "Pad 4")
    _frame(context, [])
    pad = context.gamepad()
    assert_false(pad.connected_this_frame)
    assert_equal(pad.name, "Pad 4")


def test_disconnect_edge_keeps_the_name_for_its_frame() raises -> None:
    var context = Context()
    _frame(context, [Event(GamepadAdded(4, "Pad 4"))])
    _frame(context, [Event(GamepadRemoved(4))])
    var pad = context.gamepad()
    assert_false(pad.connected)
    assert_true(pad.disconnected_this_frame)
    assert_equal(pad.name, "Pad 4")
    _frame(context, [])
    pad = context.gamepad()
    assert_false(pad.disconnected_this_frame)
    assert_equal(pad.name, "")


def test_pad_replacing_one_that_left_this_frame_keeps_both_edges() raises -> (
    None
):
    var context = Context()
    _frame(context, [Event(GamepadAdded(1, "Old"))])
    _frame(context, [Event(GamepadRemoved(1)), Event(GamepadAdded(2, "New"))])
    var pad = context.gamepad()
    assert_true(pad.connected)
    assert_true(pad.connected_this_frame)
    assert_true(pad.disconnected_this_frame)
    assert_equal(pad.name, "New")


def test_rumble_queues_for_a_connected_pad_only() raises -> None:
    var context = Context()
    context.rumble(0.5)
    assert_equal(len(context._rumbles), 0)
    _frame(context, [Event(GamepadAdded(9, "Pad 9"))])
    context.rumble(0.25, low_frequency=0.5, high_frequency=0.0)
    context.rumble(1.0, player=1)
    assert_equal(len(context._rumbles), 1)
    var rumble = context._rumbles[0]
    assert_equal(rumble.id, 9)
    assert_equal(rumble.low_frequency, 0.5)
    assert_equal(rumble.high_frequency, 0.0)
    assert_equal(rumble.seconds, 0.25)


def test_rumbles_are_dropped_at_the_next_frame() raises -> None:
    var context = Context()
    _frame(context, [Event(GamepadAdded(9, "Pad 9"))])
    context.rumble(0.2)
    context._advance_frame(16)
    assert_equal(len(context._rumbles), 0)


def test_prints_keyword_form() raises -> None:
    assert_equal(
        String(Gamepad()),
        (
            "Gamepad(connected=False, connected_this_frame=False,"
            " disconnected_this_frame=False, name='',"
            " left_stick=Vector2D(0.0, 0.0), right_stick=Vector2D(0.0, 0.0),"
            " left_trigger=0.0, right_trigger=0.0, button=GamepadButton.NONE)"
        ),
    )


def test_gamepad_button_prints_as_source() raises -> None:
    assert_equal(String(GamepadButton.SOUTH), "GamepadButton.SOUTH")
    assert_equal(String(GamepadButton.NONE), "GamepadButton.NONE")
    assert_equal(String(GamepadButton(40)), "GamepadButton(40)")


def test_disconnecting_releases_what_the_pad_held() raises -> None:
    var context = Context()
    _frame(
        context,
        [
            Event(GamepadAdded(1, "Pad 1")),
            Event(GamepadButtonDown(1, GamepadButton.SOUTH.value)),
        ],
    )
    _frame(context, [Event(GamepadRemoved(1))])
    var pad = context.gamepad()
    assert_false(pad.down(GamepadButton.SOUTH))
    assert_true(pad.released(GamepadButton.SOUTH))

    _frame(context, [])
    assert_false(context.gamepad().released(GamepadButton.SOUTH))


def test_focus_lost_releases_pad_buttons() raises -> None:
    var context = Context()
    _frame(
        context,
        [
            Event(GamepadAdded(1, "Pad 1")),
            Event(GamepadButtonDown(1, GamepadButton.SOUTH.value)),
        ],
    )
    _frame(context, [Event(FocusLost())])
    assert_false(context.gamepad().down(GamepadButton.SOUTH))
    assert_true(context.gamepad().released(GamepadButton.SOUTH))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
