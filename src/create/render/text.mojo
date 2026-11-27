from std.collections import Optional

from create.math.point import Point
from create.math.vector import Vector
from create.math import OptionalNumber
from .canvas import Canvas
from .drawable import Drawable
from ._text import NO_WRAP


struct Text(Copyable, Drawable, Equatable, Movable, Writable):
    """A piece of text placed in the world, to draw with `canvas.draw`.

    `canvas.draw(Text("Score", (0, 200)))` draws what
    `canvas.text("Score", (0, 200))` draws: the text at `position`, anchored
    by the style's `text_alignment`, in its font, size and text colour. As a
    value it can be kept in a field and be one part of a `Drawable` of your
    own, beside the shapes it is drawn with:

    ```mojo
    @fieldwise_init
    struct Badge(Drawable):
        var plate: Rectangle
        var text: Text

        def draw_to(self, mut canvas: Canvas):
            canvas.draw(self.plate)
            with canvas.style(text_color=Color.WHITE):
                canvas.draw(self.text)
    ```

    Given a `width`, the text wraps onto as many lines as keep each at most
    that wide, as `canvas.text(text, position, width)` does.

    Its size depends on the font it is drawn in, which belongs to the
    style, so it has no `bounds` of its own: `canvas.bounds(text)` measures
    it in the style it is drawn in.
    """

    var value: String
    """The text drawn."""
    var position: Point
    """Where it is anchored, by the style's `text_alignment`."""
    var width: Optional[Float64]
    """The width it wraps at, or `None` to break only at newlines."""

    def __init__(
        out self,
        value: String,
        position: Point,
        width: OptionalNumber = None,
    ):
        self.value = value
        self.position = position
        self.width = width._value

    def __eq__(self, other: Self) -> Bool:
        return (
            self.value == other.value
            and self.position == other.position
            and self.width == other.width
        )

    def write_to[W: Writer](self, mut writer: W):
        writer.write('Text(value="')
        for character in self.value.codepoint_slices():
            if character == '"':
                writer.write('\\"')
            elif character == "\\":
                writer.write("\\\\")
            elif character == "\n":
                writer.write("\\n")
            else:
                writer.write(character)
        writer.write('"')
        writer.write(", position=", self.position)
        if self.width:
            writer.write(", width=", self.width.value())
        writer.write(")")

    def move_to(self, position: Point) -> Self:
        """The text anchored at `position` instead; this one is unchanged."""
        var moved = self.copy()
        moved.position = position
        return moved^

    def translate(self, delta: Vector) -> Self:
        """The text moved by `delta`; this one is unchanged."""
        var moved = self.copy()
        moved.position = moved.position + delta
        return moved^

    def draw_to(self, mut canvas: Canvas):
        canvas._text(self.value, self.position, self._wrap())

    def _wrap(self) -> Float64:
        """The width it wraps at, as the text layout takes it: `NO_WRAP`
        when it has none."""
        if self.width:
            return max(self.width.value(), 0.0)
        return NO_WRAP
