comptime _MAX_LENGTHS = 8
"""The most lengths a pattern holds: four on/off pairs."""

comptime _EXPLICIT = 0
comptime _DASHED = 1
comptime _DOTTED = 2


struct StrokeDash(Copyable, Equatable, ImplicitlyCopyable, Movable, Writable):
    """How a stroke is broken into dashes along its length.

    | Value | Stroke |
    |---|---|
    | `SOLID` | Unbroken (the default) |
    | `DASHED` | Dashes 3 thicknesses long, 2 apart |
    | `DOTTED` | Round dots as wide as the stroke, 2 thicknesses apart |
    | `StrokeDash(on, off)` | Dashes `on` long, `off` apart |
    | `StrokeDash(on, off, on, off, ...)` | Up to four on/off pairs, repeated |

    **A preset is a look; a constructor is exact control.** The presets
    scale with the stroke's thickness, so they suit any stroke as they are.
    A constructor's lengths are world units, scaled by autoscale, the
    camera and the transform as the thickness is, and keep their spacing
    whatever the thickness. A dot is a dash of no length: `DOTTED` is
    always round, while `StrokeDash(0, 8)` takes `stroke_cap`, so it draws
    dots under `ROUND`, squares under `SQUARE` and nothing under `BUTT`.

    ```mojo
    canvas.stroke_dash(StrokeDash.DASHED)
    with canvas.style(stroke_dash=StrokeDash(12, 4, 2, 4)):  # dash-dot
        canvas.circle((0, 0), 80)
    ```

    **Where it starts.** A line starts at its start, a curve at its first
    point, a polygon or triangle at its first vertex, all in their own
    order. A rectangle starts at its top-left corner and a circle or
    ellipse at its right-most point, both running counter-clockwise. A
    sector starts at its tip, out along its start radius. `offset` starts
    the pattern that far into itself, so raising it every frame marches the
    dashes backwards along the stroke (`with_offset`). A closed outline
    doesn't stretch the pattern to fit: where it comes back round, a dash
    can meet a shorter one.

    **Every dash is a stroke of its own:** `stroke_cap` finishes both its
    ends, a region's dashes included, and a dash round a corner is mitred
    as a solid stroke is. Dashes whose caps reach into each other overlap
    there, which a translucent stroke shows. Lengths are measured along the
    middle of the stroke, after `stroke_alignment` has placed it. The fill
    still meets the stroke's inner edge, so a gap shows what is behind the
    shape; `StrokeAlign.OUTSIDE` puts the fill under the gaps instead.

    Set with `canvas.stroke_dash(dash)`, `Style(stroke_dash=)` or
    `canvas.style(stroke_dash=)`; like all style it resets each frame.
    """

    var _lengths: SIMD[DType.float64, _MAX_LENGTHS]
    var _count: Int
    var _kind: Int
    var _offset: Float64

    comptime SOLID = StrokeDash(_kind=_EXPLICIT)
    comptime DASHED = StrokeDash(_kind=_DASHED)
    comptime DOTTED = StrokeDash(_kind=_DOTTED)

    def __init__(out self, on: Float64, off: Float64, *, offset: Float64 = 0):
        """Dashes `on` world units long, `off` apart, starting `offset` into
        the pattern. A negative length counts as none."""
        self._lengths = SIMD[DType.float64, _MAX_LENGTHS](0)
        self._lengths[0] = max(on, 0.0)
        self._lengths[1] = max(off, 0.0)
        self._count = 2
        self._kind = _EXPLICIT
        self._offset = offset

    def __init__(out self, *lengths: Float64, offset: Float64 = 0) raises:
        """The pattern `on, off, on, off, ...`, in world units, repeated
        along the stroke and starting `offset` into it. A negative length
        counts as none.

        Raises unless `lengths` is whole on/off pairs, at most four of them.
        """
        if len(lengths) % 2 != 0:
            raise Error(
                (
                    "StrokeDash takes on/off pairs, so an even number of"
                    " lengths; got "
                ),
                len(lengths),
            )
        if len(lengths) > _MAX_LENGTHS:
            raise Error(
                "StrokeDash takes at most ",
                _MAX_LENGTHS // 2,
                " on/off pairs; got ",
                len(lengths) // 2,
            )
        self._lengths = SIMD[DType.float64, _MAX_LENGTHS](0)
        for i in range(len(lengths)):
            self._lengths[i] = max(lengths[i], 0.0)
        self._count = len(lengths)
        self._kind = _EXPLICIT
        self._offset = offset

    def __init__(out self, *, _kind: Int, _offset: Float64 = 0):
        """A preset, or `SOLID` (an explicit pattern of no lengths)."""
        self._lengths = SIMD[DType.float64, _MAX_LENGTHS](0)
        self._count = 0
        self._kind = _kind
        self._offset = _offset

    def with_offset(self, offset: Float64) -> StrokeDash:
        """This pattern starting `offset` world units into itself, for
        marching dashes: `dash.with_offset(context.time.elapsed * 20)`."""
        var out = self
        out._offset = offset
        return out

    def offset(self) -> Float64:
        """How far into the pattern the stroke starts, in world units."""
        return self._offset

    def __eq__(self, other: StrokeDash) -> Bool:
        return (
            self._kind == other._kind
            and self._count == other._count
            and self._offset == other._offset
            and self._lengths == other._lengths
        )

    def __ne__(self, other: StrokeDash) -> Bool:
        return not self == other

    def write_to[W: Writer](self, mut writer: W):
        if self._kind == _DASHED:
            writer.write("StrokeDash.DASHED")
        elif self._kind == _DOTTED:
            writer.write("StrokeDash.DOTTED")
        elif self._count == 0:
            writer.write("StrokeDash.SOLID")
        else:
            writer.write("StrokeDash(")
            for i in range(self._count):
                if i > 0:
                    writer.write(", ")
                writer.write(self._lengths[i])
            if self._offset != 0.0:
                writer.write(", offset=", self._offset)
            writer.write(")")
            return
        if self._offset != 0.0:
            writer.write(".with_offset(", self._offset, ")")

    def _is_solid(self) -> Bool:
        """Whether this draws an unbroken stroke: `SOLID`, or a pattern of
        no length at all, which could never repeat."""
        if self._kind != _EXPLICIT:
            return False
        var total = 0.0
        for i in range(self._count):
            total += self._lengths[i]
        return total <= 0.0

    def _is_dotted(self) -> Bool:
        """Whether this is `DOTTED`, whose dots are round whatever the cap."""
        return self._kind == _DOTTED

    def _resolved(self, thickness: Float64) -> StrokeDash:
        """This pattern for a stroke `thickness` world units thick, as
        explicit lengths: a preset scaled by the thickness, a constructor's
        lengths as they are. Resolved when a command is recorded, so a
        shadow that thickens the stroke keeps the shape's dashes."""
        if self._kind == _EXPLICIT:
            return self
        var out = StrokeDash(_kind=_EXPLICIT, _offset=self._offset)
        if self._kind == _DASHED:
            out._lengths[0] = 3.0 * thickness
            out._lengths[1] = 2.0 * thickness
        else:
            out._lengths[0] = 0.0
            out._lengths[1] = 2.0 * thickness
        out._count = 2
        return out

    def _length(self, i: Int) -> Float64:
        """The `i`th length of an explicit pattern, `on` at even `i`."""
        return self._lengths[i]

    def _len(self) -> Int:
        """How many lengths an explicit pattern holds; 0 for `SOLID`."""
        return self._count
