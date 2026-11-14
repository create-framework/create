"""Every shape kind but the analytic primitives, lowered to `Pieces`.

`shape_pieces` is the one place a line, a curve, a sector, a polygon or a
triangle becomes what a replay draws: convex device pieces, fill and stroke,
holding only what the command's paint shows. Both replays call it on the
same command under the same matrix, so they draw the same pieces, and its
blurred shadow is the same pieces masked (`pieces_shadow_mask`).

Rectangles and circles are not lowered: each replay rasterises them from
their equations, the CPU row by row and the GPU in its own emitters, which
is where they are fast. Neither is a plain triangle's fill, one
`fill_triangle` pass, while it has no rounding and no stroke
(`is_plain_triangle`). A dashed stroke is lowered on every kind, a
rectangle's and a circle's too: its dashes are pieces (`_dash.mojo`), and
its fill the pieces the solid stroke would leave.
"""

from create.geometry._fillet import rect_corner_radius, rounded_vertices
from create.math import TAU
from create.math.matrix import Matrix, _apply as mat_apply
from create.math.point2d import Point2D
from create.math.vector2d import Vector2D

from ._command import (
    CirclePayload,
    CurvesPayload,
    LinePayload,
    PolygonPayload,
    RectPayload,
    RenderCommand,
    SectorPayload,
    TrianglePayload,
)
from ._curve import (
    bezier_device_points,
    circle_segments,
    device_x_axis,
    stroke_pieces,
    stroke_segment,
)
from ._dash import dashed_stroke
from ._pieces import Pieces, PlacedMask, pieces_shadow_mask
from ._polygon import polygon_quads
from ._sector import sector_quads
from ._transform import pixel_scale, stroke_thickness_px
from ._triangle import triangle_pieces
from .stroke_cap import StrokeCap
from .stroke_dash import StrokeDash


def is_lowered(c: RenderCommand) -> Bool:
    """Whether `c` is drawn through `shape_pieces`: a line, a curve, a
    sector, a polygon or a triangle, or any shape with a dashed stroke."""
    if c.paint._stroke_dashed() and c.is_shape():
        return True
    return (
        c.payload.isa[LinePayload]()
        or c.payload.isa[CurvesPayload]()
        or c.payload.isa[SectorPayload]()
        or c.payload.isa[PolygonPayload]()
        or c.payload.isa[TrianglePayload]()
    )


def is_plain_triangle(c: RenderCommand) -> Bool:
    """Whether `c` is a triangle with neither rounding nor a visible
    stroke: one convex fill, which each replay draws in a single pass
    rather than through `shape_pieces`."""
    if not c.payload.isa[TrianglePayload]():
        return False
    return (
        c.payload[TrianglePayload].corner_radius <= 0.0
        and not c.paint._stroke_visible()
    )


def shape_pieces(c: RenderCommand, m: Matrix[3, 3], scale: Float64) -> Pieces:
    """`c` (`is_lowered`) mapped by the device matrix `m` and cut into
    convex pieces, keeping only the parts its paint shows. `scale` is the
    fallback pixel scale for a transform that is not uniform."""
    if c.paint._stroke_dashed():
        return _dashed_pieces(c, m, scale)
    var out: Pieces
    if c.payload.isa[LinePayload]():
        out = _line_pieces(c, m, scale)
    elif c.payload.isa[CurvesPayload]():
        out = Pieces()
        if c.paint._stroke_visible():
            out.add_stroke(
                stroke_pieces(
                    bezier_device_points(c, m),
                    Float64(stroke_thickness_px(c.paint, m, scale)),
                    c.paint.stroke_cap,
                    device_x_axis(m),
                )
            )
    elif c.payload.isa[SectorPayload]():
        out = sector_quads(c, m, scale)
    elif c.payload.isa[PolygonPayload]():
        out = polygon_quads(c, m, scale)
    elif c.payload.isa[TrianglePayload]():
        out = triangle_pieces(c, m, scale)
    else:
        out = Pieces()
    if not c.paint._fill_visible():
        out.clear_fill()
    if not c.paint._stroke_visible():
        out.clear_stroke()
    return out^


def _dashed_pieces(c: RenderCommand, m: Matrix[3, 3], scale: Float64) -> Pieces:
    """`c`'s pieces with its stroke dashed: the fill the solid stroke would
    leave, and the dashes along that stroke's middle."""
    var out: Pieces
    if c.payload.isa[RectPayload]() or c.payload.isa[CirclePayload]():
        out = Pieces()
        if c.paint._fill_visible():
            var fill = _eroded_outline(c, m, scale)
            if len(fill) > 0:
                out.fill_polygons.append(fill^)
    elif c.payload.isa[LinePayload]() or c.payload.isa[CurvesPayload]():
        out = Pieces()
    else:
        var solid = c.copy()
        solid.paint.stroke_dash = StrokeDash.SOLID
        out = shape_pieces(solid, m, scale)
        out.clear_stroke()
    out.add_stroke(dashed_stroke(c, m, scale))
    return out^


def _eroded_outline(
    c: RenderCommand, m: Matrix[3, 3], scale: Float64
) -> List[Point2D]:
    """The rectangle or circle `c` eroded by its stroke, mapped by `m`: the
    convex fill inside the stroke's inner edge, where each replay's own
    rasteriser stops the fill. Empty when the stroke leaves none."""
    var sf = pixel_scale(m, scale)
    var t = Float64(stroke_thickness_px(c.paint, m, scale)) / sf
    var local: List[Point2D]
    if c.payload.isa[RectPayload]():
        ref rect = c.payload[RectPayload]
        var hw = rect.w / 2.0 - t
        var hh = rect.h / 2.0 - t
        if hw <= 0.0 or hh <= 0.0:
            return List[Point2D]()
        var r = max(
            rect_corner_radius(rect.corner_radius, rect.w, rect.h) - t, 0.0
        )
        var x = rect.center.x
        var y = rect.center.y
        var corners: List[Point2D] = [
            Point2D(x - hw, y + hh),
            Point2D(x - hw, y - hh),
            Point2D(x + hw, y - hh),
            Point2D(x + hw, y + hh),
        ]
        local = rounded_vertices(
            corners, r, TAU / Float64(circle_segments(r * sf))
        )
    else:
        ref circle = c.payload[CirclePayload]
        var r = circle.r - t
        if r <= 0.0:
            return List[Point2D]()
        var n = circle_segments(r * sf)
        local = List[Point2D](capacity=n)
        for i in range(n):
            local.append(
                circle.center
                + Vector2D.from_angle(TAU * Float64(i) / Float64(n)) * r
            )
    var out = List[Point2D](capacity=len(local))
    for p in local:
        var q = mat_apply(m, p.x, p.y)
        out.append(Point2D(q[0], q[1]))
    return out^


def _line_pieces(c: RenderCommand, m: Matrix[3, 3], scale: Float64) -> Pieces:
    """A line's stroke: `stroke_segment`'s one quad, or `stroke_pieces`
    for a round cap or a line of no length. A line has no interior."""
    var out = Pieces()
    if not c.paint._stroke_visible():
        return out^
    ref line = c.payload[LinePayload]
    var p0 = mat_apply(m, line.start.x, line.start.y)
    var p1 = mat_apply(m, line.end.x, line.end.y)
    var a = Point2D(p0[0], p0[1])
    var b = Point2D(p1[0], p1[1])
    var width = Float64(stroke_thickness_px(c.paint, m, scale))
    var cap = c.paint.stroke_cap
    if cap == StrokeCap.ROUND or a == b:
        out.add_stroke(stroke_pieces([a, b], width, cap, device_x_axis(m)))
        return out^
    var quad = stroke_segment(a, b, width, cap)
    if quad:
        ref q = quad.value()
        for i in range(4):
            out.stroke_quads.append(q[i])
    return out^


def shape_shadow_mask(
    c: RenderCommand, m: Matrix[3, 3], scale: Float64, blur: Int
) -> PlacedMask:
    """The shadow command `c` (`is_lowered`, one colour) mapped by `m`,
    lowered, rasterised into an alpha mask and blurred by `blur` device
    pixels: only what it paints, so a stroke-only ring leaves its middle."""
    return pieces_shadow_mask(shape_pieces(c, m, scale), blur)
