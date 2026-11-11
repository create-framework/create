"""Stroke geometry for curves, shared by both replays.

A curve is flattened and stroked in *device* space at replay, not at record
time, so it stays smooth however far a camera zooms in. Both backends fill
the same quads — the CPU through `fill_quad`, the GPU as vertices — which is what keeps them in parity.

A stroke's open ends are finished by its `StrokeCap`: a square cap lengthens
the end quads, a round cap is a convex half disc whose base is exactly the end
quad's edge, which the CPU fills with `fill_convex` (walking edges as
`fill_quad` does, so the shared edge composites once) and the GPU fans.

A blurred curve shadow is a mask rasterised from those same quads and blurred
(`bezier_shadow_mask`), which both backends composite; `quads_shadow_mask`
builds one from any device quads, which is how sectors and polygons cast theirs too.
Unlike an image's, it is not cached: a curve has no stable id to key it by,
so every blurred curve shadow costs one blur per frame.
"""

from std.math import ceil, cos, floor, sin, sqrt

from create.math import PI

from create.geometry.bezier import Bezier
from create.math.matrix import Matrix, _apply as mat_apply
from create.math.point2d import Point2D
from create.math.vector2d import Vector2D

from ._blur import BlurredMask, blur_alpha
from ._command import CurvesPayload, RenderCommand
from ._raster import fill_quad
from ._transform import stroke_thickness_px
from create.color.color import Color
from ._surface import MemorySurface
from .stroke_cap import StrokeCap

comptime _MIN_CIRCLE_SEGMENTS = 12
comptime _MAX_CIRCLE_SEGMENTS = 256


def circle_segments(radius_px: Float64) -> Int:
    """How many segments a circle of this device radius is worth.

    One segment per pixel of radius is far finer than the eye needs and still
    cheap; the floor keeps a tiny circle from becoming a triangle, and the cap
    keeps a huge one from flooding the batch.
    """
    if radius_px <= 0.0:
        return _MIN_CIRCLE_SEGMENTS
    return max(
        _MIN_CIRCLE_SEGMENTS, min(_MAX_CIRCLE_SEGMENTS, Int(ceil(radius_px)))
    )


comptime FLATTEN_TOLERANCE_PX = 0.25
"""How far, in device pixels, a flattened curve may stray from the true one:
well under the half-pixel that would move a pixel centre in or out."""

comptime MITER_LIMIT = 4.0
"""The furthest a mitred corner may reach, in half-thicknesses. A flattened
curve turns only slightly between segments, so the limit only bites at a
cusp, where the unclamped miter would shoot off towards infinity."""


def bezier_device_points(c: RenderCommand, m: Matrix[3, 3]) -> List[Point2D]:
    """`c`'s chain of curves (`c` a `CurvesPayload`) mapped by `m` and flattened
    to one polyline of device-space points, the point where one curve meets
    the next appearing once.

    The control points are mapped rather than the flattened points: a
    Bézier's shape survives an affine map, so each curve is flattened at the
    size it will actually be drawn.
    """
    ref controls = c.payload[CurvesPayload].points
    var mapped = List[Point2D](capacity=len(controls))
    for p in controls:
        mapped.append(mat_apply(m, p.x, p.y))
    var points = List[Point2D]()
    for i in range(0, len(mapped) - 3, 3):
        var part = Bezier(
            mapped[i], mapped[i + 1], mapped[i + 2], mapped[i + 3]
        ).flatten(FLATTEN_TOLERANCE_PX)
        var first = 0 if len(points) == 0 else 1
        for j in range(first, len(part)):
            points.append(part[j])
    return points^


def device_x_axis(m: Matrix[3, 3]) -> Vector2D:
    """The local x axis as `m` maps it, the way a `SQUARE` dot is turned."""
    var origin = mat_apply(m, 0.0, 0.0)
    var x = mat_apply(m, 1.0, 0.0)
    return Vector2D(x[0] - origin[0], x[1] - origin[1])


def stroke_segment(
    a: Point2D, b: Point2D, width: Float64, cap: StrokeCap = StrokeCap.BUTT
) -> Optional[Array[Point2D, 4]]:
    """The one quad of `stroke_pieces([a, b], width, cap)`, without a list:
    `a`-`b` pushed out by half the width along its normal, left edge first,
    and lengthened by half the width at both ends under `SQUARE`. None when
    it has no width or no length, or `cap` is `ROUND` (whose half discs are
    more than a quad). Stroking lines is hot, so this allocates nothing; the
    arithmetic is the general path's."""
    var d = b - a
    if width <= 0.0 or (d.x == 0.0 and d.y == 0.0) or cap == StrokeCap.ROUND:
        return None
    var start = a
    var end = b
    if cap == StrokeCap.SQUARE:
        start = _pushed_out(a, b, width / 2.0)
        end = _pushed_out(b, a, width / 2.0)
        d = end - start
    var offset = Vector2D(-d.y, d.x) / d.magnitude() * (width / 2.0)
    var corners: Array[Point2D, 4] = [
        start + offset,
        end + offset,
        end - offset,
        start - offset,
    ]
    return corners^


struct StrokePieces(Movable):
    """A stroke as convex device pieces: `quads`, four corners each as
    `fill_quad` takes them, and `caps`, each a convex polygon in order around
    its edge. No two pieces overlap, so a translucent stroke composites
    once."""

    var quads: List[Point2D]
    var caps: List[List[Point2D]]

    def __init__(out self):
        self.quads = List[Point2D]()
        self.caps = List[List[Point2D]]()

    def take_quads(deinit self) -> List[Point2D]:
        """The quads alone, moved out; for a stroke with no caps."""
        return self.quads^


def stroke_quads(points: List[Point2D], width: Float64) -> List[Point2D]:
    """`stroke_pieces` with butt ends, which are quads alone."""
    return stroke_pieces(points, width, StrokeCap.BUTT).take_quads()


def stroke_pieces(
    points: List[Point2D],
    width: Float64,
    cap: StrokeCap,
    axis: Vector2D = Vector2D(1.0, 0.0),
) -> StrokePieces:
    """The `width`-thick band along the polyline `points`, as quads (four
    corners each, in order around the quad's edge, quad after quad) and the
    caps on its ends.

    Neighbouring quads meet on a mitred edge — both use the same two corners
    — so the band has no gap at a joint and no overlap either, and a
    translucent stroke composites once everywhere. The two open ends are
    finished by `cap`: `BUTT` flush, `SQUARE` with the end quads pushed out
    by half the width, `ROUND` with a half disc each, which starts and ends
    on exactly the end quad's two corners so the two share that edge. A
    polyline that ends where it starts, around at least three distinct
    points, is a ring instead: it has no ends, and its last quad meets its
    first on a mitred edge like any other joint. Repeated points are
    skipped. A polyline of no length is a dot under `ROUND` (one disc), a
    square turned to `axis` (the local x axis in device space) under
    `SQUARE`, and nothing under `BUTT`.

    At a cusp the miter is clamped to `MITER_LIMIT`, which lets the two
    quads either side overlap slightly there.
    """
    var path = List[Point2D](capacity=len(points))
    for p in points:
        if len(path) == 0 or path[len(path) - 1] != p:
            path.append(p)
    var out = StrokePieces()
    if len(path) == 0 or width <= 0.0:
        return out^
    var half = width / 2.0
    if len(path) == 1:
        _add_dot(out, path[0], half, cap, axis)
        return out^
    var closed = len(path) >= 4 and path[0] == path[len(path) - 1]
    if closed:
        # The repeat of the first point; the ring wraps round to it instead.
        _ = path.pop()

    var n = len(path)
    var segments = n if closed else n - 1
    if not closed and cap == StrokeCap.SQUARE:
        path[0] = _pushed_out(path[0], path[1], half)
        path[n - 1] = _pushed_out(path[n - 1], path[n - 2], half)
    var normals = List[Vector2D](capacity=segments)
    for i in range(segments):
        var d = path[(i + 1) % n] - path[i]
        normals.append(Vector2D(-d.y, d.x) / d.magnitude())

    # Each vertex's offset to the band's left edge; the right edge is its
    # negation. A joint's offset lies along the bisector of its two
    # normals, long enough that both neighbouring edges stay `half` away;
    # an open end's is its one segment's normal.
    var offsets = List[Vector2D](capacity=n)
    for j in range(n):
        if not closed and j == 0:
            offsets.append(normals[0] * half)
        elif not closed and j == n - 1:
            offsets.append(normals[segments - 1] * half)
        else:
            offsets.append(_miter(normals[(j - 1 + n) % n], normals[j], half))

    out.quads.reserve(4 * segments)
    for i in range(segments):
        var k = (i + 1) % n
        out.quads.append(path[i] + offsets[i])
        out.quads.append(path[k] + offsets[k])
        out.quads.append(path[k] - offsets[k])
        out.quads.append(path[i] - offsets[i])

    if not closed and cap == StrokeCap.ROUND:
        out.caps.append(_half_disc(path[0], offsets[0], half))
        out.caps.append(_half_disc(path[n - 1], -offsets[n - 1], half))
    return out^


def _pushed_out(end: Point2D, inner: Point2D, half: Float64) -> Point2D:
    """`end` moved `half` further from `inner`, along the segment: a square
    cap's lengthening, shared so `stroke_segment` matches `stroke_pieces`."""
    var d = end - inner
    return end + d / d.magnitude() * half


def _half_disc(
    center: Point2D, from_offset: Vector2D, half: Float64
) -> List[Point2D]:
    """The half disc of radius `half` about `center`, from
    `center + from_offset` round to `center - from_offset`, bulging a
    quarter turn on from `from_offset` (counter-clockwise, x right and y
    up). Given the start's left offset or the end's right one, as
    `stroke_pieces` passes them, that is away from the band. The two ends
    are those exact values, so the base is the end quad's own edge."""
    var steps = max(circle_segments(half) // 2, 2)
    var across = Vector2D(-from_offset.y, from_offset.x)
    var corners = List[Point2D](capacity=steps + 1)
    corners.append(center + from_offset)
    for i in range(1, steps):
        var angle = PI * Float64(i) / Float64(steps)
        corners.append(center + from_offset * cos(angle) + across * sin(angle))
    corners.append(center - from_offset)
    return corners^


def _add_dot(
    mut out: StrokePieces,
    center: Point2D,
    half: Float64,
    cap: StrokeCap,
    axis: Vector2D,
):
    """A stroke of no length: a disc under `ROUND`, a square of side
    `2 * half` along `axis` under `SQUARE`, nothing under `BUTT`."""
    if cap == StrokeCap.ROUND:
        var steps = circle_segments(half)
        var disc = List[Point2D](capacity=steps)
        for i in range(steps):
            var angle = 2.0 * PI * Float64(i) / Float64(steps)
            disc.append(center + Vector2D(cos(angle), sin(angle)) * half)
        out.caps.append(disc^)
    elif cap == StrokeCap.SQUARE:
        var length = axis.magnitude()
        var along = Vector2D(1.0, 0.0) if length == 0.0 else axis / length
        along = along * half
        var across = Vector2D(-along.y, along.x)
        out.quads.append(center - along - across)
        out.quads.append(center + along - across)
        out.quads.append(center + along + across)
        out.quads.append(center - along + across)


def _miter(before: Vector2D, after: Vector2D, half: Float64) -> Vector2D:
    """The offset to the left edge at a joint between segments with unit
    normals `before` and `after`, clamped to `MITER_LIMIT` half-widths."""
    var bisector = before + after
    var length = bisector.magnitude()
    if length == 0.0:
        # The path doubles straight back: no bisector exists.
        return after * half
    bisector /= length
    var reach = half / bisector.dot(after)
    return bisector * min(reach, MITER_LIMIT * half)


struct PlacedMask(Movable):
    """A blurred mask and where its top-left pixel lands on the device."""

    var mask: BlurredMask
    var x: Int
    var y: Int

    def __init__(out self, var mask: BlurredMask, x: Int, y: Int):
        self.mask = mask^
        self.x = x
        self.y = y


def bezier_shadow_mask(
    c: RenderCommand, m: Matrix[3, 3], scale: Float64, blur: Int
) -> PlacedMask:
    """The stroke of `c` (a `CurvesPayload` shadow command) mapped by `m`,
    rasterised into an alpha mask and blurred by `blur` device pixels.

    The quads are the ones the stroke itself fills, and each cap is fanned
    into quads of its own, three corners each with the last repeated: the
    mask is one opaque colour, so where they overlap does not matter. A
    curve with no visible stroke gives an empty mask.
    """
    var corners = List[Point2D]()
    if c.style._stroke_visible():
        var pieces = stroke_pieces(
            bezier_device_points(c, m),
            Float64(stroke_thickness_px(c.style, m, scale)),
            c.style.stroke_cap,
            device_x_axis(m),
        )
        corners = pieces.quads.copy()
        for cap in pieces.caps:
            for i in range(1, len(cap) - 1):
                corners.append(cap[0])
                corners.append(cap[i])
                corners.append(cap[i + 1])
                corners.append(cap[i + 1])
    return quads_shadow_mask(corners, blur)


def quads_shadow_mask(corners: List[Point2D], blur: Int) -> PlacedMask:
    """Device quads (four corners each, as `fill_quad` takes them)
    rasterised into an alpha mask and blurred by `blur` device pixels.

    The quads are shifted by a whole number of pixels onto the mask, so
    every pixel centre falls where it would on the device and the mask holds
    the same pixels the quads paint there. No quads give an empty mask.
    """
    if len(corners) == 0:
        return PlacedMask(BlurredMask(List[UInt8](), 0, 0, 0), 0, 0)
    var lo = corners[0]
    var hi = corners[0]
    for p in corners:
        lo = Point2D(min(lo.x, p.x), min(lo.y, p.y))
        hi = Point2D(max(hi.x, p.x), max(hi.y, p.y))
    var x0 = Int(floor(lo.x))
    var y0 = Int(floor(lo.y))
    var width = Int(ceil(hi.x)) - x0 + 1
    var height = Int(ceil(hi.y)) - y0 + 1

    # Filled white on a scratch surface, so the mask is the same pixels the
    # hard quads paint; only its alpha is kept.
    var scratch = MemorySurface(width, height)
    var s = scratch.surface()
    for q in range(0, len(corners), 4):
        var qx: Array[Float64, 4] = [
            corners[q].x - Float64(x0),
            corners[q + 1].x - Float64(x0),
            corners[q + 2].x - Float64(x0),
            corners[q + 3].x - Float64(x0),
        ]
        var qy: Array[Float64, 4] = [
            corners[q].y - Float64(y0),
            corners[q + 1].y - Float64(y0),
            corners[q + 2].y - Float64(y0),
            corners[q + 3].y - Float64(y0),
        ]
        fill_quad(s, qx, qy, Color.WHITE)
    var alpha = List[UInt8](length=width * height, fill=0)
    for i in range(width * height):
        alpha[i] = scratch.data[i * 4 + 3]
    var mask = blur_alpha(alpha, width, height, Float64(blur) / 2.0)
    var pad = mask.pad
    return PlacedMask(mask^, x0 - pad, y0 - pad)
