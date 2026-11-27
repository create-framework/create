from create.color.color import Color
from create.math.number import Number


struct GradientStop(Copyable, Equatable, ImplicitlyCopyable, Movable, Writable):
    """A colour placed at a position along a `Gradient`, from 0 at its start
    to 1 at its end.

    A program writes one as a `(position, colour)` pair, and never names the
    type: `Gradient.linear([(0, Color.BLUE), (0.7, Color.PURPLE), (1,
    Color.ORANGE)])`. The position can be any number, so `0` and `1` need no
    `.0`.
    """

    var position: Float64
    var color: Color

    def __init__(out self, position: Number, color: Color):
        self.position = Float64(position)
        self.color = color

    @implicit
    def __init__(out self, stop: Tuple[Float64, Color]):
        self = GradientStop(stop[0], stop[1])

    @implicit
    def __init__(out self, stop: Tuple[Int, Color]):
        self = GradientStop(stop[0], stop[1])

    def __eq__(self, other: GradientStop) -> Bool:
        return self.position == other.position and self.color == other.color

    def write_to(self, mut writer: Some[Writer]):
        writer.write(
            "GradientStop(position=",
            self.position,
            ", color=",
            self.color,
            ")",
        )
