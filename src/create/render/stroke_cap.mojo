struct StrokeCap(Copyable, Equatable, ImplicitlyCopyable, Movable, Writable):
    """How the two open ends of a stroked line or curve are finished.

    | Cap | End |
    |---|---|
    | `BUTT` | Square, flush with the end point (the default) |
    | `ROUND` | A half disc, its diameter the stroke thickness |
    | `SQUARE` | Square, pushed out past the end point by half the thickness |

    Only open ends have caps: a `Line`, a `Bezier`, an `Arc` short of a whole
    turn, and an open `Spline`. A closed curve and the stroke of a region
    (rectangle, circle, triangle, sector, polygon) have none, unless the
    stroke is dashed (`StrokeDash`): then each dash has two. A line of no
    length draws a dot under `ROUND`, a square lined up with the local axes
    under `SQUARE`, and nothing under `BUTT`.

    Set with `canvas.stroke_cap(cap)`, `Style(stroke_cap=)` or
    `canvas.style(stroke_cap=)`; like all style it resets each frame. A
    type of its own, so a bare number never passes for one.
    """

    var value: Int

    comptime BUTT = StrokeCap(0)
    comptime ROUND = StrokeCap(1)
    comptime SQUARE = StrokeCap(2)

    def __init__(out self, value: Int):
        self.value = value

    def __eq__(self, other: StrokeCap) -> Bool:
        return self.value == other.value

    def __ne__(self, other: StrokeCap) -> Bool:
        return self.value != other.value

    def write_to[W: Writer](self, mut writer: W):
        if self == StrokeCap.BUTT:
            writer.write("StrokeCap.BUTT")
        elif self == StrokeCap.ROUND:
            writer.write("StrokeCap.ROUND")
        elif self == StrokeCap.SQUARE:
            writer.write("StrokeCap.SQUARE")
        else:
            writer.write("StrokeCap(", self.value, ")")
