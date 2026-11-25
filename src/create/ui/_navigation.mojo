"""Internal: focus as a tree hands it to a widget, and the gamepad reading
and geometry focus moves by, shared by the widget tree and the old `UI`."""

from create.core import Context
from create.input import Gamepad, GamepadButton
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


def _pad_push(
    context: Context, player: Optional[Int], mut stick_was: Vector
) -> Vector:
    """This frame's push on the d-pad, or the left stick tipped past
    halfway: up, down, left or right, once per push. `stick_was` keeps the
    stick's direction between frames, so a held stick pushes once."""
    if _pad_pressed(context, player, GamepadButton.DPAD_UP):
        return Vector.UP
    if _pad_pressed(context, player, GamepadButton.DPAD_DOWN):
        return Vector.DOWN
    if _pad_pressed(context, player, GamepadButton.DPAD_LEFT):
        return Vector.LEFT
    if _pad_pressed(context, player, GamepadButton.DPAD_RIGHT):
        return Vector.RIGHT
    var stick = Vector.ZERO
    for pad in _pads(context, player):
        if pad.connected and pad.left_stick.magnitude() > 0.5:
            var s = pad.left_stick
            if abs(s.x) > abs(s.y):
                stick = Vector.RIGHT if s.x > 0 else Vector.LEFT
            else:
                stick = Vector.UP if s.y > 0 else Vector.DOWN
            break
    var push = stick if stick != stick_was else Vector.ZERO
    stick_was = stick
    return push


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
