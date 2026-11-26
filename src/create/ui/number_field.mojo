"""`NumberField`: a number, typed or stepped with − and + buttons, kept
within a range."""

from create.app import Context
from create.geometry import Rectangle
from create.input import Key
from create.math import OptionalNumber, Point
from create.render import Canvas, Style
from .button import Button
from .button_variant import ButtonVariant
from .color_scheme import ColorScheme
from ._theme import _Theme
from ._layout import _UNSIZED
from ._navigation import _Focus
from .text_field import TextField
from .clickable import Clickable
from .widget import Widget


comptime _FIELD_WIDTH = 120.0
"""How wide a number field's text prefers to be, without its buttons."""

comptime _BUTTON_GAP = 8.0
"""The gap between a number field's text and its buttons, and between
the buttons."""


struct NumberField(Clickable, Copyable, Movable, Widget):
    """A number between `minimum` and `maximum`, typed into a field or
    stepped with the − and + buttons beside it, such as a count of players
    or a volume in whole percent.

    ```mojo
    # In `create`, building the `players` field:
    var players = NumberField(2, 1, 8, Rectangle((0, 0), 220, 40))

    # In `update`:
    self.players.update(context, canvas)
    canvas.draw(self.players)
    if self.players.changed():
        self.seats = Int(self.players.value)
    ```

    Typing works as in a `TextField`. What was typed becomes the value on
    Enter, or when the field loses focus: kept within the range and rounded
    to `decimals` places. Text that isn't a number puts the value back as
    it was. The − and + buttons step the value by `step`, and so do the up
    and down arrows while the field has focus, and a gamepad's push in a
    `UI`.

    Its parts: `container` and `text_style` are the field's, as a text
    field's are, and `buttons` is the style of both buttons, as a button's
    `style` is.
    """

    var value: Float64
    """The number. Set it to change it from the program; the field shows it
    while it doesn't have focus."""
    var minimum: Float64
    """The smallest value it takes."""
    var maximum: Float64
    """The largest value it takes."""
    var rect: Rectangle
    """Where it is: the field, then the − and + buttons at its right end."""
    var step: Float64
    """How far the buttons, the arrows and a gamepad step the value."""
    var decimals: Int
    """How many places after the point the value is rounded to and shown
    with: whole numbers at 0."""
    var container: Style
    var text_style: Style
    var buttons: Style
    var enabled: Bool
    """Whether it reacts to the mouse and keyboard. A disabled field is
    faded."""
    var _field: TextField
    var _minus: Button
    var _plus: Button
    var _was_focused: Bool
    var _changed: Bool

    def __init__(
        out self,
        value: Float64,
        minimum: Float64,
        maximum: Float64,
        rect: Rectangle = _UNSIZED,
        *,
        step: OptionalNumber = None,
        decimals: Int = 0,
        container: Style = Style(),
        text_style: Style = Style(),
        buttons: Style = Style(),
        enabled: Bool = True,
    ):
        self.minimum = min(minimum, maximum)
        self.maximum = max(minimum, maximum)
        self.decimals = max(decimals, 0)
        self.value = _kept(value, self.minimum, self.maximum, self.decimals)
        self.rect = rect
        self.step = step.or_else(1)
        self.container = container
        self.text_style = text_style
        self.buttons = buttons
        self.enabled = enabled
        self._field = TextField(_shown(self.value, self.decimals))
        self._minus = Button("−", variant=ButtonVariant.TONAL)
        self._plus = Button("+", variant=ButtonVariant.TONAL)
        self._was_focused = False
        self._changed = False

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        """Read what the mouse and keyboard did to it this frame, and work
        out its look: call it before drawing it.

        It is drawn in the light colours; give it others with `colors`."""
        self._update(context, canvas, _Theme.default(), free=True)

    def update(
        mut self,
        mut context: Context,
        mut canvas: Canvas,
        *,
        colors: ColorScheme,
    ) raises:
        """`update`, drawn in `colors`, such as `ColorScheme.dark()` on a
        dark screen."""
        self._update(context, canvas, _Theme.default(colors), free=True)

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
        var before = self.value
        self._place_parts()
        # its own styles, over the `UI`'s for number fields; the text
        # field's and buttons' kinds then sit beneath those
        ref kind = theme.styles[]
        self._field.container = self.container.over(kind.number_field_container)
        self._field.text_style = self.text_style.over(
            kind.number_field_text_style
        )
        self._minus.style = self.buttons.over(kind.number_field_buttons)
        self._plus.style = self._minus.style
        self._field._update(
            context, canvas, theme, free=free, focus=focus, disabled=not enabled
        )
        var standalone = _Focus.standalone()
        self._minus._update(
            context,
            canvas,
            theme,
            free=free,
            focus=standalone,
            disabled=not enabled,
        )
        self._plus._update(
            context,
            canvas,
            theme,
            free=free,
            focus=standalone,
            disabled=not enabled,
        )
        var focused = self._field.focused()
        # what was typed counts on Enter, or as focus leaves
        if self._field.submitted() or (self._was_focused and not focused):
            self._take_typed()
        self._was_focused = focused
        if enabled:
            var by = 0.0
            if self._minus.released():
                by = -1
            elif self._plus.released():
                by = 1
            elif focused and context.keyboard.typed(Key.UP):
                by = 1
            elif focused and context.keyboard.typed(Key.DOWN):
                by = -1
            elif focus.push.y != 0:
                by = 1 if focus.push.y > 0 else -1
            if by != 0:
                self.value = _kept(
                    self.value + by * self.step,
                    self.minimum,
                    self.maximum,
                    self.decimals,
                )
                self._show_value()
        # the field shows the value, unless it is being typed into
        if not focused:
            var shown = _shown(self.value, self.decimals)
            if self._field.text() != shown:
                self._show_value()
        self._changed = self.value != before

    def _take_typed(mut self):
        """Make what was typed the value, kept within the range and rounded;
        text that isn't a number puts the value back."""
        try:
            var typed = atof(self._field.text().strip())
            self.value = _kept(typed, self.minimum, self.maximum, self.decimals)
        except:
            pass
        self._show_value()

    def _show_value(mut self):
        """Put the value in the field, with the caret after it, so typing
        carries on from its end."""
        self._field.set_text(_shown(self.value, self.decimals))
        self._field.move_to_end()

    def _place_parts(mut self):
        """Place the field and its two buttons in `rect`: the buttons square,
        at its right end."""
        var side = self.rect.height
        var y = self.rect.position.y
        var right = self.rect.right()
        self._plus.rect = Rectangle(Point(right - side / 2, y), side, side)
        self._minus.rect = Rectangle(
            Point(right - side - _BUTTON_GAP - side / 2, y), side, side
        )
        var width = max(self.rect.width - 2 * (side + _BUTTON_GAP), 0.0)
        self._field.rect = Rectangle(
            Point(self.rect.left() + width / 2, y), width, side
        )

    def _measure(
        self, mut canvas: Canvas, theme: _Theme
    ) raises -> Tuple[Float64, Float64]:
        """The size it prefers in `theme`: `_FIELD_WIDTH` for the field and
        room for two square buttons, `control_height` tall."""
        var side = theme.control_height
        return (_FIELD_WIDTH + 2 * (side + _BUTTON_GAP), side)

    def focused(self) -> Bool:
        """Whether it has focus, so typing goes into it."""
        return self._field.focused()

    def changed(self) -> Bool:
        """Whether its last `update` changed `value`, by typing, a button,
        an arrow or a gamepad."""
        return self._changed

    def hovered(self) -> Bool:
        return (
            self._field.hovered()
            or self._minus.hovered()
            or self._plus.hovered()
        )

    def pressed(self) -> Bool:
        return (
            self._field.pressed()
            or self._minus.pressed()
            or self._plus.pressed()
        )

    def down(self) -> Bool:
        return self._field.down() or self._minus.down() or self._plus.down()

    def released(self) -> Bool:
        return (
            self._field.released()
            or self._minus.released()
            or self._plus.released()
        )

    def draw_to(self, mut canvas: Canvas):
        canvas.draw(self._field)
        canvas.draw(self._minus)
        canvas.draw(self._plus)


def _kept(
    value: Float64, minimum: Float64, maximum: Float64, decimals: Int
) -> Float64:
    """`value` rounded to `decimals` places and kept between `minimum` and
    `maximum`."""
    var scale = 10.0**decimals
    var rounded = round(value * scale) / scale
    return min(max(rounded, minimum), maximum)


def _shown(value: Float64, decimals: Int) -> String:
    """`value` written with `decimals` places after the point, none at 0:
    `3`, `2.50`, `-0.5`."""
    var scale = 10.0**decimals
    var units = Int(round(abs(value) * scale))
    var sign = "-" if value < 0 and units != 0 else ""
    var places = 1
    for _ in range(decimals):
        places *= 10
    var whole = units // places
    if decimals == 0:
        return sign + String(whole)
    var fraction = String(units % places)
    while fraction.byte_length() < decimals:
        fraction = "0" + fraction
    return sign + String(whole) + "." + fraction
