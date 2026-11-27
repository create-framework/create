"""`Button`: a widget with a line of text on it, which the mouse clicks."""

from create.app import Context
from create.geometry import Rectangle
from create.render import Canvas, Style, Text
from create.render.style import _ResolvedStyle
from ._pointer import _Pointer
from create.color.color_scheme import ColorScheme
from ._theme import (
    _ButtonLook,
    _Theme,
    _BUTTON_FILLED,
    _BUTTON_TONAL,
    _BUTTON_OUTLINED,
    _BUTTON_TEXT,
)
from ._layout import _UNSIZED
from .text_field import _measure
from ._navigation import _Focus
from .clickable import Clickable
from .widget import Widget


comptime _BUTTON_PADDING = 24.0
"""The room a button leaves either side of its text, at the size it
prefers."""


struct Button(Clickable, Copyable, Movable, Widget):
    """A button with a line of text on it, which the mouse clicks.

    Keep it in a field, so it remembers being pressed from one frame to the
    next. Each frame, `update` it and then draw it, and ask it what
    happened:

    ```mojo
    # In `create`, building the `play` field:
    var play = Button("Play", Rectangle((0, 0), 160, 48))

    # In `update`:
    self.play.update(context, canvas)
    canvas.draw(self.play)
    if self.play.released():
        self.start()
    ```

    `released()` is the click: the button let go over it, after being
    pressed on it. `pressed()` is the press, `down()` whether it is held,
    and `hovered()` whether the pointer is over it.

    It is filled in the colours' `primary` unless its `style` says
    otherwise, and its style changes only what it sets:
    `Style(corner_radius=0)` squares its corners. Four ready-made styles
    give it a weight, from the main action to the quietest: `Button.FILLED`
    (the look it has unless styled), `Button.TONAL`, `Button.OUTLINED` and
    `Button.TEXT`. Each names its colours by `ColorRole`, so it follows the
    colours it is drawn in, and layers under a style of your own with
    `over`: `Style(corner_radius=0).over(Button.OUTLINED)`. It
    steps lighter or darker while hovered and pressed, and fades while not
    `enabled`, when it reacts to nothing.
    """

    comptime FILLED = _BUTTON_FILLED
    """Filled in `primary`, with its text in `on_primary`: for the main
    action. A button looks like this unless styled."""
    comptime TONAL = _BUTTON_TONAL
    """Filled in `primary_container`, a paler tint of `primary`: for a
    secondary action."""
    comptime OUTLINED = _BUTTON_OUTLINED
    """Outlined, unfilled, with its text in `primary`: for a less important
    action."""
    comptime TEXT = _BUTTON_TEXT
    """Only its text, in `primary`: for the quietest actions, such as a
    list of choices."""

    var text: String
    """The text on it."""
    var rect: Rectangle
    """Where it is, and how big. To turn a button, update and draw it
    inside a `canvas.transform` block, which turns its text with it."""
    var style: Style
    """Its own style, over its default look."""
    var enabled: Bool
    """Whether it reacts to the mouse. A disabled button is faded."""
    var _pointer: _Pointer
    var _activated: Bool
    var _look: _ButtonLook

    def __init__(
        out self,
        text: String,
        rect: Rectangle = _UNSIZED,
        *,
        style: Style = Style(),
        enabled: Bool = True,
    ):
        self.text = text
        self.rect = rect
        self.style = style
        self.enabled = enabled
        self._pointer = _Pointer()
        self._activated = False
        self._look = _Theme.default().button(
            style,
            rect.height,
            hovered=False,
            pressed=False,
            disabled=not enabled,
        )

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        """Read what the mouse did to it this frame, and work out its look:
        call it before drawing it.

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
        var pointer = canvas.to_local(context.mouse.position)
        self._pointer.update(
            context.mouse,
            self.rect.contains(pointer),
            free=free,
            enabled=enabled,
        )
        self._activated = focus.activated and enabled
        self._look = theme.button(
            self.style,
            self.rect.height,
            hovered=self._pointer.hovered,
            pressed=self._pointer.looks_pressed(),
            disabled=not enabled,
        )

    def _measure(
        self, mut canvas: Canvas, theme: _Theme
    ) raises -> Tuple[Float64, Float64]:
        """The size it prefers in `theme`: its text with room either side,
        `control_height` tall."""
        var look = theme.button(
            self.style,
            theme.control_height,
            hovered=False,
            pressed=False,
            disabled=False,
        )
        var width = _measure(canvas, self.text, look.text)
        return (width + 2 * _BUTTON_PADDING, theme.control_height)

    def hovered(self) -> Bool:
        """Whether the pointer is over it, as of its last `update`."""
        return self._pointer.hovered

    def pressed(self) -> Bool:
        """Whether the left button went down over it this frame."""
        return self._pointer.pressed

    def down(self) -> Bool:
        """Whether it is held: pressed on it, and the button not let go
        since, wherever the pointer has moved."""
        return self._pointer.held

    def released(self) -> Bool:
        """Whether it was clicked this frame: let go over it after being
        pressed on it, or, in a `UI`, pressed with Enter, Space or a
        gamepad's south button while it has focus."""
        return self._pointer.released or self._activated

    def _ring(self) -> Rectangle:
        """The shape its focus ring goes round."""
        var shape = self.rect.copy()
        shape.corner_radius = self._look.corner_radius
        return shape^

    def draw_to(self, mut canvas: Canvas):
        var shape = self.rect.copy()
        shape.corner_radius = self._look.corner_radius
        if self._look.body:
            with canvas._with_style(self._look.body.value()):
                canvas.draw(shape)
        if self._look.layer:
            with canvas._with_style(self._look.layer.value()):
                canvas.draw(shape)
        with canvas._with_style(self._look.text):
            canvas.draw(Text(self.text, self.rect.position))
