from create.math.point2d import Point2D
from create.math.vector2d import Vector2D

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
    `Point2D`s because they are locations; `wheel` is a `Vector2D` because
    a scroll is a displacement.

    It is the loop's own `Mouse`, not a copy: held buttons persist in it
    from frame to frame, and only the edges and the wheel clear. So read it
    and don't write it.
    """

    var position: Point2D
    """Where the pointer is, in screen space."""
    var button: MouseButton
    """The most recent button pressed (`MouseButton.NONE` before any). Kept
    until the next press."""
    var wheel: Vector2D
    """This frame's scroll, zero on a frame without any."""
    var press_position: Point2D
    """Where the most recent press happened, in screen space. Captured from
    the press itself, so a move later in the same frame doesn't overwrite
    where a click started, and kept until the next press, so a drag is
    `position - press_position` for as long as the button is down."""
    var _held: Int
    var _pressed: Int
    var _released: Int
    # Buttons are a handful of small ints (1..5), not the sparse space keys
    # need a set for, so a bitmask is enough.

    def __init__(out self):
        self.position = Point2D(0, 0)
        self.button = MouseButton.NONE
        self.wheel = Vector2D(0, 0)
        self.press_position = Point2D(0, 0)
        self._held = 0
        self._pressed = 0
        self._released = 0

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
        self.wheel = Vector2D(0, 0)

    def _move(mut self, position: Point2D):
        self.position = position

    def _button_down(mut self, button: MouseButton, position: Point2D):
        self.button = button
        self.position = position
        self.press_position = position
        self._held |= button._bit()
        self._pressed |= button._bit()

    def _button_up(mut self, button: MouseButton, position: Point2D):
        self.position = position
        self._held &= ~button._bit()
        self._released |= button._bit()

    def _scroll(mut self, delta: Vector2D):
        self.wheel = delta
