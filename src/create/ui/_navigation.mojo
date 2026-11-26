"""Internal: focus as a `UI` hands it to a widget, the arrow and gamepad
readings that move it, and the geometry it moves by."""

from create.app import Context
from create.input import Gamepad, GamepadButton, Key, Keyboard
from create.math import Point, Vector


@fieldwise_init
struct _Focus(Copyable, ImplicitlyCopyable, Movable):
    """What a widget's focus means for it this frame, as the tree it is in
    decides it.

    A widget on its own gets `_Focus.standalone()`: no tree decides for it,
    so a text field takes focus by its own clicks."""

    var in_tree: Bool
    """Whether a tree decides its focus; when not, the fields below are
    unused."""
    var focused: Bool
    var keys: Bool
    """Whether keys act on it: focused from the keyboard or code, not by a
    click or a gamepad, so a game's own keys still work after a click."""
    var activated: Bool
    """Enter or Space while keys act on it, or a gamepad's south button
    while it has focus shown: a press, as a click is."""
    var step: Int
    """-1 or 1 when a gamepad pushed left or right on it while it has focus
    shown, for a slider to step; 0 otherwise."""

    @staticmethod
    def standalone() -> Self:
        return Self(
            in_tree=False, focused=False, keys=False, activated=False, step=0
        )


def _pads(context: Context, player: Optional[Int]) -> List[Gamepad]:
    """The gamepads that drive a tree: its player's, or every one."""
    if player:
        return [context.gamepad(player.value())]
    return context._gamepads._slots.copy()


def _pad_pressed(
    context: Context, player: Optional[Int], button: GamepadButton
) -> Bool:
    """Whether `button` went down this frame on a pad that drives a tree."""
    for pad in _pads(context, player):
        if pad.connected and pad.pressed(button):
            return True
    return False


comptime _REPEAT_DELAY = 0.4
"""Seconds a direction is held on a gamepad before it pushes again."""
comptime _REPEAT_INTERVAL = 0.1
"""Seconds between pushes while a direction stays held after that."""


struct _PadRepeat(Copyable, ImplicitlyCopyable, Movable):
    """The direction held on a tree's gamepads, kept between frames, and
    when a held direction pushes next."""

    var direction: Vector
    var next: Float64
    """The real time, in seconds, it pushes again while still held."""

    def __init__(out self):
        self.direction = Vector.ZERO
        self.next = 0.0


def _pad_push(
    context: Context, player: Optional[Int], mut repeat: _PadRepeat
) -> Vector:
    """This frame's push on the d-pad, or the left stick tipped past
    halfway: up, down, left or right. A push comes once when a direction is
    pressed, and again every `_REPEAT_INTERVAL` once it has been held for
    `_REPEAT_DELAY`, by the real clock, so a paused game's menu repeats
    too."""
    var now = context.time.real_elapsed
    var pressed = _direction(
        up=_pad_pressed(context, player, GamepadButton.DPAD_UP),
        down=_pad_pressed(context, player, GamepadButton.DPAD_DOWN),
        left=_pad_pressed(context, player, GamepadButton.DPAD_LEFT),
        right=_pad_pressed(context, player, GamepadButton.DPAD_RIGHT),
    )
    if pressed != Vector.ZERO:
        repeat.direction = pressed
        repeat.next = now + _REPEAT_DELAY
        return pressed
    var held = Vector.ZERO
    for pad in _pads(context, player):
        if not pad.connected:
            continue
        held = _direction(
            up=pad.down(GamepadButton.DPAD_UP),
            down=pad.down(GamepadButton.DPAD_DOWN),
            left=pad.down(GamepadButton.DPAD_LEFT),
            right=pad.down(GamepadButton.DPAD_RIGHT),
        )
        if held == Vector.ZERO and pad.left_stick.magnitude() > 0.5:
            var s = pad.left_stick
            if abs(s.x) > abs(s.y):
                held = Vector.RIGHT if s.x > 0 else Vector.LEFT
            else:
                held = Vector.UP if s.y > 0 else Vector.DOWN
        if held != Vector.ZERO:
            break
    if held != repeat.direction:
        repeat.direction = held
        repeat.next = now + _REPEAT_DELAY
        return held  # nothing, when let go
    if held != Vector.ZERO and now >= repeat.next:
        repeat.next = now + _REPEAT_INTERVAL
        return held
    return Vector.ZERO


def _direction(*, up: Bool, down: Bool, left: Bool, right: Bool) -> Vector:
    """The direction of whichever of the four is true, up first; none when
    none is."""
    if up:
        return Vector.UP
    if down:
        return Vector.DOWN
    if left:
        return Vector.LEFT
    if right:
        return Vector.RIGHT
    return Vector.ZERO


def _arrow_push(keyboard: Keyboard) -> Vector:
    """The arrow typed this frame, as a direction: typed, so a held arrow
    repeats as the system's key repeat does."""
    return _direction(
        up=keyboard.typed(Key.UP),
        down=keyboard.typed(Key.DOWN),
        left=keyboard.typed(Key.LEFT),
        right=keyboard.typed(Key.RIGHT),
    )


def _nearest(
    at: Optional[Point], direction: Vector, centres: List[Point]
) -> Optional[Int]:
    """Which of `centres` focus moves to from `at` in `direction`: the
    nearest ahead, where one straight ahead beats a nearer one off to the
    side. From no focus (`at` is `None`), the first."""
    if not centres:
        return None
    if not at:
        return 0
    var best = Optional[Int](None)
    var best_score = 0.0
    for i in range(len(centres)):
        var offset = centres[i] - at.value()
        var ahead = offset.dot(direction)
        if ahead <= 1:
            continue
        var aside = abs(offset.x * direction.y - offset.y * direction.x)
        var score = ahead + 2 * aside
        if not best or score < best_score:
            best = i
            best_score = score
    return best
