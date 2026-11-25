"""`Button`, and `ButtonVariant`: which of the colours a button is drawn
in."""

from create.core import Context
from create.geometry import Rectangle
from create.render import Canvas, Style, Text
from create.render.style import _ResolvedStyle
from ._pointer import _Pointer
from ._theme import _ButtonLook, _Theme
from .widget import Clickable, Widget


@fieldwise_init
struct ButtonVariant(
    Copyable, Equatable, ImplicitlyCopyable, Movable, Writable
):
    """Which of the colours a button is drawn in.

    From the most prominent to the quietest:

    - `FILLED`: filled with `primary`, for the main action on screen.
    - `TONAL`: filled with `secondary_container`, for a secondary action.
    - `OUTLINED`: an `outline` border and `primary` text, for an action that
      should be visible but not stand out.
    - `TEXT`: `primary` text alone, for the least important actions.
    """

    var value: Int

    comptime FILLED = ButtonVariant(0)
    comptime TONAL = ButtonVariant(1)
    comptime OUTLINED = ButtonVariant(2)
    comptime TEXT = ButtonVariant(3)

    def __eq__(self, other: Self) -> Bool:
        return self.value == other.value

    def write_to[W: Writer](self, mut writer: W):
        if self == Self.FILLED:
            writer.write("ButtonVariant.FILLED")
        elif self == Self.TONAL:
            writer.write("ButtonVariant.TONAL")
        elif self == Self.OUTLINED:
            writer.write("ButtonVariant.OUTLINED")
        elif self == Self.TEXT:
            writer.write("ButtonVariant.TEXT")
        else:
            writer.write("ButtonVariant(", self.value, ")")


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

    Its look comes from its `variant`, in the light colours, with its own
    `style` over that: `Style(corner_radius=4)` squares its corners. It
    steps lighter or darker while hovered and pressed, and fades while not
    `enabled`, when it reacts to nothing.
    """

    var text: String
    """The text on it."""
    var rect: Rectangle
    """Where it is, and how big. A rotated rectangle turns it."""
    var variant: ButtonVariant
    """Which of the colours it is drawn in."""
    var style: Style
    """Its own style, over its variant's look."""
    var enabled: Bool
    """Whether it reacts to the mouse. A disabled button is faded."""
    var _pointer: _Pointer
    var _look: _ButtonLook

    def __init__(
        out self,
        text: String,
        rect: Rectangle,
        *,
        variant: ButtonVariant = ButtonVariant.FILLED,
        style: Style = Style(),
        enabled: Bool = True,
    ):
        self.text = text
        self.rect = rect
        self.variant = variant
        self.style = style
        self.enabled = enabled
        self._pointer = _Pointer()
        self._look = _Theme.default().button(
            style,
            variant,
            rect.height,
            hovered=False,
            pressed=False,
            disabled=not enabled,
        )

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        """Read what the mouse did to it this frame, and work out its look:
        call it before drawing it."""
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
        var pointer = canvas.to_local(context.mouse.position)
        self._pointer.update(
            context.mouse,
            self.rect.contains(pointer),
            free=free,
            enabled=self.enabled,
        )
        self._look = theme.button(
            self.style,
            self.variant,
            self.rect.height,
            hovered=self._pointer.hovered,
            pressed=self._pointer.looks_pressed(),
            disabled=not self.enabled,
        )

    def hovered(self) -> Bool:
        return self._pointer.hovered

    def pressed(self) -> Bool:
        return self._pointer.pressed

    def down(self) -> Bool:
        return self._pointer.held

    def released(self) -> Bool:
        return self._pointer.released

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
