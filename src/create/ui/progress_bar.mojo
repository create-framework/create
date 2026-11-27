"""`ProgressBar`: a bar showing how far something has got."""

from create.app import Context
from create.geometry import Line, Rectangle
from create.math import Number, OptionalNumber, Point, clamp
from create.render import Canvas, Style
from create.color.color_scheme import ColorScheme
from ._theme import _ProgressBarLook, _Theme
from ._layout import _UNSIZED
from .slider import _CONTROL_WIDTH
from .widget import Widget


struct ProgressBar(Copyable, Movable, Widget):
    """A bar filled as far as `value` has got from `minimum` to `maximum`,
    such as a level loading, a health bar or a cooldown. It reacts to
    nothing.

    ```mojo
    # In `create`, building the `loading` field:
    var loading = ProgressBar(0, Rectangle((0, -100), 300, 20))

    # In `update`: fill it as the level loads.
    self.loading.value = self.loaded / self.total
    self.loading.update(context, canvas)
    canvas.draw(self.loading)
    ```

    A `value` outside `minimum` to `maximum` fills it no further than its
    ends. `maximum` may be less than `minimum`, which runs it the other way.

    Each part is a line drawn in a style of its own, so its stroke is its
    colour and thickness: `track` is the whole length, and `indicator`, the
    line from the start to `value`, lies over it, taking what it leaves
    unset from `track`.
    """

    var value: Float64
    """How far it has got. Set it as what it shows moves on."""
    var minimum: Float64
    """The value at the left end: empty."""
    var maximum: Float64
    """The value at the right end: full."""
    var rect: Rectangle
    """Where it is: the bar runs across its middle."""
    var track: Style
    """The line along its whole length: its stroke is its colour and
    thickness."""
    var indicator: Style
    """The line from the start to `value`, over `track`, taking what it
    leaves unset from it."""
    var enabled: Bool
    """Whether it is shown as active. A disabled bar is faded."""
    var _look: _ProgressBarLook

    def __init__(
        out self,
        value: Number,
        rect: Rectangle = _UNSIZED,
        *,
        minimum: OptionalNumber = None,
        maximum: OptionalNumber = None,
        track: Style = Style(),
        indicator: Style = Style(),
        enabled: Bool = True,
    ):
        self.value = Float64(value)
        self.minimum = minimum.or_else(0)
        self.maximum = maximum.or_else(1)
        self.rect = rect
        self.track = track
        self.indicator = indicator
        self.enabled = enabled
        self._look = _Theme.default().progress_bar(
            track, indicator, disabled=not enabled
        )

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        """Work out its look from its fields: call it before drawing it.

        It is drawn in the canvas's colours,
        `canvas.colors()`."""
        self._update(context, canvas, _Theme.default(canvas.colors()))

    def _update(
        mut self,
        mut context: Context,
        mut canvas: Canvas,
        theme: _Theme,
        *,
        disabled: Bool = False,
    ) raises:
        """`update` in `theme`, as a `UI` updates it; `disabled` fades it as
        part of a disabled part of the `UI`, whatever its own `enabled`."""
        self._look = theme.progress_bar(
            self.track,
            self.indicator,
            disabled=disabled or not self.enabled,
        )

    def _measure(
        self, mut canvas: Canvas, theme: _Theme
    ) raises -> Tuple[Float64, Float64]:
        """The size it prefers in `theme`: `_CONTROL_WIDTH` wide, half
        `control_height` tall."""
        return (_CONTROL_WIDTH, theme.control_height / 2)

    def fraction(self) -> Float64:
        """How far along it is, from 0 when empty to 1 when full."""
        if self.maximum == self.minimum:
            return 0.0
        return clamp(
            (self.value - self.minimum) / (self.maximum - self.minimum),
            0.0,
            1.0,
        )

    def draw_to(self, mut canvas: Canvas):
        # the ends inset by half the thickness, so round ends stay inside
        var inset = self._look.track.stroke_thickness / 2
        var left = self.rect.left() + inset
        var right = self.rect.right() - inset
        var y = self.rect.position.y
        with canvas._with_style(self._look.track):
            canvas.draw(Line(Point(left, y), Point(right, y)))
        var fraction = self.fraction()
        if fraction > 0:
            var end = left + fraction * (right - left)
            with canvas._with_style(self._look.indicator):
                canvas.draw(Line(Point(left, y), Point(end, y)))
