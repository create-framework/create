"""`Theme`: the design tokens every widget draws from."""

from create.color import Color
from create.text import Font, FontWeight


@fieldwise_init
struct ColorScheme(Copyable, ImplicitlyCopyable, Movable, Writable):
    """The colours of a theme, as pairs of roles: each colour a widget is
    filled with, and the `on_` colour for text and icons drawn on it, chosen
    to read well together.

    - **`primary`** is for the most important actions, such as a filled
      button; **`secondary`** and **`tertiary`** for less prominent ones and
      accents; **`error`** for mistakes and warnings.
    - Each of those has a **`_container`**: a quieter fill of the same
      colour, such as a tonal button's.
    - **`background`** is behind everything, and **`surface`** is what
      widgets sit on; usually the two are the same colour. **`surface_dim`**
      and **`surface_bright`** are the darkest and lightest surfaces, and the
      **`surface_container_`** roles, from `lowest` to `highest`, are
      surfaces set apart from the one around them, such as a panel, a text
      field's fill or a slider's track. Text on any surface is `on_surface`,
      or the quieter `on_surface_variant`.
    - **`outline`** draws borders, and **`outline_variant`** fainter
      dividers.
    """

    var primary: Color
    var on_primary: Color
    var primary_container: Color
    var on_primary_container: Color
    var secondary: Color
    var on_secondary: Color
    var secondary_container: Color
    var on_secondary_container: Color
    var tertiary: Color
    var on_tertiary: Color
    var tertiary_container: Color
    var on_tertiary_container: Color
    var error: Color
    var on_error: Color
    var error_container: Color
    var on_error_container: Color
    var surface: Color
    var surface_dim: Color
    var surface_bright: Color
    var on_surface: Color
    var on_surface_variant: Color
    var surface_container_lowest: Color
    var surface_container_low: Color
    var surface_container: Color
    var surface_container_high: Color
    var surface_container_highest: Color
    var outline: Color
    var outline_variant: Color
    var background: Color
    var on_background: Color

    @staticmethod
    def light() -> ColorScheme:
        """Dark colours on a light background."""
        return ColorScheme(
            primary=Color.hex(0x3A5BC7),
            on_primary=Color.hex(0xFFFFFF),
            primary_container=Color.hex(0xDCE4FF),
            on_primary_container=Color.hex(0x0F1F5C),
            secondary=Color.hex(0x546070),
            on_secondary=Color.hex(0xFFFFFF),
            secondary_container=Color.hex(0xDDE3EC),
            on_secondary_container=Color.hex(0x18202B),
            tertiary=Color.hex(0x1D7279),
            on_tertiary=Color.hex(0xFFFFFF),
            tertiary_container=Color.hex(0xC8ECEE),
            on_tertiary_container=Color.hex(0x002B2E),
            error=Color.hex(0xBA1A1A),
            on_error=Color.hex(0xFFFFFF),
            error_container=Color.hex(0xFFDAD6),
            on_error_container=Color.hex(0x410002),
            surface=Color.hex(0xF8F9FC),
            surface_dim=Color.hex(0xD8DAE0),
            surface_bright=Color.hex(0xF8F9FC),
            on_surface=Color.hex(0x1A1C20),
            on_surface_variant=Color.hex(0x434852),
            surface_container_lowest=Color.hex(0xFFFFFF),
            surface_container_low=Color.hex(0xF2F3F7),
            surface_container=Color.hex(0xECEEF2),
            surface_container_high=Color.hex(0xE6E8ED),
            surface_container_highest=Color.hex(0xE1E3E8),
            outline=Color.hex(0x737883),
            outline_variant=Color.hex(0xC3C7D0),
            background=Color.hex(0xF8F9FC),
            on_background=Color.hex(0x1A1C20),
        )

    @staticmethod
    def dark() -> ColorScheme:
        """Light colours on a dark background."""
        return ColorScheme(
            primary=Color.hex(0xA9BEFF),
            on_primary=Color.hex(0x0E2766),
            primary_container=Color.hex(0x2C4497),
            on_primary_container=Color.hex(0xDCE4FF),
            secondary=Color.hex(0xBCC6D4),
            on_secondary=Color.hex(0x26303C),
            secondary_container=Color.hex(0x3D4754),
            on_secondary_container=Color.hex(0xDDE3EC),
            tertiary=Color.hex(0x8CD3D8),
            on_tertiary=Color.hex(0x00373A),
            tertiary_container=Color.hex(0x14585D),
            on_tertiary_container=Color.hex(0xC8ECEE),
            error=Color.hex(0xFFB4AB),
            on_error=Color.hex(0x690005),
            error_container=Color.hex(0x93000A),
            on_error_container=Color.hex(0xFFDAD6),
            surface=Color.hex(0x111318),
            surface_dim=Color.hex(0x111318),
            surface_bright=Color.hex(0x37393E),
            on_surface=Color.hex(0xE2E4EA),
            on_surface_variant=Color.hex(0xC3C7D0),
            surface_container_lowest=Color.hex(0x0C0E13),
            surface_container_low=Color.hex(0x191B20),
            surface_container=Color.hex(0x1D1F25),
            surface_container_high=Color.hex(0x282A2F),
            surface_container_highest=Color.hex(0x33353A),
            outline=Color.hex(0x8D919B),
            outline_variant=Color.hex(0x43474F),
            background=Color.hex(0x111318),
            on_background=Color.hex(0xE2E4EA),
        )

    def _override(
        mut self,
        primary: Optional[Color],
        on_primary: Optional[Color],
        secondary: Optional[Color],
        on_secondary: Optional[Color],
        tertiary: Optional[Color],
        on_tertiary: Optional[Color],
        error: Optional[Color],
        on_error: Optional[Color],
        surface: Optional[Color],
        on_surface: Optional[Color],
    ):
        """Replace the roles given. A surface given changes the background
        and every other colour worked out from it; a colour given changes its
        container to a quieter mix of it with the surface. A role given
        without its `on_` partner gets black or white, whichever reads better
        on it."""
        if surface:
            self._surfaces(surface.value(), on_surface)
        elif on_surface:
            self.on_surface = on_surface.value()
            self.on_background = on_surface.value()
        if primary:
            (
                self.primary,
                self.on_primary,
                self.primary_container,
                self.on_primary_container,
            ) = _family(primary.value(), on_primary, self.surface)
        elif on_primary:
            self.on_primary = on_primary.value()
        if secondary:
            (
                self.secondary,
                self.on_secondary,
                self.secondary_container,
                self.on_secondary_container,
            ) = _family(secondary.value(), on_secondary, self.surface)
        elif on_secondary:
            self.on_secondary = on_secondary.value()
        if tertiary:
            (
                self.tertiary,
                self.on_tertiary,
                self.tertiary_container,
                self.on_tertiary_container,
            ) = _family(tertiary.value(), on_tertiary, self.surface)
        elif on_tertiary:
            self.on_tertiary = on_tertiary.value()
        if error:
            (
                self.error,
                self.on_error,
                self.error_container,
                self.on_error_container,
            ) = _family(error.value(), on_error, self.surface)
        elif on_error:
            self.on_error = on_error.value()

    def _surfaces(mut self, surface: Color, on_surface: Optional[Color]):
        """Every surface, background and outline role, worked out from
        `surface`. The containers step from it towards the text colour, so
        each stands out a little more from the surface, and `lowest` steps
        the other way, a little further from the text."""
        var text = on_surface.or_else(_readable_on(surface))
        # black on a light surface, white on a dark one
        var away = _readable_on(text)
        var light = _readable_on(surface) == Color.BLACK
        self.surface = surface
        self.on_surface = text
        self.on_surface_variant = text.lerp(surface, 0.25)
        self.surface_dim = surface.lerp(text, 0.12) if light else surface
        self.surface_bright = surface if light else surface.lerp(text, 0.15)
        self.surface_container_lowest = surface.lerp(away, 0.6)
        self.surface_container_low = surface.lerp(text, 0.03)
        self.surface_container = surface.lerp(text, 0.06)
        self.surface_container_high = surface.lerp(text, 0.09)
        self.surface_container_highest = surface.lerp(text, 0.12)
        self.outline = text.lerp(surface, 0.5)
        self.outline_variant = text.lerp(surface, 0.8)
        self.background = surface
        self.on_background = text


def _contrast(a: Color, b: Color) -> Float64:
    """The WCAG contrast ratio of two colours: 1 for the same lightness, 21
    for black on white. Text needs at least 4.5 to read comfortably."""
    var la = a.luminance()
    var lb = b.luminance()
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)


def _readable_on(background: Color) -> Color:
    """Black or white, whichever contrasts more with `background`."""
    if _contrast(Color.BLACK, background) >= _contrast(Color.WHITE, background):
        return Color.BLACK
    return Color.WHITE


def _family(
    color: Color, on_color: Optional[Color], surface: Color
) -> Tuple[Color, Color, Color, Color]:
    """A role, its `on_` partner, its container and the container's `on_`
    partner, worked out from one colour on `surface`."""
    var container = color.lerp(surface, 0.7)
    return (
        color,
        on_color.or_else(_readable_on(color)),
        container,
        _readable_on(container),
    )


@fieldwise_init
struct TypeStyle(Copyable, ImplicitlyCopyable, Movable, Writable):
    """How one kind of text looks: its size, its weight and its font, or the
    canvas's default font when `font` is `None`."""

    var size: Float64
    var weight: FontWeight
    var font: Optional[Font]


@fieldwise_init
struct Typography(Copyable, ImplicitlyCopyable, Movable, Writable):
    """The theme's kinds of text: `title` for headings, `body` for running
    text and `label` for the text on widgets, such as a button's."""

    var title: TypeStyle
    var body: TypeStyle
    var label: TypeStyle

    def __init__(out self):
        self.title = TypeStyle(22, FontWeight.REGULAR, None)
        self.body = TypeStyle(16, FontWeight.REGULAR, None)
        self.label = TypeStyle(14, FontWeight.MEDIUM, None)


@fieldwise_init
struct CornerRadii(Copyable, ImplicitlyCopyable, Movable, Writable):
    """How round the theme's corners are, from `small`, such as a checkbox's,
    to `large`, such as a panel's."""

    var small: Float64
    var medium: Float64
    var large: Float64

    def __init__(out self):
        self.small = 4
        self.medium = 12
        self.large = 16


@fieldwise_init
struct Spacing(Copyable, ImplicitlyCopyable, Movable, Writable):
    """The theme's gaps, from `small`, between a label and its widget, to
    `large`, between groups of widgets."""

    var small: Float64
    var medium: Float64
    var large: Float64

    def __init__(out self):
        self.small = 4
        self.medium = 8
        self.large = 16


@fieldwise_init
struct StateLayers(Copyable, ImplicitlyCopyable, Movable, Writable):
    """How strongly a widget shows its state.

    A hovered, focused, pressed or dragged widget moves its OKLCH lightness
    by that step towards its text colour: 0.09 is a clear but quiet change,
    and the same step looks like the same change on any colour. A disabled
    widget instead fades, its content to `disabled_content` of its opacity
    and its fill to `disabled_container`.
    """

    var hovered: Float64
    var focused: Float64
    var pressed: Float64
    var dragged: Float64
    var disabled_content: Float64
    var disabled_container: Float64

    def __init__(out self):
        self.hovered = 0.09
        self.focused = 0.09
        self.pressed = 0.16
        self.dragged = 0.16
        self.disabled_content = 0.38
        self.disabled_container = 0.12


@fieldwise_init
struct FocusRing(Copyable, ImplicitlyCopyable, Movable, Writable):
    """The ring drawn around a widget focused from the keyboard, a gamepad
    or `take_focus`: its `thickness`, the `gap` between it and the widget,
    and its `color`, the scheme's `secondary` unless given. It follows the
    widget's shape, its corners rounded by the widget's own radius grown by
    the gap."""

    var thickness: Float64
    var gap: Float64
    var color: Optional[Color]

    def __init__(out self):
        self.thickness = 3
        self.gap = 2
        self.color = None


@fieldwise_init
struct Theme(Copyable, ImplicitlyCopyable, Movable, Writable):
    """The design tokens every widget draws from: colours, kinds of text,
    corner radii, gaps, state layers and the focus ring. A widget's look
    is worked out from these when it is drawn, so changing a token changes
    every widget that uses it.

    ```mojo
    # In `create`, building the `ui` field:
    var ui = UI(Theme.dark(primary=Color.ORANGE))
    ```
    """

    var colors: ColorScheme
    var typography: Typography
    var corner_radii: CornerRadii
    var spacing: Spacing
    var state_layers: StateLayers
    var focus_ring: FocusRing

    @staticmethod
    def light(
        *,
        primary: Optional[Color] = None,
        on_primary: Optional[Color] = None,
        secondary: Optional[Color] = None,
        on_secondary: Optional[Color] = None,
        tertiary: Optional[Color] = None,
        on_tertiary: Optional[Color] = None,
        error: Optional[Color] = None,
        on_error: Optional[Color] = None,
        surface: Optional[Color] = None,
        on_surface: Optional[Color] = None,
    ) -> Theme:
        """A theme of dark colours on a light background, with the colours
        given replacing its own.

        A colour given also changes its container to a quieter mix of it
        with the surface, and a colour given without its `on_` partner gets
        black or white, whichever reads better on it. So this is enough to
        make the buttons orange:

        ```mojo
        # In `create`, building the `ui` field:
        var ui = UI(Theme.light(primary=Color.ORANGE))
        ```
        """
        var colors = ColorScheme.light()
        colors._override(
            primary,
            on_primary,
            secondary,
            on_secondary,
            tertiary,
            on_tertiary,
            error,
            on_error,
            surface,
            on_surface,
        )
        return Theme._with_colors(colors)

    @staticmethod
    def dark(
        *,
        primary: Optional[Color] = None,
        on_primary: Optional[Color] = None,
        secondary: Optional[Color] = None,
        on_secondary: Optional[Color] = None,
        tertiary: Optional[Color] = None,
        on_tertiary: Optional[Color] = None,
        error: Optional[Color] = None,
        on_error: Optional[Color] = None,
        surface: Optional[Color] = None,
        on_surface: Optional[Color] = None,
    ) -> Theme:
        """A theme of light colours on a dark background, with the colours
        given replacing its own, as `Theme.light` does."""
        var colors = ColorScheme.dark()
        colors._override(
            primary,
            on_primary,
            secondary,
            on_secondary,
            tertiary,
            on_tertiary,
            error,
            on_error,
            surface,
            on_surface,
        )
        return Theme._with_colors(colors)

    @staticmethod
    def _with_colors(colors: ColorScheme) -> Theme:
        return Theme(
            colors=colors,
            typography=Typography(),
            corner_radii=CornerRadii(),
            spacing=Spacing(),
            state_layers=StateLayers(),
            focus_ring=FocusRing(),
        )
