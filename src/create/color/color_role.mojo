"""`ColorRole`, a colour named by what it is for in a `ColorScheme`."""


struct ColorRole(Copyable, Equatable, ImplicitlyCopyable, Movable, Writable):
    """A colour named by what it is for, such as `ColorRole.PRIMARY`, rather
    than by its channels: the colour scheme in use decides which colour it is.

    A `Style` takes a role wherever it takes a colour, so a look can be
    written once and follow the scheme:

    ```mojo
    # In `create`, building the `banner` field: a strip in the scheme's
    # primary colour, whichever scheme is in use.
    var banner = Style(
        fill=ColorRole.PRIMARY, text_color=ColorRole.ON_PRIMARY
    )
    ```

    The role is turned into a colour when the style is applied: by the
    canvas's colours (`canvas.colors`) when it is drawn, and by a `UI`'s
    colours when a widget is styled with it. There is a role for each of
    `ColorScheme`'s colours, named as its field is, in capitals:
    `ColorRole.SURFACE_CONTAINER` is `scheme.surface_container`.
    """

    var value: Int

    comptime PRIMARY = ColorRole(0)
    comptime ON_PRIMARY = ColorRole(1)
    comptime PRIMARY_CONTAINER = ColorRole(2)
    comptime ON_PRIMARY_CONTAINER = ColorRole(3)
    comptime SECONDARY = ColorRole(4)
    comptime ON_SECONDARY = ColorRole(5)
    comptime SECONDARY_CONTAINER = ColorRole(6)
    comptime ON_SECONDARY_CONTAINER = ColorRole(7)
    comptime TERTIARY = ColorRole(8)
    comptime ON_TERTIARY = ColorRole(9)
    comptime TERTIARY_CONTAINER = ColorRole(10)
    comptime ON_TERTIARY_CONTAINER = ColorRole(11)
    comptime ERROR = ColorRole(12)
    comptime ON_ERROR = ColorRole(13)
    comptime ERROR_CONTAINER = ColorRole(14)
    comptime ON_ERROR_CONTAINER = ColorRole(15)
    comptime SURFACE = ColorRole(16)
    comptime SURFACE_DIM = ColorRole(17)
    comptime SURFACE_BRIGHT = ColorRole(18)
    comptime ON_SURFACE = ColorRole(19)
    comptime ON_SURFACE_VARIANT = ColorRole(20)
    comptime SURFACE_CONTAINER_LOWEST = ColorRole(21)
    comptime SURFACE_CONTAINER_LOW = ColorRole(22)
    comptime SURFACE_CONTAINER = ColorRole(23)
    comptime SURFACE_CONTAINER_HIGH = ColorRole(24)
    comptime SURFACE_CONTAINER_HIGHEST = ColorRole(25)
    comptime OUTLINE = ColorRole(26)
    comptime OUTLINE_VARIANT = ColorRole(27)
    comptime BACKGROUND = ColorRole(28)
    comptime ON_BACKGROUND = ColorRole(29)

    def __init__(out self, value: Int):
        self.value = value

    def __eq__(self, other: ColorRole) -> Bool:
        return self.value == other.value

    def __ne__(self, other: ColorRole) -> Bool:
        return self.value != other.value

    def write_to[W: Writer](self, mut writer: W):
        if self.value == 0:
            writer.write("ColorRole.PRIMARY")
        elif self.value == 1:
            writer.write("ColorRole.ON_PRIMARY")
        elif self.value == 2:
            writer.write("ColorRole.PRIMARY_CONTAINER")
        elif self.value == 3:
            writer.write("ColorRole.ON_PRIMARY_CONTAINER")
        elif self.value == 4:
            writer.write("ColorRole.SECONDARY")
        elif self.value == 5:
            writer.write("ColorRole.ON_SECONDARY")
        elif self.value == 6:
            writer.write("ColorRole.SECONDARY_CONTAINER")
        elif self.value == 7:
            writer.write("ColorRole.ON_SECONDARY_CONTAINER")
        elif self.value == 8:
            writer.write("ColorRole.TERTIARY")
        elif self.value == 9:
            writer.write("ColorRole.ON_TERTIARY")
        elif self.value == 10:
            writer.write("ColorRole.TERTIARY_CONTAINER")
        elif self.value == 11:
            writer.write("ColorRole.ON_TERTIARY_CONTAINER")
        elif self.value == 12:
            writer.write("ColorRole.ERROR")
        elif self.value == 13:
            writer.write("ColorRole.ON_ERROR")
        elif self.value == 14:
            writer.write("ColorRole.ERROR_CONTAINER")
        elif self.value == 15:
            writer.write("ColorRole.ON_ERROR_CONTAINER")
        elif self.value == 16:
            writer.write("ColorRole.SURFACE")
        elif self.value == 17:
            writer.write("ColorRole.SURFACE_DIM")
        elif self.value == 18:
            writer.write("ColorRole.SURFACE_BRIGHT")
        elif self.value == 19:
            writer.write("ColorRole.ON_SURFACE")
        elif self.value == 20:
            writer.write("ColorRole.ON_SURFACE_VARIANT")
        elif self.value == 21:
            writer.write("ColorRole.SURFACE_CONTAINER_LOWEST")
        elif self.value == 22:
            writer.write("ColorRole.SURFACE_CONTAINER_LOW")
        elif self.value == 23:
            writer.write("ColorRole.SURFACE_CONTAINER")
        elif self.value == 24:
            writer.write("ColorRole.SURFACE_CONTAINER_HIGH")
        elif self.value == 25:
            writer.write("ColorRole.SURFACE_CONTAINER_HIGHEST")
        elif self.value == 26:
            writer.write("ColorRole.OUTLINE")
        elif self.value == 27:
            writer.write("ColorRole.OUTLINE_VARIANT")
        elif self.value == 28:
            writer.write("ColorRole.BACKGROUND")
        elif self.value == 29:
            writer.write("ColorRole.ON_BACKGROUND")
        else:
            writer.write("ColorRole(", self.value, ")")
