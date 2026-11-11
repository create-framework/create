from std.math import atan2, ceil, cos, floor, min, max, sin, sqrt
from create.math import PI, TAU, Point2D, Vector2D
from .arc import Arc
from .line import Line
from .polygon import Polygon


comptime _ANGLE_EPSILON = 1e-12
"""How far, in radians, a direction may fall outside a sweep and still count
as on its edge. The edges come from `cos`/`sin` of the angles, which round, so
without it a point exactly on an edge (`Arc.at(1)`, say) could test outside."""

comptime _RADIUS_EPSILON = 1e-9
"""How far, as a fraction of the radius, a point may lie off an arc's circle
and still count as on it. A point on an arc is found through `cos`, `sin` and
`sqrt`, which round, so exact equality would miss most of them: tangents,
crossings, the arc's own `at`."""

comptime _MAX_ARC_BEZIER_ANGLE = PI / 4.0
"""The widest piece `Arc.beziers` approximates with one cubic. At 45° the
cubic strays from the circle by about 4e-6 of the radius: under a quarter
pixel for any radius short of 60,000 pixels."""

comptime _MAX_ARC_FLATTEN_SEGMENTS = 1024
"""Upper bound on `Arc.flatten`'s segment count, as for `Bezier.flatten`."""

comptime _FILLET_STEP = TAU / 64.0
"""The widest turn, in radians, between two points of a rounded corner in a
rounded shape's outline polygon. The chords sit inside the arc by at most
`r * (1 - cos(step / 2))`, about 0.1% of the corner radius."""


def _closest_on_segment(p: Point2D, a: Point2D, b: Point2D) -> Point2D:
    var ab = b - a
    var len_sq = ab.dot(ab)
    if len_sq == 0.0:
        return a
    var t = max(0.0, min(1.0, (p - a).dot(ab) / len_sq))
    return a + ab * t


def _orientation(a: Point2D, b: Point2D, c: Point2D) -> Int:
    var cross = (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
    if cross > 0.0:
        return 1
    if cross < 0.0:
        return -1
    return 0


def _point_on_segment(p: Point2D, a: Point2D, b: Point2D) -> Bool:
    if _orientation(a, b, p) != 0:
        return False
    return min(a.x, b.x) <= p.x <= max(a.x, b.x) and min(
        a.y, b.y
    ) <= p.y <= max(a.y, b.y)


def _distance_squared(p: Point2D, q: Point2D) -> Float64:
    var d = p - q
    return d.dot(d)


def _rounded_closest(q: Point2D, p: Point2D, r: Float64) -> Point2D:
    """The closest point to `p` on a shape rounded by `r`, given `q`, the
    closest point to `p` on the sharp shape it rounds out from."""
    var d = p - q
    var distance_squared = d.dot(d)
    if distance_squared <= r * r:
        return p
    return q + d * (r / sqrt(distance_squared))


def _cross(a: Vector2D, b: Vector2D) -> Float64:
    return a.x * b.y - a.y * b.x


def _unit(angle: Float64) -> Vector2D:
    return Vector2D(cos(angle), sin(angle))


def _normalized_sweep(
    start_angle: Float64, sweep_angle: Float64
) -> Tuple[Float64, Float64]:
    """The same sweep as a start angle and a counter-clockwise extent in
    `[0, TAU]`: a clockwise sweep is walked from its other end, and anything
    past a full turn is a full turn."""
    if sweep_angle < 0.0:
        return (start_angle + sweep_angle, min(-sweep_angle, TAU))
    return (start_angle, min(sweep_angle, TAU))


def _in_sweep(v: Vector2D, start_angle: Float64, sweep_angle: Float64) -> Bool:
    """Whether direction `v` lies within the sweep, edges included, for a
    normalized sweep (`_normalized_sweep`). A zero `v` has no direction and
    counts as inside.

    Decided by cross products against the edge directions rather than by
    comparing `atan2` angles, so there is no wrap-around at ±PI to handle.
    Up to a half turn the sweep is convex: `v` must be on the inner side of
    both edges and not pointing away from them. Past a half turn it is
    whatever the open, convex wedge it leaves out is not.
    """
    if sweep_angle >= TAU:
        return True
    var magnitude = v.magnitude()
    if magnitude == 0.0:
        return True
    var slack = _ANGLE_EPSILON * magnitude
    var u0 = _unit(start_angle)
    var u1 = _unit(start_angle + sweep_angle)
    if sweep_angle <= PI:
        return (
            _cross(u0, v) >= -slack
            and _cross(v, u1) >= -slack
            and v.dot(_unit(start_angle + sweep_angle / 2.0)) >= -slack
        )
    return not (_cross(u1, v) > slack and _cross(v, u0) > slack)


# A curve that crosses a region's boundary only at known points is wholly
# inside or wholly outside between them, so a region holds it exactly when
# it holds the middle of every piece. These cut segments and arcs at such
# points. A cut where the curve only comes near the boundary costs a piece
# but never the answer, so each cuts at a whole line or circle rather than
# only where the boundary really is.
def _cut_at_line(l: Line, other: Line, mut cuts: List[Float64]):
    """Append the fractions along `l` where it meets the line through
    `other`: one where they cross, or where `other`'s ends fall when the
    two run along the same line."""
    var d = l.end - l.start
    var e = other.end - other.start
    var across = _cross(d, e)
    if across != 0.0:
        cuts.append(_cross(other.start - l.start, e) / across)
    elif (
        _cross(other.start - l.start, d) == 0.0 and d.magnitude_squared() > 0.0
    ):
        cuts.append((other.start - l.start).dot(d) / d.magnitude_squared())
        cuts.append((other.end - l.start).dot(d) / d.magnitude_squared())


def _cut_at_circle(
    l: Line, position: Point2D, r: Float64, mut cuts: List[Float64]
):
    """Append the fractions along `l` where its line crosses the circle."""
    var d = l.end - l.start
    var f = l.start - position
    var len_sq = d.magnitude_squared()
    var b = f.dot(d)
    var discriminant = b * b - len_sq * (f.magnitude_squared() - r * r)
    if len_sq > 0.0 and discriminant >= 0.0:
        var root = sqrt(discriminant)
        cuts.append((-b - root) / len_sq)
        cuts.append((-b + root) / len_sq)


def _segment_middles(l: Line, var cuts: List[Float64]) -> List[Point2D]:
    """The middle of every piece `cuts` leaves of `l`, a cut being a
    fraction along it; those off the segment are pulled back onto it."""
    cuts.append(0.0)
    cuts.append(1.0)
    sort(cuts)
    var middles = List[Point2D]()
    for i in range(len(cuts) - 1):
        var t0 = max(0.0, min(cuts[i], 1.0))
        var t1 = max(0.0, min(cuts[i + 1], 1.0))
        if t1 > t0:
            middles.append(l.start + (l.end - l.start) * ((t0 + t1) / 2.0))
    return middles^


def _circle_crossings(
    l: Line, position: Point2D, r: Float64, mut crossings: List[Point2D]
):
    """Append where the line through `l` crosses the circle."""
    var d = l.end - l.start
    var length = d.magnitude()
    if length == 0.0:
        return
    var u = d * (1.0 / length)
    var foot = l.start + u * (position - l.start).dot(u)
    var h_sq = _distance_squared(position, foot)
    if h_sq <= r * r:
        var half = sqrt(r * r - h_sq)
        crossings.append(foot + u * half)
        crossings.append(foot - u * half)


def _arc_middles(a: Arc, crossings: List[Point2D]) -> List[Point2D]:
    """The middle of every piece of `a` the points `crossings` on its
    circle leave, cut as angles past the start of its counter-clockwise
    sweep; points off the arc cut nothing."""
    var s = _normalized_sweep(a.start_angle, a.sweep_angle)
    var cuts: List[Float64] = [0.0, s[1]]
    for p in crossings:
        var v = p - a.position
        var angle = atan2(v.y, v.x) - s[0]
        angle -= TAU * floor(angle / TAU)
        if angle < s[1]:
            cuts.append(angle)
    sort(cuts)
    var middles = List[Point2D]()
    for i in range(len(cuts) - 1):
        var middle = s[0] + (cuts[i] + cuts[i + 1]) / 2.0
        middles.append(a.position + _unit(middle) * a.r)
    return middles^


def _project_range[
    N: Int
](nx: Float64, ny: Float64, pts: Array[Point2D, N]) -> Tuple[Float64, Float64]:
    var lo = nx * pts[0].x + ny * pts[0].y
    var hi = lo
    for i in range(1, N):
        var proj = nx * pts[i].x + ny * pts[i].y
        lo = min(lo, proj)
        hi = max(hi, proj)
    return (lo, hi)


def _ranges_separate[
    N: Int, M: Int
](
    nx: Float64,
    ny: Float64,
    a: Array[Point2D, N],
    b: Array[Point2D, M],
) -> Bool:
    var ra = _project_range(nx, ny, a)
    var rb = _project_range(nx, ny, b)
    return ra[1] < rb[0] or rb[1] < ra[0]


def _polygons_overlap[
    N: Int, M: Int
](a: Array[Point2D, N], b: Array[Point2D, M]) -> Bool:
    # SAT over both polygons' edge normals -- exact for convex polygons.
    # A zero-length edge contributes no normal, so its axis is skipped; its
    # direction is tested instead (needed to separate collinear degenerate
    # polygons), and the world axes are always tested (needed when both
    # polygons collapse to points and contribute no edge axes at all).
    # Testing extra axes is always sound: separation on any axis proves
    # disjointness, and genuinely overlapping shapes separate on none.
    for i in range(N):
        var p0 = a[i]
        var p1 = a[(i + 1) % N]
        var dx = p1.x - p0.x
        var dy = p1.y - p0.y
        if dx == 0.0 and dy == 0.0:
            continue
        if _ranges_separate(-dy, dx, a, b):
            return False
        if _ranges_separate(dx, dy, a, b):
            return False
    for i in range(M):
        var p0 = b[i]
        var p1 = b[(i + 1) % M]
        var dx = p1.x - p0.x
        var dy = p1.y - p0.y
        if dx == 0.0 and dy == 0.0:
            continue
        if _ranges_separate(-dy, dx, a, b):
            return False
        if _ranges_separate(dx, dy, a, b):
            return False
    if _ranges_separate(1.0, 0.0, a, b):
        return False
    if _ranges_separate(0.0, 1.0, a, b):
        return False
    return True


def _rounded_outline[
    N: Int
](inner: Array[Point2D, N], corners: Array[Point2D, N], r: Float64) -> Polygon:
    """The convex shape with `corners`, each rounded by `r`, as a polygon.

    `inner` is the shape with every edge moved in by `r`: its corners are
    the centres of the fillets. Each fillet turns from one edge's outward
    normal to the next's, taken from `corners` so they stay defined when
    `inner` collapses to a segment or a point.
    """
    var area2 = 0.0
    for i in range(N):
        var a = corners[i]
        var b = corners[(i + 1) % N]
        area2 += a.x * b.y - b.x * a.y
    var points = List[Point2D]()
    for k in range(N):
        # Counter-clockwise, so the outward normal is the edge turned right.
        var i = k if area2 > 0.0 else N - 1 - k
        var before = (i + N - 1) % N if area2 > 0.0 else (i + 1) % N
        var after = (i + 1) % N if area2 > 0.0 else (i + N - 1) % N
        var e0 = corners[i] - corners[before]
        var e1 = corners[after] - corners[i]
        var a0 = atan2(-e0.x, e0.y)
        var sweep = atan2(-e1.x, e1.y) - a0
        while sweep < 0.0:
            sweep += TAU
        var steps = max(Int(ceil(sweep / _FILLET_STEP)), 1)
        for j in range(steps + 1):
            var angle = a0 + sweep * Float64(j) / Float64(steps)
            points.append(inner[i] + _unit(angle) * r)
    return Polygon(points^)


def _winds(a: Point2D, b: Point2D, p: Point2D) -> Int:
    """What the edge from `a` to `b` adds to the winding round `p`: +1 up
    across the horizontal through `p` to its right, -1 down, half-open in
    y so a vertex on that line is counted once."""
    if a.y <= p.y:
        if b.y > p.y and _orientation(a, b, p) > 0:
            return 1
    elif b.y <= p.y and _orientation(a, b, p) < 0:
        return -1
    return 0


def _swapped(p: Point2D) -> Point2D:
    return Point2D(p.y, p.x)


def _closed_outline[N: Int](pts: Array[Point2D, N]) -> List[Line]:
    var outline = List[Line](capacity=N)
    for i in range(N):
        outline.append(Line(pts[i], pts[(i + 1) % N]))
    return outline^
