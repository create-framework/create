"""`Panel`: a surface for widgets to sit on."""

from create.color import Color
from create.core import Context
from create.geometry import Rectangle
from create.render import Canvas, Style
from ._theme import _PanelLook, _Theme
from .widget import Widget


struct Panel(Copyable, Movable, Widget):
    """A surface filling a rectangle, for widgets to sit on: a rounded card
    in the light colours' `surface_container`, unless its `style` says
    otherwise. It reacts to nothing.

    ```mojo
    # In `create`, building the `card` field:
    var card = Panel(Rectangle((0, 0), 320, 200))

    # In `update`: the card, then what sits on it.
    self.card.update(context, canvas)
    canvas.draw(self.card)
    ```

    `content_color()` is the colour for text on it: its style's
    `text_color`, or the partner of its fill, so text on a dark panel can be
    drawn light.
    """

    var rect: Rectangle
    """Where it is, and how big."""
    var style: Style
    """Its own style, over the default card."""
    var _look: _PanelLook

    def __init__(out self, rect: Rectangle, *, style: Style = Style()):
        self.rect = rect
        self.style = style
        self._look = _Theme.default().panel(style)

    def update(mut self, mut context: Context, canvas: Canvas) raises:
        """Work out its look from its fields: call it before drawing it."""
        self._update(context, canvas, _Theme.default())

    def _update(
        mut self, mut context: Context, canvas: Canvas, theme: _Theme
    ) raises:
        """`update` in `theme`, as a `UI` updates it."""
        self._look = theme.panel(self.style)

    def surface_color(self) -> Color:
        """The colour the widgets on it sit on: its fill, or, with its fill
        switched off, what is beneath it."""
        return self._look.surface

    def content_color(self) -> Color:
        """The colour for text on it."""
        return self._look.content

    def draw_to(self, mut canvas: Canvas):
        var shape = self.rect.copy()
        shape.corner_radius = self._look.style.corner_radius
        with canvas._with_style(self._look.style):
            canvas.draw(shape)
