"""`ButtonVariant`: which of the theme's colours a button is drawn in."""


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
