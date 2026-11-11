"""The mouse cursor over the window: `context.cursor`'s value.

A selector with a type of its own, compared with `==`, like `WindowMode`:
the constructor is not `@implicit`, so a bare number never passes for a
cursor. Each is the platform's own system cursor, so it looks native on
every desktop.

`ARROW` is the default. `HIDDEN` hides the cursor over the window, like
Processing's `noCursor()`; any other value shows it again. The resize
cursors are named by the line they run along, read left to right with y
up: `RESIZE_DIAGONAL_RISING` is `/`, `RESIZE_DIAGONAL_FALLING` is `\\`.
"""


struct Cursor(Copyable, Equatable, ImplicitlyCopyable, Movable, Writable):
    var value: Int

    comptime ARROW = Cursor(0)
    """The ordinary pointer."""
    comptime CROSSHAIR = Cursor(1)
    """Precise aiming or drawing: Processing's `CROSS`."""
    comptime HAND = Cursor(2)
    """Something clickable, like a link."""
    comptime TEXT = Cursor(3)
    """Text that can be edited or selected: an I-beam."""
    comptime WAIT = Cursor(4)
    """Busy, not taking input."""
    comptime PROGRESS = Cursor(5)
    """Busy, but still taking input: usually an arrow with a spinner."""
    comptime MOVE = Cursor(6)
    """Something that can be dragged in any direction."""
    comptime NOT_ALLOWED = Cursor(7)
    """An action that can't be done here."""
    comptime RESIZE_HORIZONTAL = Cursor(8)
    comptime RESIZE_VERTICAL = Cursor(9)
    comptime RESIZE_DIAGONAL_RISING = Cursor(10)
    comptime RESIZE_DIAGONAL_FALLING = Cursor(11)
    comptime HIDDEN = Cursor(12)
    """No cursor over the window: Processing's `noCursor()`."""

    def __init__(out self, value: Int):
        self.value = value

    def __eq__(self, other: Cursor) -> Bool:
        return self.value == other.value

    def __ne__(self, other: Cursor) -> Bool:
        return self.value != other.value

    def write_to[W: Writer](self, mut writer: W):
        comptime for i in range(len(_NAMED_CURSORS)):
            comptime entry = _NAMED_CURSORS[i]
            if self == entry[0]:
                writer.write("Cursor.", entry[1])
                return
        writer.write("Cursor(", self.value, ")")

    @staticmethod
    def from_name(name: String) -> Optional[Cursor]:
        """The cursor whose constant is `name`, case folded: `"hand"`, `"crosshair"`, `"hidden"`. `None`
        for an unknown name — for a binding read from a file, where a
        misspelled constant would have failed to compile.
        """
        var upper = name.upper()
        comptime for i in range(len(_NAMED_CURSORS)):
            comptime entry = _NAMED_CURSORS[i]
            if upper == entry[1]:
                return entry[0]
        return None


# Every `Cursor` constant with its name, for printing and `from_name`.
comptime _NAMED_CURSORS = [
    (Cursor.ARROW, StaticString("ARROW")),
    (Cursor.CROSSHAIR, StaticString("CROSSHAIR")),
    (Cursor.HAND, StaticString("HAND")),
    (Cursor.TEXT, StaticString("TEXT")),
    (Cursor.WAIT, StaticString("WAIT")),
    (Cursor.PROGRESS, StaticString("PROGRESS")),
    (Cursor.MOVE, StaticString("MOVE")),
    (Cursor.NOT_ALLOWED, StaticString("NOT_ALLOWED")),
    (Cursor.RESIZE_HORIZONTAL, StaticString("RESIZE_HORIZONTAL")),
    (Cursor.RESIZE_VERTICAL, StaticString("RESIZE_VERTICAL")),
    (Cursor.RESIZE_DIAGONAL_RISING, StaticString("RESIZE_DIAGONAL_RISING")),
    (Cursor.RESIZE_DIAGONAL_FALLING, StaticString("RESIZE_DIAGONAL_FALLING")),
    (Cursor.HIDDEN, StaticString("HIDDEN")),
]
