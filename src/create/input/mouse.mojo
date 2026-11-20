from create.math.point import Point
from create.math.vector import Vector

from ._claim import _Claim
from .mouse_button import MouseButton


struct Mouse(Copyable, Movable, Writable):
    """The mouse's state for one frame, read as `context.mouse`.

    Buttons follow the vocabulary every device shares: *down* is held right
    now, *pressed*/*released* are the edges, true only in the frame the
    button went down or came up. Each takes `MouseButton.LEFT` unless told
    otherwise, so `context.mouse.pressed()` is a click.

    `position` is in screen coordinates — origin at the centre, y up, so
    negative left of and below it — and camera-independent, since the loop
    reads a frame's events before the `Canvas` (and any `Camera` it sets)
    exists. Convert with `camera.to_world`, or `canvas.to_local` for the
    frame a shape is drawn in. `position` and `press_position` are
    `Point`s because they are locations; `wheel` is a `Vector` because
    a scroll is a displacement.

    It is the loop's own `Mouse`, not a copy: held buttons persist in it
    from frame to frame, and only the edges and the wheel clear. So read it
    and don't write it.
    """

    var position: Point
    """Where the pointer is, in screen space."""
    var button: MouseButton
    """The most recent button pressed (`MouseButton.NONE` before any). Kept
    until the next press."""
    var movement: Vector
    """How far the pointer moved this frame, in screen units, y up: zero on
    a frame it stayed still. It keeps counting where `position` stops — at
    the screen's edge, and while `context.lock_mouse(True)` holds the
    pointer — so it is what a first-person camera or an endless drag
    turns by."""
    var wheel: Vector
    """This frame's scroll, zero on a frame without any."""
    var press_position: Point
    """Where the most recent press happened, in screen space. Captured from
    the press itself, so a move later in the same frame doesn't overwrite
    where a click started, and kept until the next press, so a drag is
    `position - press_position` for as long as the button is down."""
    var _held: Int
    var _pressed: Int
    var _released: Int
    var _claim: _Claim
    """Which of several readers, such as two `UI`s, has the mouse."""
    # Buttons are a handful of small ints (1..5), not the sparse space keys
    # need a set for, so a bitmask is enough.

    def __init__(out self):
        self.position = Point(0, 0)
        self.button = MouseButton.NONE
        self.movement = Vector(0, 0)
        self.wheel = Vector(0, 0)
        self.press_position = Point(0, 0)
        self._held = 0
        self._pressed = 0
        self._released = 0
        self._claim = _Claim()

    def down(self, button: MouseButton = MouseButton.LEFT) -> Bool:
        """Whether `button` is held right now."""
        return (self._held & button._bit()) != 0

    def pressed(self, button: MouseButton = MouseButton.LEFT) -> Bool:
        """Whether `button` went down this frame: true once per click.
        `press_position` is where it happened."""
        return (self._pressed & button._bit()) != 0

    def released(self, button: MouseButton = MouseButton.LEFT) -> Bool:
        """Whether `button` came up this frame: true once."""
        return (self._released & button._bit()) != 0

    def write_to[W: Writer](self, mut writer: W):
        writer.write(
            "Mouse(position=",
            self.position,
            ", button=",
            self.button,
            ", movement=",
            self.movement,
            ", wheel=",
            self.wheel,
            ", press_position=",
            self.press_position,
            ")",
        )

    def _new_frame(mut self):
        """Clear the edges and the wheel, keeping what is held. Called once
        a frame, before that frame's events."""
        self._pressed = 0
        self._released = 0
        self.movement = Vector(0, 0)
        self.wheel = Vector(0, 0)

    def _move(mut self, position: Point, movement: Vector = Vector.ZERO):
        self.position = position
        self.movement += movement

    def _button_down(mut self, button: MouseButton, position: Point):
        self.button = button
        self.position = position
        self.press_position = position
        self._held |= button._bit()
        self._pressed |= button._bit()

    def _button_up(mut self, button: MouseButton, position: Point):
        self.position = position
        self._held &= ~button._bit()
        self._released |= button._bit()

    def _scroll(mut self, delta: Vector):
        # Added up: a fast flick or a trackpad sends several in a frame.
        self.wheel += delta

    def _release_all(mut self):
        """Let go of every held button, each with its released edge, as
        `Keyboard._release_all` does."""
        self._released |= self._held
        self._held = 0
