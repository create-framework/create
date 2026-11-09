struct StrokeAlign(Copyable, Equatable, ImplicitlyCopyable, Movable, Writable):
    """Where a region's stroke sits against the shape's edge.

    | Alignment | Stroke |
    |---|---|
    | `INSIDE` | Within the shape, its outer edge on the shape's (the default) |
    | `CENTER` | Centred on the edge, half its thickness either side |
    | `OUTSIDE` | Around the shape, its inner edge on the shape's |

    The fill always meets the stroke's inner edge, so `OUTSIDE` leaves the
    fill the whole shape and `INSIDE` erodes it by the thickness. The
    default keeps what is drawn within what `contains`, `overlaps` and
    `clip` see. Only regions have an inside: a rectangle, circle, triangle,
    sector or polygon. Lines and curves are always stroked centred, and a
    self-crossing polygon's seams (edges running through its inside) stay
    centred too.

    Set with `canvas.stroke_alignment(alignment)`, `Style(stroke_alignment=)`
    or `canvas.style(stroke_alignment=)`; like all style it resets each
    frame. A type of its own, so a bare number never passes for one.
    """

    var value: Int

    comptime INSIDE = StrokeAlign(0)
    comptime CENTER = StrokeAlign(1)
    comptime OUTSIDE = StrokeAlign(2)

    def __init__(out self, value: Int):
        self.value = value

    def __eq__(self, other: StrokeAlign) -> Bool:
        return self.value == other.value

    def __ne__(self, other: StrokeAlign) -> Bool:
        return self.value != other.value

    def _offset_fraction(self) -> Float64:
        """How far out the stroke's outer edge lies past the shape's, as a
        fraction of the thickness: 0 inside, 0.5 centred, 1 outside."""
        if self == StrokeAlign.CENTER:
            return 0.5
        if self == StrokeAlign.OUTSIDE:
            return 1.0
        return 0.0

    def write_to[W: Writer](self, mut writer: W):
        if self == StrokeAlign.INSIDE:
            writer.write("StrokeAlign.INSIDE")
        elif self == StrokeAlign.CENTER:
            writer.write("StrokeAlign.CENTER")
        elif self == StrokeAlign.OUTSIDE:
            writer.write("StrokeAlign.OUTSIDE")
        else:
            writer.write("StrokeAlign(", self.value, ")")
