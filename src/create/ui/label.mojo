"""`Label`: text placed in a rectangle."""

from create.core import Context
from create.geometry import Rectangle
from create.math import Point
from create.render import Align, Canvas, Style, Text
from create.render.style import _ResolvedStyle
from ._theme import _Theme
from .widget import Widget


struct Label(Copyable, Movable, Widget):
    """Text placed in a rectangle, by an alignment: in its centre unless
    told otherwise, against its left edge with `Align.LEFT`, and so on. It
    reacts to nothing.

    ```mojo
    # In `create`, building the `title` field:
    var title = Label("Settings", Rectangle((0, 200), 300, 40), Align.LEFT)

    # In `update`:
    self.title.update(context, canvas)
    canvas.draw(self.title)
    ```

    Its text is drawn in the light colours' text colour, in its own `style`
    over that; `Style(font_size=22)` makes a heading of it. The text is not
    wrapped or cut to the rectangle: the rectangle only places it.
    """

    var text: String
    """The text drawn."""
    var rect: Rectangle
    """Where the text is placed."""
    var alignment: Optional[Align]
    """Which point of `rect` the text is anchored to: the style's
    `text_alignment` when `None`, and the centre when that is unset too."""
    var style: Style
    """Its own style, over the default text style."""
    var _look: _ResolvedStyle

    def __init__(
        out self,
        text: String,
        rect: Rectangle,
        alignment: Optional[Align] = None,
        *,
        style: Style = Style(),
    ):
        self.text = text
        self.rect = rect
        self.alignment = alignment
        self.style = style
        self._look = _Theme.default().label(style, alignment, disabled=False)

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        """Work out its look from its fields: call it before drawing it."""
        self._update(context, canvas, _Theme.default(), disabled=False)

    def _update(
        mut self,
        mut context: Context,
        mut canvas: Canvas,
        theme: _Theme,
        *,
        disabled: Bool,
    ) raises:
        """`update` in `theme`, as a `UI` updates it; `disabled` fades it, as
        a disabled part of a `UI` does."""
        self._look = theme.label(self.style, self.alignment, disabled=disabled)

    def draw_to(self, mut canvas: Canvas):
        with canvas._with_style(self._look):
            canvas.draw(
                Text(self.text, _anchor(self.rect, self._look.text_alignment))
            )


def _anchor(rect: Rectangle, alignment: Align) -> Point:
    """The point of `rect` that text placed by `alignment` is anchored to:
    its centre, or the middle of the edge or the corner `alignment` names."""
    var x = rect.position.x
    var y = rect.position.y
    if (
        alignment == Align.LEFT
        or alignment == Align.TOP_LEFT
        or alignment == Align.BOTTOM_LEFT
    ):
        x -= rect.width / 2
    elif (
        alignment == Align.RIGHT
        or alignment == Align.TOP_RIGHT
        or alignment == Align.BOTTOM_RIGHT
    ):
        x += rect.width / 2
    if (
        alignment == Align.TOP
        or alignment == Align.TOP_LEFT
        or alignment == Align.TOP_RIGHT
    ):
        y += rect.height / 2
    elif (
        alignment == Align.BOTTOM
        or alignment == Align.BOTTOM_LEFT
        or alignment == Align.BOTTOM_RIGHT
    ):
        y -= rect.height / 2
    return Point(x, y)
