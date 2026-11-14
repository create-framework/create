"""Dashed strokes, shared by both replays.

A dashed stroke is drawn along its middle: `dashed_stroke` finds the line the
solid stroke would be centred on, in device space, walks the pattern along
it, and strokes each dash with `stroke_pieces`, its ends finished by the
cap. So a dash is a stroke of its own, mitred round a corner, and both
backends draw the same pieces.

The middle of a line or a curve is the path itself. A region's stroke is an
inset band of the (aligned) shape, so its middle is the outline moved in by
half the thickness: worked out from the shape's own numbers for a
rectangle, a circle and a triangle, whose rounding stays exact, and by
mitring every vertex in for a sector or a polygon, whose `grow` (a shadow's
spread, an alignment) moves it back out. The outline is built in local units
and mapped, so it lands where the solid band would.

The pattern's lengths are world units, scaled to device pixels as the
thickness is (`pixel_scale`); `StrokeDash._resolved` has already turned a
preset into lengths when the command was recorded.
"""

from std.math import floor, max, min, sqrt

from create.geometry._fillet import (
    rect_corner_radius,
    rounded_sector_vertices,
    rounded_vertices,
    triangle_corner_radius,
)
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
    _grow_triangle,
)
from ._curve import (
    MITER_LIMIT,
    StrokePieces,
    bezier_device_points,
    circle_segments,
    device_x_axis,
    stroke_pieces,
)
from ._transform import pixel_scale, stroke_thickness_px
from .stroke_cap import StrokeCap

comptime _MIN_PERIOD_PX = 1.0
"""A pattern repeating in less than this many device pixels can't be told
from a solid stroke, and would cut it into needlessly many pieces: it is
drawn solid."""

comptime _SNAP_PX = 1e-6
"""Points closer than this many device pixels are one point."""

comptime _MAX_DASHES = 100_000
"""The most dashes one stroke is cut into; more is drawn solid. A long path
at a short period (a huge circle, a far zoom) would otherwise cost one
piece per pixel or less."""


def dashed_stroke(
    c: RenderCommand, m: Matrix[3, 3], scale: Float64
) -> StrokePieces:
    """The dashes of `c`'s stroke (`c.paint._stroke_dashed()`) mapped by the
    device matrix `m`, as convex device pieces."""
    var width = Float64(stroke_thickness_px(c.paint, m, scale))
    var sf = pixel_scale(m, scale)
    var closed: Bool
    var points: List[Point2D]
    if c.payload.isa[LinePayload]():
        ref line = c.payload[LinePayload]
        points = [
            _mapped(m, line.start),
            _mapped(m, line.end),
        ]
        closed = False
    elif c.payload.isa[CurvesPayload]():
        points = bezier_device_points(c, m)
        closed = False
    else:
        var local = _region_middle(c, width / sf, sf)
        points = List[Point2D](capacity=len(local))
        for p in local:
            points.append(_mapped(m, p))
        closed = True
    ref dash = c.paint.stroke_dash
    var pattern = List[Float64](capacity=dash._len())
    for i in range(dash._len()):
        pattern.append(dash._length(i) * sf)
    return dash_path(
        points,
        closed,
        pattern,
        dash.offset() * sf,
        width,
        c.paint.stroke_cap,
        device_x_axis(m),
    )


def dash_path(
    points: List[Point2D],
    closed: Bool,
    pattern: List[Float64],
    offset: Float64,
    width: Float64,
    cap: StrokeCap,
    axis: Vector2D,
) -> StrokePieces:
    """The polyline `points` (round to its start again if `closed`) cut by
    `pattern` (on, off, on, off, ... lengths, in the points' units) starting
    `offset` into it, each dash stroked `width` wide with `cap` on both ends.

    A dash of no length is a dot, turned along the path under `SQUARE`. A
    pattern too fine to see (`_MIN_PERIOD_PX`) or to cut into pieces
    (`_MAX_DASHES`) strokes the whole path solid, a `closed` one as a ring;
    `axis` turns a solid path of no length, as `stroke_pieces` does.
    """
    var path = points.copy()
    if closed and len(path) > 0:
        path.append(path[0])
    var total = 0.0
    for length in pattern:
        total += length
    var path_length = 0.0
    for i in range(len(path) - 1):
        path_length += (path[i + 1] - path[i]).magnitude()
    if (
        len(pattern) < 2
        or total < _MIN_PERIOD_PX
        or path_length / total > Float64(_MAX_DASHES)
    ):
        return stroke_pieces(path, width, cap, axis)

    # Find where in the pattern the path starts.
    var n = len(pattern)
    var phase = offset - floor(offset / total) * total
    var k = 0
    while phase >= pattern[k] and phase > 0.0:
        phase -= pattern[k]
        k = (k + 1) % n
    var remaining = max(pattern[k] - phase, 0.0)
    var on = k % 2 == 0

    var out = StrokePieces()
    var run = List[Point2D]()
    if on and len(path) > 0:
        run.append(path[0])
    var direction = Vector2D(1.0, 0.0)
    for i in range(len(path) - 1):
        var a = path[i]
        var segment = path[i + 1] - a
        var length = segment.magnitude()
        if length == 0.0:
            continue
        direction = segment / length
        var position = 0.0
        # Every switch between dash and gap inside this segment.
        while remaining <= length - position:
            position += remaining
            # A switch on the segment's end is that end exactly: a point a
            # rounding error short of it would make a segment of no
            # direction, which the next joint would mitre wildly.
            var p = path[i + 1] if length - position < _SNAP_PX else (
                a + direction * position
            )
            if on:
                _extend(run, p)
                _add_dash(out, run, width, cap, direction)
                run = List[Point2D]()
            else:
                run = [p]
            on = not on
            k = (k + 1) % n
            remaining = pattern[k]
        remaining -= length - position
        if on:
            _extend(run, path[i + 1])
    if on and len(run) > 0:
        _add_dash(out, run, width, cap, direction)
    return out^


def _extend(mut run: List[Point2D], p: Point2D):
    """Add `p` to `run` unless it is within `_SNAP_PX` of the last point."""
    if len(run) > 0 and (p - run[len(run) - 1]).magnitude() < _SNAP_PX:
        return
    run.append(p)


def _add_dash(
    mut out: StrokePieces,
    run: List[Point2D],
    width: Float64,
    cap: StrokeCap,
    direction: Vector2D,
):
    """Stroke one dash, the polyline `run`, into `out`; a dot is turned
    along `direction`, the path's where it lies."""
    var pieces = stroke_pieces(run, width, cap, direction)
    for p in pieces.quads:
        out.quads.append(p)
    for polygon in pieces.caps:
        out.caps.append(polygon.copy())


def _mapped(m: Matrix[3, 3], p: Point2D) -> Point2D:
    var q = mat_apply(m, p.x, p.y)
    return Point2D(q[0], q[1])


def _region_middle(
    c: RenderCommand, thickness: Float64, sf: Float64
) -> List[Point2D]:
    """The middle of the region `c`'s stroke, a closed outline in local
    units with no repeat of its first point: the shape's edge moved in by
    half of `thickness` (local units). `sf` is the pixel scale, which sets
    how finely a curve is flattened."""
    var half = thickness / 2.0
    if c.payload.isa[RectPayload]():
        ref rect = c.payload[RectPayload]
        var r = max(
            rect_corner_radius(rect.corner_radius, rect.w, rect.h) - half, 0.0
        )
        var hw = max(rect.w / 2.0 - half, 0.0)
        var hh = max(rect.h / 2.0 - half, 0.0)
        var x = rect.center.x
        var y = rect.center.y
        # From the top-left corner, counter-clockwise.
        var corners: List[Point2D] = [
            Point2D(x - hw, y + hh),
            Point2D(x - hw, y - hh),
            Point2D(x + hw, y - hh),
            Point2D(x + hw, y + hh),
        ]
        return rounded_vertices(corners, r, _step(r * sf))
    if c.payload.isa[CirclePayload]():
        ref circle = c.payload[CirclePayload]
        return _circle(circle.center, max(circle.r - half, 0.0), 0.0, 1.0, sf)
    if c.payload.isa[TrianglePayload]():
        ref triangle = c.payload[TrianglePayload]
        var g = triangle.corners.copy()
        var r = triangle_corner_radius(
            triangle.corner_radius, g[0], g[1], g[2], g[3], g[4], g[5]
        )
        var a = Point2D(g[0], g[1])
        var b = Point2D(g[2], g[3])
        var d = Point2D(g[4], g[5])
        var area = abs(_cross(b - a, d - a)) / 2.0
        var perimeter = (
            (b - a).magnitude() + (d - b).magnitude() + (a - d).magnitude()
        )
        # No further in than the incircle's centre, where it would turn
        # inside out.
        var inset = (
            min(half, 2.0 * area / perimeter) if perimeter > 0.0 else 0.0
        )
        _grow_triangle(g, -inset)
        var corners: List[Point2D] = [
            Point2D(g[0], g[1]),
            Point2D(g[2], g[3]),
            Point2D(g[4], g[5]),
        ]
        var rounded = max(r - inset, 0.0)
        return rounded_vertices(corners, rounded, _step(rounded * sf))
    if c.payload.isa[SectorPayload]():
        ref sector = c.payload[SectorPayload]
        var sweep = max(min(sector.sweep_angle, TAU), -TAU)
        if abs(sweep) >= TAU:
            # A whole disc has no tip: its middle is a circle.
            return _circle(
                sector.center,
                max(sector.r + sector.grow - half, 0.0),
                sector.start_angle,
                1.0 if sweep > 0.0 else -1.0,
                sf,
            )
        var step = _step(sector.r * sf)
        var outline = rounded_sector_vertices(
            sector.center, sector.r, sector.start_angle, sweep, 0.0, step, step
        )
        return _inset(outline, half - sector.grow)
    if c.payload.isa[PolygonPayload]():
        ref polygon = c.payload[PolygonPayload]
        return _inset(polygon.vertices, half - polygon.grow)
    return List[Point2D]()


def _cross(a: Vector2D, b: Vector2D) -> Float64:
    return a.x * b.y - a.y * b.x


def _step(radius_px: Float64) -> Float64:
    """The most radians apart a flattened arc of this device radius puts
    its points, as finely as `circle_segments` cuts a whole circle."""
    return TAU / Float64(circle_segments(radius_px))


def _circle(
    center: Point2D, r: Float64, start: Float64, turn: Float64, sf: Float64
) -> List[Point2D]:
    """The circle of radius `r` about `center` from the angle `start`,
    counter-clockwise for a `turn` of 1 and clockwise for -1."""
    var n = circle_segments(r * sf)
    var out = List[Point2D](capacity=n)
    for i in range(n):
        var angle = start + turn * TAU * Float64(i) / Float64(n)
        out.append(center + Vector2D.from_angle(angle) * r)
    return out^


def _inset(points: List[Point2D], d: Float64) -> List[Point2D]:
    """The closed outline `points` with every edge moved `d` towards its
    inside (outwards if negative), each vertex along its corner's bisector,
    as a mitred stroke's edge is. A spike is mitred no further than
    `MITER_LIMIT` times `d`."""
    var path = List[Point2D](capacity=len(points))
    for p in points:
        if len(path) == 0 or path[len(path) - 1] != p:
            path.append(p)
    if len(path) > 1 and path[0] == path[len(path) - 1]:
        _ = path.pop()
    var n = len(path)
    if n < 3 or d == 0.0:
        return path^
    var area = 0.0
    for i in range(n):
        var q = path[(i + 1) % n]
        area += path[i].x * q.y - q.x * path[i].y
    # Counter-clockwise, the inside is on each edge's left.
    var side = 1.0 if area > 0.0 else -1.0
    var normals = List[Vector2D](capacity=n)
    for i in range(n):
        var e = path[(i + 1) % n] - path[i]
        normals.append(Vector2D(-e.y, e.x) / e.magnitude() * side)
    var out = List[Point2D](capacity=n)
    for i in range(n):
        var before = normals[(i + n - 1) % n]
        var after = normals[i]
        var bisector = before + after
        var length = bisector.magnitude()
        var offset: Vector2D
        if length == 0.0:
            offset = after * d
        else:
            bisector /= length
            var reach = min(1.0 / bisector.dot(after), MITER_LIMIT)
            offset = bisector * (reach * d)
        out.append(path[i] + offset)

    # An edge shorter than the inset beside a sharp corner folds back on
    # itself: its inset runs the wrong way. Drop the smoother of its two
    # vertices until none does, so the corner's mitre stands alone.
    var kept = List[Int](capacity=n)
    for i in range(n):
        kept.append(i)
    var folded = True
    while folded and len(kept) > 3:
        folded = False
        for a in range(len(kept)):
            var i = kept[a]
            var j = kept[(a + 1) % len(kept)]
            if (out[j] - out[i]).dot(path[j] - path[i]) < 0.0:
                var turn_i = normals[(i + n - 1) % n].dot(normals[i])
                var turn_j = normals[(j + n - 1) % n].dot(normals[j])
                _ = kept.pop(a if turn_i > turn_j else (a + 1) % len(kept))
                folded = True
                break
    if len(kept) == n:
        return out^
    var unfolded = List[Point2D](capacity=len(kept))
    for i in kept:
        unfolded.append(out[i])
    return unfolded^
