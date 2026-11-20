"""`ButtonVariant` and `ButtonStyle`: how a button looks."""

from create.color import Color
from create.math._optional_float64 import _OptionalFloat64
from .theme import TypeStyle


@fieldwise_init
struct ButtonVariant(
    Copyable, Equatable, ImplicitlyCopyable, Movable, Writable
):
    """Which of the theme's colours a button is drawn in.

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


struct ButtonStyle(Copyable, ImplicitlyCopyable, Movable, Writable):
    """How one button looks, where it differs from its variant. Every field
    left unset is worked out from the theme when the button is drawn.

    ```mojo
    # In `update`, inside `with self.ui.screen(context, canvas) as ui:`:
    var square = ButtonStyle(corner_radius=4)
    if ui.button("Stop", Rectangle((0, 0), 120, 40), style=square):
        ...
    ```
    """

    var container_color: Optional[Color]
    """The fill behind the text."""
    var content_color: Optional[Color]
    """The text's colour, which the hovered and pressed states tint the
    button with too."""
    var outline_color: Optional[Color]
    """The border's colour; a border is drawn when this or
    `outline_thickness` is given, or for an `OUTLINED` button."""
    var outline_thickness: Optional[Float64]
    var corner_radius: Optional[Float64]
    """Half the height unless given, so the ends are round."""
    var text_style: Optional[TypeStyle]
    """The theme's `label` text unless given."""

    def __init__(
        out self,
        *,
        container_color: Optional[Color] = None,
        content_color: Optional[Color] = None,
        outline_color: Optional[Color] = None,
        outline_thickness: _OptionalFloat64 = None,
        corner_radius: _OptionalFloat64 = None,
        text_style: Optional[TypeStyle] = None,
    ):
        self.container_color = container_color
        self.content_color = content_color
        self.outline_color = outline_color
        self.outline_thickness = outline_thickness._value
        self.corner_radius = corner_radius._value
        self.text_style = text_style
