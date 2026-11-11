struct MouseButton(Copyable, Equatable, ImplicitlyCopyable, Movable, Writable):
    """A mouse button, for `Mouse.down`/`pressed`/`released`.

    Matches SDL's own button numbering, not named after it: `BACK`/`FORWARD`
    are the side thumb buttons (SDL's X1/X2) — named for what a mouse driver
    or browser calls them, not SDL's internal label, since nobody looks at
    their mouse and thinks "that's my X1 button."

    A wrapped button number rather than a bare `Int`, like `Key`, so a stray
    number cannot be passed where a button is expected — the numbering is not
    what anyone guesses (`RIGHT` is 3, not 2). `MouseButton(n)` names a
    button past `FORWARD` on a mouse that has one.

    `NONE` is no button, what `Mouse.button` reads before any press;
    it is never down.
    """

    var value: Int

    comptime NONE = MouseButton(0)
    comptime LEFT = MouseButton(1)
    comptime MIDDLE = MouseButton(2)
    comptime RIGHT = MouseButton(3)
    comptime BACK = MouseButton(4)
    comptime FORWARD = MouseButton(5)

    def __init__(out self, value: Int):
        self.value = value

    def __eq__(self, other: MouseButton) -> Bool:
        return self.value == other.value

    def __ne__(self, other: MouseButton) -> Bool:
        return self.value != other.value

    def write_to[W: Writer](self, mut writer: W):
        comptime for i in range(len(_NAMED_MOUSE_BUTTONS)):
            comptime entry = _NAMED_MOUSE_BUTTONS[i]
            if self == entry[0]:
                writer.write("MouseButton.", entry[1])
                return
        writer.write("MouseButton(", self.value, ")")

    @staticmethod
    def from_name(name: String) -> Optional[MouseButton]:
        """The button whose constant is `name`, case folded: `"left"`, `"right"`, `"back"`. `None`
        for an unknown name — for a binding read from a file, where a
        misspelled constant would have failed to compile.
        """
        var upper = name.upper()
        comptime for i in range(len(_NAMED_MOUSE_BUTTONS)):
            comptime entry = _NAMED_MOUSE_BUTTONS[i]
            if upper == entry[1]:
                return entry[0]
        return None

    def _bit(self) -> Int:
        """This button's bit in `Mouse`'s button masks; 0, never set, for
        `NONE` and for a number no mask can hold."""
        if 1 <= self.value < 64:
            return 1 << self.value
        return 0


# Every `MouseButton` constant with its name, for printing and `from_name`.
comptime _NAMED_MOUSE_BUTTONS = [
    (MouseButton.NONE, StaticString("NONE")),
    (MouseButton.LEFT, StaticString("LEFT")),
    (MouseButton.MIDDLE, StaticString("MIDDLE")),
    (MouseButton.RIGHT, StaticString("RIGHT")),
    (MouseButton.BACK, StaticString("BACK")),
    (MouseButton.FORWARD, StaticString("FORWARD")),
]
