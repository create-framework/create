"""`ColorScheme`, the colours widgets are drawn in."""

from create.color import Color


@fieldwise_init
struct ColorScheme(Copyable, ImplicitlyCopyable, Movable, Writable):
    """The colours widgets are drawn in, as pairs of roles: each colour a
    widget is filled with, and the `on_` colour for text and icons drawn on
    it, chosen to read well together. A program gives its scheme to a `UI`
    with `ui.colors(scheme)`, and draws its own things in it too, such as
    `canvas.background(scheme.background)`.

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
    ) -> Self:
        """Dark colours on a light background, with the colours given
        replacing its own.

        A colour given also changes its container to a quieter mix of it
        with the surface, and a colour given without its `on_` partner gets
        black or white, whichever reads better on it. So this is enough to
        make the buttons orange:

        ```mojo
        # In `create`, building the `colors` field:
        var colors = ColorScheme.light(primary=Color.ORANGE)
        ```
        """
        var colors = ColorScheme(
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
        return colors

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
    ) -> Self:
        """Light colours on a dark background, with the colours given
        replacing its own, as `ColorScheme.light` does."""
        var colors = ColorScheme(
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
        return colors

    @staticmethod
    def from_seed(
        seed: Color,
        *,
        dark: Bool = False,
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
    ) -> Self:
        """The colours worked out from one colour, such as a game's own,
        as Material's dynamic colour does: light unless `dark`.

        The seed's hue gives five families of colour: the primary, a greyer
        secondary, a tertiary turned 60 degrees round the colour wheel,
        near-greys for the surfaces, and a fixed red for errors. Each role
        then takes Material's fixed tone, a lightness that looks the same in
        every hue: in the light scheme `primary` is tone 40 and `on_primary`
        100, `primary_container` 90 and `on_primary_container` 10. The gap
        between two paired roles keeps them readable together, whatever the
        seed. A grey seed gives grey colours.

        The colours given replace those worked out, as in `light` and `dark`.

        ```mojo
        # In `create`, building the `colors` field:
        var colors = ColorScheme.from_seed(Color.hex(0xE07A2E))  # orange
        var warning = ColorScheme.from_seed(  # the same, with a yellow error
            Color.hex(0xE07A2E), error=Color.hex(0xE0B000)
        )
        ```
        """
        var at = seed.to_oklch()
        var hue = at[2]
        # A seed with some colour gets a primary vivid enough to read as
        # that colour; a grey seed stays grey.
        var chroma = 0.0 if at[1] < 0.03 else min(max(at[1], 0.1), 0.16)
        var primary_palette = _Palette(hue, chroma)
        var secondary_palette = _Palette(hue, chroma / 3)
        var tertiary_palette = _Palette(hue + 60, chroma * 0.6)
        var neutral = _Palette(hue, min(chroma / 12, 0.012))
        var variant = _Palette(hue, min(chroma / 6, 0.025))
        var error_palette = _Palette(25, 0.17)
        var colors: ColorScheme
        if dark:
            colors = ColorScheme(
                primary=primary_palette.tone(80),
                on_primary=primary_palette.tone(20),
                primary_container=primary_palette.tone(30),
                on_primary_container=primary_palette.tone(90),
                secondary=secondary_palette.tone(80),
                on_secondary=secondary_palette.tone(20),
                secondary_container=secondary_palette.tone(30),
                on_secondary_container=secondary_palette.tone(90),
                tertiary=tertiary_palette.tone(80),
                on_tertiary=tertiary_palette.tone(20),
                tertiary_container=tertiary_palette.tone(30),
                on_tertiary_container=tertiary_palette.tone(90),
                error=error_palette.tone(80),
                on_error=error_palette.tone(20),
                error_container=error_palette.tone(30),
                on_error_container=error_palette.tone(90),
                surface=neutral.tone(6),
                surface_dim=neutral.tone(6),
                surface_bright=neutral.tone(24),
                on_surface=neutral.tone(90),
                on_surface_variant=variant.tone(80),
                surface_container_lowest=neutral.tone(4),
                surface_container_low=neutral.tone(10),
                surface_container=neutral.tone(12),
                surface_container_high=neutral.tone(17),
                surface_container_highest=neutral.tone(22),
                outline=variant.tone(60),
                outline_variant=variant.tone(30),
                background=neutral.tone(6),
                on_background=neutral.tone(90),
            )
        else:
            colors = ColorScheme(
                primary=primary_palette.tone(40),
                on_primary=primary_palette.tone(100),
                primary_container=primary_palette.tone(90),
                on_primary_container=primary_palette.tone(10),
                secondary=secondary_palette.tone(40),
                on_secondary=secondary_palette.tone(100),
                secondary_container=secondary_palette.tone(90),
                on_secondary_container=secondary_palette.tone(10),
                tertiary=tertiary_palette.tone(40),
                on_tertiary=tertiary_palette.tone(100),
                tertiary_container=tertiary_palette.tone(90),
                on_tertiary_container=tertiary_palette.tone(10),
                error=error_palette.tone(40),
                on_error=error_palette.tone(100),
                error_container=error_palette.tone(90),
                on_error_container=error_palette.tone(10),
                surface=neutral.tone(98),
                surface_dim=neutral.tone(87),
                surface_bright=neutral.tone(98),
                on_surface=neutral.tone(10),
                on_surface_variant=variant.tone(30),
                surface_container_lowest=neutral.tone(100),
                surface_container_low=neutral.tone(96),
                surface_container=neutral.tone(94),
                surface_container_high=neutral.tone(92),
                surface_container_highest=neutral.tone(90),
                outline=variant.tone(50),
                outline_variant=variant.tone(80),
                background=neutral.tone(98),
                on_background=neutral.tone(10),
            )
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
        return colors

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
struct _Palette(Copyable, ImplicitlyCopyable, Movable):
    """One family of colour for `from_seed`: a hue and a chroma, from which
    a colour at any tone, its lightness from 0 to 100, is made."""

    var hue: Float64
    var chroma: Float64

    def tone(self, tone: Float64) -> Color:
        """This family's colour at `tone`, Material's measure of lightness:
        0 black, 100 white, and 50 the grey halfway between to the eye
        (CIELAB lightness). The tone fixes how much light the colour gives
        off, so two tones far enough apart read together in any hue. Near
        the ends a screen can show little colour, so the chroma is lowered
        to fit there, keeping the tone."""
        # CIELAB lightness to luminance, and luminance to OKLCH lightness,
        # which for a grey is its cube root.
        var t = min(max(tone, 0.0), 100.0)
        var luminance = ((t + 16) / 116) ** 3 if t > 8 else t / 903.2963
        return Color.oklch(luminance ** (1.0 / 3.0), self.chroma, self.hue)
