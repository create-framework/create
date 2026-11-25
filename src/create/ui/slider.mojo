"""`Slider`: a handle dragged along a track to set a value."""

from create.core import Context
from create.geometry import Circle, Line, Rectangle
from create.math import Point, clamp
from create.render import Canvas, Style
from create._optional import _OptionalFloat64
from ._pointer import _Pointer
from ._theme import _SliderLook, _Theme
from .widget import Clickable, Widget


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

    Each part is a shape drawn in a style of its own: `track` is a line, so
    its stroke is the track's colour and thickness; `active_track` is the
    line from the start to the handle, over `track`, taking what it leaves
    unset from it; `handle` is a point, so its stroke is the handle's colour
    and its `stroke_thickness` its diameter (`StrokeCap.SQUARE` makes it
    square); and `handle_outline` is a circle round the handle, drawn when
    it sets a stroke or a fill.
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
    var active_track: Style
    var handle: Style
    var handle_outline: Style
    var enabled: Bool
    """Whether it reacts to the mouse. A disabled slider is faded."""
    var _pointer: _Pointer
    var _changed: Bool
    var _look: _SliderLook

    def __init__(
        out self,
        value: Float64,
        minimum: Float64,
        maximum: Float64,
        rect: Rectangle,
        *,
        step: _OptionalFloat64 = None,
        track: Style = Style(),
        active_track: Style = Style(),
        handle: Style = Style(),
        handle_outline: Style = Style(),
        enabled: Bool = True,
    ):
        self.value = value
        self.minimum = minimum
        self.maximum = maximum
        self.rect = rect
        self.step = step._value
        self.track = track
        self.active_track = active_track
        self.handle = handle
        self.handle_outline = handle_outline
        self.enabled = enabled
        self._pointer = _Pointer()
        self._changed = False
        self._look = _Theme.default().slider(
            track,
            active_track,
            handle,
            handle_outline,
            hovered=False,
            dragging=False,
            disabled=not enabled,
        )

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        """Read what the mouse did to it this frame, moving the handle while
        it is dragged, and work out its look: call it before drawing it.
        Raises if `step` isn't more than 0."""
        self._update(context, canvas, _Theme.default(), free=True)

    def _update(
        mut self,
        mut context: Context,
        mut canvas: Canvas,
        theme: _Theme,
        *,
        free: Bool,
    ) raises:
        """`update` in `theme`, as a `UI` updates it; `free` is false when
        another widget is over it at the pointer."""
        _check_step(self.step, "Slider")
        var pointer = canvas.to_local(context.mouse.position)
        self._pointer.update(
            context.mouse,
            self.rect.contains(pointer),
            free=free,
            enabled=self.enabled,
        )
        self._look = theme.slider(
            self.track,
            self.active_track,
            self.handle,
            self.handle_outline,
            hovered=self._pointer.hovered,
            dragging=self._pointer.dragged,
            disabled=not self.enabled,
        )
        self._changed = False
        if self._pointer.dragged:
            var ends = _slider_ends(self.rect, self._knob_radius())
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

    def changed(self) -> Bool:
        """Whether its last `update` changed `value`."""
        return self._changed

    def hovered(self) -> Bool:
        return self._pointer.hovered

    def pressed(self) -> Bool:
        return self._pointer.pressed

    def down(self) -> Bool:
        """Whether it is being dragged."""
        return self._pointer.held

    def released(self) -> Bool:
        return self._pointer.released

    def _knob_radius(self) -> Float64:
        return self._look.handle.stroke_thickness / 2

    def draw_to(self, mut canvas: Canvas):
        var radius = self._knob_radius()
        var ends = _slider_ends(self.rect, radius)
        var left = ends[0]
        var right = ends[1]
        var y = self.rect.position.y
        var handle_x = _handle_x(
            self.value, self.minimum, self.maximum, left, right
        )
        with canvas._with_style(self._look.track):
            canvas.draw(Line(Point(left, y), Point(right, y)))
        if handle_x > left:
            with canvas._with_style(self._look.active):
                canvas.draw(Line(Point(left, y), Point(handle_x, y)))
        var centre = Point(handle_x, y)
        with canvas._with_style(self._look.handle):
            canvas.draw(Line(centre, centre))
        ref outline = self._look.outline
        if outline.fill_enabled or outline.stroke_enabled:
            with canvas._with_style(outline):
                canvas.draw(Circle(centre, radius))


def _check_step(step: Optional[Float64], what: String) raises:
    """Raise unless `step`, when given, is more than 0."""
    if step and not step.value() > 0:  # NaN included
        raise Error(
            what + ": step must be more than 0, not " + String(step.value())
        )


def _slider_ends(
    rect: Rectangle, knob_radius: Float64
) -> Tuple[Float64, Float64]:
    """Where a slider's handle centre runs from and to, left and right:
    across `rect`, inset by the handle's radius so it stays inside."""
    return (
        rect.position.x - rect.width / 2 + knob_radius,
        rect.position.x + rect.width / 2 - knob_radius,
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
