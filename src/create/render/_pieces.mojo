"""A shape as convex device-space pieces, the form both replays draw.

Every kind but the two analytic primitives — rectangles and circles, which
each replay rasterises from their equations — is lowered to `Pieces` by
`shape_pieces` (`_lower.mojo`) before it is drawn: lines, curves, sectors,
polygons and triangles. The CPU fills each piece with `fill_quad` or
`fill_convex`, whose half-open rule composites an edge two pieces share
exactly once; the GPU pushes them as vertices. So the two backends draw the
same pieces, and each needs one path for all of them rather than one per
kind.

A blurred shadow of pieces is a mask rasterised from them and blurred
(`pieces_shadow_mask`), which both backends composite. Unlike an image's, it
is not cached: pieces have no stable id to key it by, so each costs one blur
per frame.
"""

from std.math import ceil, floor

from create.color.color import Color
from create.math.point import Point

from ._blur import BlurredMask, PlacedMask
from ._curve import StrokePieces
from ._raster import FillPaint, fill_convex, fill_quad
from ._surface import MemorySurface, Surface


struct Pieces(Movable):
    """A shape's fill and stroke as convex device pieces, none overlapping
    another, so a translucent shape composites once.

    Each part is quads, four corners apiece in order around their edge as
    `fill_quad` takes them (a corner repeats where a piece is a triangle),
    and polygons, each a whole convex outline: a triangle's fill, a round
    cap. A lowered shape holds only what it paints, so an empty part is one
    the style hides.
    """

    var fill_quads: List[Point]
    var fill_polygons: List[List[Point]]
    var stroke_quads: List[Point]
    var stroke_polygons: List[List[Point]]

    def __init__(out self):
        self.fill_quads = List[Point]()
        self.fill_polygons = List[List[Point]]()
        self.stroke_quads = List[Point]()
        self.stroke_polygons = List[List[Point]]()

    def has_fill(self) -> Bool:
        return len(self.fill_quads) > 0 or len(self.fill_polygons) > 0

    def has_stroke(self) -> Bool:
        return len(self.stroke_quads) > 0 or len(self.stroke_polygons) > 0

    def add_stroke(mut self, strip: StrokePieces):
        """Add a stroke strip's quads and caps to the stroke."""
        for p in strip.quads:
            self.stroke_quads.append(p)
        for cap in strip.caps:
            self.stroke_polygons.append(cap.copy())

    def clear_fill(mut self):
        self.fill_quads.clear()
        self.fill_polygons.clear()

    def clear_stroke(mut self):
        self.stroke_quads.clear()
        self.stroke_polygons.clear()


def fill_pieces[
    o: Origin[mut=True]
](
    s: Surface[o],
    quads: List[Point],
    polygons: List[List[Point]],
    paint: FillPaint,
):
    """Fill one part of a shape's pieces: each quad with `fill_quad`, each
    polygon with `fill_convex`, which walks edges as `fill_quad` does, so a
    polygon and the quad it meets share that edge exactly."""
    for q in range(0, len(quads), 4):
        var qx: Array[Float64, 4] = [
            quads[q].x,
            quads[q + 1].x,
            quads[q + 2].x,
            quads[q + 3].x,
        ]
        var qy: Array[Float64, 4] = [
            quads[q].y,
            quads[q + 1].y,
            quads[q + 2].y,
            quads[q + 3].y,
        ]
        fill_quad(s, qx, qy, paint)
    for polygon in polygons:
        fill_convex(s, polygon, paint)


def pieces_mask(pieces: Pieces) -> PlacedMask:
    """Every piece, fill and stroke alike, rasterised into one alpha mask.

    The pieces are shifted by a whole number of pixels onto the mask, so
    every pixel centre falls where it would on the device and the mask holds
    the same pixels the pieces paint there. No pieces give an empty mask.
    """
    var lo = Point(Float64.MAX, Float64.MAX)
    var hi = Point(-Float64.MAX, -Float64.MAX)
    _extend(lo, hi, pieces.fill_quads)
    _extend(lo, hi, pieces.stroke_quads)
    for polygon in pieces.fill_polygons:
        _extend(lo, hi, polygon)
    for polygon in pieces.stroke_polygons:
        _extend(lo, hi, polygon)
    if lo.x > hi.x:
        return PlacedMask.empty()
    var x0 = Int(floor(lo.x))
    var y0 = Int(floor(lo.y))
    var width = Int(ceil(hi.x)) - x0 + 1
    var height = Int(ceil(hi.y)) - y0 + 1

    # Filled white on a scratch surface, so the mask is the same pixels the
    # hard pieces paint; only its alpha is kept.
    var scratch = MemorySurface(width, height)
    var shift = Point(Float64(x0), Float64(y0))
    var s = scratch.surface()
    fill_pieces(
        s,
        _shifted(pieces.fill_quads, shift),
        _shifted(pieces.fill_polygons, shift),
        Color.WHITE,
    )
    fill_pieces(
        s,
        _shifted(pieces.stroke_quads, shift),
        _shifted(pieces.stroke_polygons, shift),
        Color.WHITE,
    )
    return PlacedMask(BlurredMask(scratch.alpha(), width, height, 0), x0, y0)


def pieces_shadow_mask(pieces: Pieces, blur: Int) -> PlacedMask:
    """`pieces_mask` blurred by `blur` device pixels."""
    return pieces_mask(pieces).blurred(blur)


def _extend(mut lo: Point, mut hi: Point, points: List[Point]):
    """Grow the box `lo`..`hi` to hold `points`."""
    for p in points:
        lo = Point(min(lo.x, p.x), min(lo.y, p.y))
        hi = Point(max(hi.x, p.x), max(hi.y, p.y))


def _shifted(points: List[Point], by: Point) -> List[Point]:
    var out = List[Point](capacity=len(points))
    for p in points:
        out.append(Point(p.x - by.x, p.y - by.y))
    return out^


def _shifted(polygons: List[List[Point]], by: Point) -> List[List[Point]]:
    var out = List[List[Point]](capacity=len(polygons))
    for polygon in polygons:
        out.append(_shifted(polygon, by))
    return out^
