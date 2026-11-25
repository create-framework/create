# A type of its own, not an `Int`: `mode` sits ahead of `width`/`height` in
# `run`'s signature, where an `Int` would make `run("T", 800)` a silently
# valid mode. The constructor is not `@implicit` for the same reason. One
# value is exactly one mode, which independent bools could not guarantee.
struct WindowMode(Copyable, Equatable, ImplicitlyCopyable, Movable, Writable):
    """How the window presents itself: `run`'s `mode`, and
    `context.window_mode`'s value.

    `WINDOWED` is the default. Compare modes with `==`.
    """

    var value: Int

    comptime WINDOWED = WindowMode(0)
    """An ordinary decorated window of the design size."""
    comptime FULLSCREEN = WindowMode(1)
    """The whole display, with the design scaled onto it."""
    comptime BORDERLESS = WindowMode(2)
    """A window of the design size with no title bar or border."""
    comptime MAXIMIZED = WindowMode(3)
    """A decorated window filling the display's work area, with the design
    scaled onto it."""

    def __init__(out self, value: Int):
        self.value = value

    def __eq__(self, other: WindowMode) -> Bool:
        return self.value == other.value

    def __ne__(self, other: WindowMode) -> Bool:
        return self.value != other.value

    def write_to[W: Writer](self, mut writer: W):
        if self == WindowMode.WINDOWED:
            writer.write("WindowMode.WINDOWED")
        elif self == WindowMode.FULLSCREEN:
            writer.write("WindowMode.FULLSCREEN")
        elif self == WindowMode.BORDERLESS:
            writer.write("WindowMode.BORDERLESS")
        elif self == WindowMode.MAXIMIZED:
            writer.write("WindowMode.MAXIMIZED")
        else:
            writer.write("WindowMode(", self.value, ")")
