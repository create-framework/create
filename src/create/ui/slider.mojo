"""`Slider`: a handle dragged along a track to set a value."""

from create.app import Context
from create.geometry import Line, Rectangle
from create.input import Key, Keyboard
from create.math import Point, ceil, clamp, floor
from create.render import Canvas, Style, StrokeCap
from create.math import OptionalNumber
from ._pointer import _Pointer
from create.color.color_scheme import ColorScheme
from ._theme import _SliderLook, _Theme
from ._layout import _UNSIZED
from ._navigation import _Focus
from .clickable import Clickable
from .widget import Widget


comptime _CONTROL_WIDTH = 200.0
"""How wide a slider or a text field prefers to be."""


struct Slider(Clickable, Copyable, Movable, Widget):
    """A handle on a track, dragged to set `value` between `minimum` and
    `maximum`.

    ```mojo
    # In `create`, building the `volume` field:
    var volume = Slider(0.8, 0, 1, Rectangle((0, 0), 240, 32))

    # In `update`:
    self.volume.update(context, canvas)
    canvas.draw(self.volume)
    if self.volume.changed():
        self.audio.volume(self.volume.value)
    ```

    Pressing anywhere in `rect` moves the handle there, and dragging moves
    it on, even once the pointer leaves `rect`. `step` rounds the value to
    multiples of it counted from `minimum`, and must be more than 0. A
    `value` outside `minimum` to `maximum` is drawn at the nearer end, and
    left as it is until dragged. `maximum` may be less than `minimum`, which
    runs the slider the other way.

    Each part is a shape drawn in a style of its own: `track` is a line
    across `rect`, so its stroke is the track's colour and thickness;
    `active_track` is the line from the start to the handle, over `track`,
    taking what it leaves unset from it; and `handle` is a rectangle, so its
    fill is its colour, its stroke its outline and its `corner_radius` how
    round it is: half its size makes it round, and 0 square.

    The handle is `handle_size` wide and tall, or `handle_width` by
    `handle_height` when given both, such as a thin upright handle; half
    the `UI`'s `control_height` square unless given. Its centre runs from
    half its width inside the left end of `rect` to as far inside the right
    end, so the whole handle stays inside `rect`.
    """

    var value: Float64
    """The value it sets. Set it to move the handle from the program."""
    var minimum: Float64
    """The value at the left end."""
    var maximum: Float64
    """The value at the right end."""
    var rect: Rectangle
    """Where it is: the track runs across its middle, and a press anywhere
    in it moves the handle."""
    var step: Optional[Float64]
    """What the value is rounded to a multiple of, from `minimum`; `None`
    for any value."""
    var track: Style
    """The line across `rect`: its stroke is the track's colour and
    thickness."""
    var active_track: Style
    """The line from the start to the handle, over `track`, taking what
    it leaves unset from it."""
    var handle: Style
    """The handle, a rectangle: its fill is its colour, its stroke its
    outline and its `corner_radius` how round it is."""
    var handle_width: Optional[Float64]
    """How wide the handle is; `None` for half the `control_height`."""
    var handle_height: Optional[Float64]
    """How tall the handle is; `None` for half the `control_height`."""
    var enabled: Bool
    """Whether it reacts to the mouse. A disabled slider is faded."""
    var _pointer: _Pointer
    var _changed: Bool
    var _look: _SliderLook
    var _handle_size: Tuple[Float64, Float64]
    """The handle's width and height as last updated."""

    def __init__(
        out self,
        value: Float64,
        minimum: Float64,
        maximum: Float64,
        rect: Rectangle = _UNSIZED,
        *,
        step: OptionalNumber = None,
        track: Style = Style(),
        active_track: Style = Style(),
        handle: Style = Style(),
        handle_size: OptionalNumber = None,
        enabled: Bool = True,
    ):
        """A slider whose handle is `handle_size` square, or half the
        `control_height` when not given."""
        self.value = value
        self.minimum = minimum
        self.maximum = maximum
        self.rect = rect
        self.step = step._value
        self.track = track
        self.active_track = active_track
        self.handle = handle
        self.handle_width = handle_size._value
        self.handle_height = handle_size._value
        self.enabled = enabled
        self._pointer = _Pointer()
        self._changed = False
        var theme = _Theme.default()
        self._look = theme.slider(
            track,
            active_track,
            handle,
            hovered=False,
            dragging=False,
            disabled=not enabled,
        )
        self._handle_size = (0.0, 0.0)
        self._handle_size = self._handle_in(theme)

    def __init__(
        out self,
        value: Float64,
        minimum: Float64,
        maximum: Float64,
        rect: Rectangle = _UNSIZED,
        *,
        handle_width: Float64,
        handle_height: Float64,
        step: OptionalNumber = None,
        track: Style = Style(),
        active_track: Style = Style(),
        handle: Style = Style(),
        enabled: Bool = True,
    ):
        """A slider whose handle is `handle_width` wide and `handle_height`
        tall, such as a thin upright one."""
        self = Slider(
            value,
            minimum,
            maximum,
            rect,
            step=step,
            track=track,
            active_track=active_track,
            handle=handle,
            enabled=enabled,
        )
        self.handle_width = handle_width
        self.handle_height = handle_height
        self._handle_size = (handle_width, handle_height)

    def _handle_in(self, theme: _Theme) -> Tuple[Float64, Float64]:
        """The handle's width and height in `theme`: its own, or half the
        `control_height`."""
        var side = theme.control_height / 2
        return (
            self.handle_width.or_else(side),
            self.handle_height.or_else(side),
        )

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        """Read what the mouse did to it this frame, moving the handle while
        it is dragged, and work out its look: call it before drawing it.
        Raises if `step` isn't more than 0.

        It is drawn in the canvas's colours,
        `canvas.colors()`."""
        self._update(
            context, canvas, _Theme.default(canvas.colors()), free=True
        )

    def _update(
        mut self,
        mut context: Context,
        mut canvas: Canvas,
        theme: _Theme,
        *,
        free: Bool,
        focus: _Focus = _Focus.standalone(),
        disabled: Bool = False,
    ) raises:
        """`update` in `theme`, as a `UI` updates it; `free` is false when
        another widget is over it at the pointer, and `focus` is what the
        `UI`'s focus means for it, and `disabled` disables it as part of a
        disabled part of the `UI`, whatever its own `enabled`."""
        var enabled = self.enabled and not disabled
        _check_step(self.step, "Slider")
        var pointer = canvas.to_local(context.mouse.position)
        self._pointer.update(
            context.mouse,
            self.rect.contains(pointer),
            free=free,
            enabled=enabled,
        )
        self._look = theme.slider(
            self.track,
            self.active_track,
            self.handle,
            hovered=self._pointer.hovered,
            dragging=self._pointer.dragged,
            disabled=not enabled,
        )
        self._handle_size = self._handle_in(theme)
        self._changed = False
        if self._pointer.dragged:
            var ends = _slider_ends(self.rect, self._handle_size[0] / 2)
            var moved = _dragged_value(
                pointer.x,
                ends[0],
                ends[1],
                self.minimum,
                self.maximum,
                self.step,
            )
            if moved and moved.value() != self.value:
                self.value = moved.value()
                self._changed = True
        if enabled and (focus.keys or focus.push.x != 0):
            var towards_max = 0
            if focus.push.x != 0:
                towards_max = 1 if focus.push.x > 0 else -1
            if towards_max == 0:
                towards_max = _arrow_direction(context.keyboard)
            var keyed = _keyed_value(
                self.value,
                self.minimum,
                self.maximum,
                self.step,
                towards_max,
                home=focus.keys and context.keyboard.pressed(Key.HOME),
                end=focus.keys and context.keyboard.pressed(Key.END),
            )
            if keyed[1] != self.value:
                self.value = keyed[1]
                self._changed = True

    def _measure(
        self, mut canvas: Canvas, theme: _Theme
    ) raises -> Tuple[Float64, Float64]:
        """The size it prefers in `theme`: `_CONTROL_WIDTH` wide,
        `control_height` tall."""
        return (_CONTROL_WIDTH, theme.control_height)

    def changed(self) -> Bool:
        """Whether its last `update` changed `value`."""
        return self._changed

    def hovered(self) -> Bool:
        """Whether the pointer is over it, as of its last `update`."""
        return self._pointer.hovered

    def pressed(self) -> Bool:
        """Whether the left button went down over it this frame."""
        return self._pointer.pressed

    def down(self) -> Bool:
        """Whether it is being dragged."""
        return self._pointer.held

    def released(self) -> Bool:
        """Whether it was clicked this frame: let go over it, after being
        pressed on it."""
        return self._pointer.released

    def _ring(self) -> Rectangle:
        """The shape its focus ring goes round: its handle."""
        return self._handle_rect()

    def _handle_rect(self) -> Rectangle:
        """Where the handle is drawn: a rectangle centred on the track at
        the value."""
        var width = self._handle_size[0]
        var ends = _slider_ends(self.rect, width / 2)
        var x = _handle_x(
            self.value, self.minimum, self.maximum, ends[0], ends[1]
        )
        return Rectangle(
            Point(x, self.rect.position.y),
            width,
            self._handle_size[1],
            corner_radius=self._look.handle.corner_radius,
        )

    def draw_to(self, mut canvas: Canvas):
        var y = self.rect.position.y
        var handle = self._handle_rect()
        # The track spans `rect`, its caps included: a line's round or
        # square cap reaches half its thickness past its end.
        var left = self.rect.left()
        var right = self.rect.right()
        ref track = self._look.track
        if track.stroke_cap != StrokeCap.BUTT:
            left += track.stroke_thickness / 2
            right -= track.stroke_thickness / 2
        with canvas._with_style(track):
            canvas.draw(Line(Point(left, y), Point(right, y)))
        var handle_x = handle.position.x
        if handle_x > left:
            with canvas._with_style(self._look.active):
                canvas.draw(Line(Point(left, y), Point(handle_x, y)))
        with canvas._with_style(self._look.handle):
            canvas.draw(handle)


def _check_step(step: Optional[Float64], what: String) raises:
    """Raise unless `step`, when given, is more than 0."""
    if step and not step.value() > 0:  # NaN included
        raise Error(
            what + ": step must be more than 0, not " + String(step.value())
        )


def _slider_ends(rect: Rectangle, inset: Float64) -> Tuple[Float64, Float64]:
    """Where a slider's handle centre runs from and to, left and right:
    across `rect`, inset by half the handle's width so it stays inside."""
    return (
        rect.position.x - rect.width / 2 + inset,
        rect.position.x + rect.width / 2 - inset,
    )


def _handle_x(
    value: Float64,
    minimum: Float64,
    maximum: Float64,
    left: Float64,
    right: Float64,
) -> Float64:
    """Where the handle's centre is for `value`: at the nearer end when it
    is out of range."""
    var t = 0.0
    if maximum != minimum:
        t = clamp((value - minimum) / (maximum - minimum), 0.0, 1.0)
    return left + t * (right - left)


def _dragged_value(
    pointer_x: Float64,
    left: Float64,
    right: Float64,
    minimum: Float64,
    maximum: Float64,
    step: Optional[Float64],
) -> Optional[Float64]:
    """The value a handle dragged to `pointer_x` sets, rounded to `step`;
    `None` when the track is too short or the range empty to set one."""
    if not right > left or maximum == minimum:
        return None
    var t = clamp((pointer_x - left) / (right - left), 0.0, 1.0)
    var value = minimum + t * (maximum - minimum)
    if step:
        var size = step.value()
        value = minimum + Float64(round((value - minimum) / size)) * size
        if (maximum - minimum) * (value - maximum) > 0:
            # a step past `maximum` comes back inside, towards `minimum`
            value -= size if maximum > minimum else -size
    return value


def _arrow_direction(keyboard: Keyboard) -> Int:
    """Which way the arrow keys typed this frame step a slider: 1 towards
    its maximum (Right), -1 towards its minimum (Left), 0 for neither. Up
    and Down are the tree's, to move focus on."""
    if keyboard.typed(Key.RIGHT):
        return 1
    if keyboard.typed(Key.LEFT):
        return -1
    return 0


def _keyed_value(
    value: Float64,
    minimum: Float64,
    maximum: Float64,
    step: Optional[Float64],
    towards_max: Int,
    *,
    home: Bool,
    end: Bool,
) -> Tuple[Bool, Float64]:
    """A slider's value stepped by a key: one step towards `maximum` (1) or
    `minimum` (-1), or to an end for Home or End. A step is `step`, or a
    twentieth of the range. Whether the key acted, and the value it gives,
    kept inside the range."""
    if maximum == minimum:
        return (False, value)
    var size = step.value() if step else abs(maximum - minimum) / 20
    if maximum < minimum:
        size = -size  # steps count from `minimum` towards `maximum`
    var low = minimum if minimum < maximum else maximum
    var high = maximum if minimum < maximum else minimum
    # Steps land on the grid of steps counted from `minimum`, so they don't
    # gather floating-point error: 1.0 stepped down by 0.05 twice is 0.9,
    # not 0.8999999999999999.
    var steps_from_min = (value - minimum) / size
    var moved = value
    if towards_max != 0:
        # the next step along, so a value between two steps moves to the
        # one ahead of it rather than past it
        var nearest = Float64(round(steps_from_min))
        if abs(steps_from_min - nearest) < 1e-9:
            steps_from_min = nearest  # on a step, give or take error
        var next: Float64
        if towards_max > 0:
            next = floor(steps_from_min) + 1
        else:
            next = ceil(steps_from_min) - 1
        moved = minimum + next * size
    elif home:
        moved = minimum
    elif end:
        moved = maximum
    if moved == value:
        return (False, value)
    return (True, low if moved < low else (high if moved > high else moved))
