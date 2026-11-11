from std.math import min, max, sqrt
from create.math import TAU, Point2D, Vector2D
from create.math._optional_float64 import _OptionalFloat64
from ._fillet import rounded_sector_vertices, sector_corner_radii
from .bezier import _curve_segments
from .drawable import Curve, DrawTarget, Region
from ._shared import (
    _FILLET_STEP,
    _RADIUS_EPSILON,
    _arc_middles,
    _circle_crossings,
    _closest_on_segment,
    _cut_at_circle,
    _cut_at_line,
    _distance_squared,
    _in_sweep,
    _normalized_sweep,
    _segment_middles,
)
from .arc import Arc
from .capsule import Capsule
from .circle import Circle
from .ellipse import Ellipse
from .line import Line
from .polygon import Polygon
from .rectangle import Rectangle
from .triangle import Triangle


struct Sector(
    Copyable, Equatable, ImplicitlyCopyable, Movable, Region, Writable
):
    """A sector -- a slice of pie: the region between two radii of the
    circle around `position` with radius `r`, from `start_angle` round by
    `sweep_angle`. `end_angle`, `center`, `area`, `arc`, `bounds`,
    `closest_point`, `contains`, `move_to`, `translate`.

    The angles are an `Arc`'s: radians, counter-clockwise from the +x axis,
    and a signed sweep, so a negative one runs clockwise and a full turn or
    more is the whole circle. The fields keep what was given.

    `center()` is `position`, the tip of the slice, as for `Circle`: not the
    centroid. `contains` treats the boundary as inside, within the slack
    `Arc.intersects` allows, so points found on the sector's own arc count;
    `closest_point` returns the query point itself when it is inside. A sweep wider than a
    half turn is not convex. A zero `r` collapses the sector to its tip, and
    a zero sweep to the one radius at `start_angle`. `r` is assumed
    non-negative.

    `corner_radius` rounds the tip and both ends of the arc, as
    `canvas.sector` draws them, and every test here sees the rounded shape.
    An end rounds against the arc, tangent to it from inside. Each corner is
    clamped to half of what lies beside it, as a polygon's is; past a half
    turn the tip is concave and its rounding fills the notch. A whole disc
    has no corners. The tests use the rounded outline with each curve
    flattened, so a point within about 0.1% of the radii of the boundary
    may fall either way.
    """

    var position: Point2D
    var r: Float64
    var start_angle: Float64
    var sweep_angle: Float64
    var corner_radius: Float64
    """How far each corner is rounded; 0 is sharp."""

    def __init__(
        out self,
        position: Point2D,
        r: Float64,
        start_angle: Float64,
        sweep_angle: Float64,
        *,
        corner_radius: _OptionalFloat64 = 0.0,
    ):
        self.position = position
        self.r = r
        self.start_angle = start_angle
        self.sweep_angle = sweep_angle
        self.corner_radius = corner_radius.or_else(0.0)

    def __init__(
        out self,
        position: Point2D,
        r: Int,
        start_angle: Float64,
        sweep_angle: Float64,
        *,
        corner_radius: _OptionalFloat64 = 0.0,
    ):
        self = Sector(
            position,
            Float64(r),
            start_angle,
            sweep_angle,
            corner_radius=corner_radius,
        )

    def __eq__(self, other: Sector) -> Bool:
        return (
            self.position == other.position
            and self.r == other.r
            and self.start_angle == other.start_angle
            and self.sweep_angle == other.sweep_angle
            and self.corner_radius == other.corner_radius
        )

    def __ne__(self, other: Sector) -> Bool:
        return not (self == other)

    def write_to[W: Writer](self, mut writer: W):
        writer.write(
            "Sector(position=",
            self.position,
            ", r=",
            self.r,
            ", start_angle=",
            self.start_angle,
            ", sweep_angle=",
            self.sweep_angle,
        )
        if self.corner_radius != 0.0:
            writer.write(", corner_radius=", self.corner_radius)
        writer.write(")")

    def end_angle(self) -> Float64:
        """`start_angle + sweep_angle`: where the sector ends, as an angle."""
        return self.start_angle + self.sweep_angle

    def center(self) -> Point2D:
        return self.position

    def area(self) -> Float64:
        if self._is_rounded():
            return self._outline().area()
        return 0.5 * self.r * self.r * abs(self.arc()._sweep())

    def arc(self) -> Arc:
        """The curved edge of the sector, running the same way round."""
        return Arc(self.position, self.r, self.start_angle, self.sweep_angle)

    def bounds(self) -> Rectangle:
        """The tightest axis-aligned rectangle around the sector: its arc's,
        widened to take in the tip."""
        if self._is_rounded():
            return self._outline().bounds()
        var b = self.arc().bounds()
        var lo = Point2D(
            min(b.left(), self.position.x), min(b.bottom(), self.position.y)
        )
        var hi = Point2D(
            max(b.right(), self.position.x), max(b.top(), self.position.y)
        )
        return Rectangle(lo.lerp(hi, 0.5), hi.x - lo.x, hi.y - lo.y)

    def closest_point(self, p: Point2D) -> Point2D:
        if self._is_rounded():
            return self._outline().closest_point(p)
        if self.contains(p):
            return p
        # Outside, the nearest point is on the boundary: one of the two
        # radii or the arc.
        var a = self.arc()
        var best = a.closest_point(p)
        var ends: Array[Point2D, 2] = [a.at(0.0), a.at(1.0)]
        for end in ends:
            var q = _closest_on_segment(p, self.position, end)
            if _distance_squared(p, q) < _distance_squared(p, best):
                best = q
        return best

    def contains(self, p: Point2D) -> Bool:
        # The arc is found through `cos` and `sin`, as is its sweep, so both
        # boundaries get an arc's slack: the sector holds its own edge.
        if self._is_rounded():
            return self._outline().contains(p)
        var reach = self.r * (1.0 + _RADIUS_EPSILON)
        if _distance_squared(p, self.position) > reach * reach:
            return False
        return self.arc()._spans(p)

    # A sector has no holes, so it holds a shape exactly when it holds the
    # shape's outline: a `Rectangle`, `Triangle` or `Polygon` edge by edge,
    # a `Circle` as a whole-turn `Arc`, another `Sector` as its two radii
    # and its arc. A rounded sector, or a rounded shape it is given, is
    # tested as its outline polygon.
    def contains(self, r: Rectangle) -> Bool:
        if self._is_rounded():
            return self._outline().contains(r)
        if r._radius() > 0.0:
            return self.contains(r._outline())
        return self._contains_polygon(r._points())

    def contains(self, t: Triangle) -> Bool:
        if self._is_rounded():
            return self._outline().contains(t)
        if t._radius() > 0.0:
            return self.contains(t._outline())
        return self._contains_polygon(t._points())

    def contains(self, c: Circle) -> Bool:
        if self._is_rounded():
            return self._outline().contains(c)
        return self._contains_arc(Arc(c.position, c.r, 0.0, TAU))

    def contains(self, other: Sector) -> Bool:
        if self._is_rounded():
            return self._outline().contains(other)
        if other._is_rounded():
            return self.contains(other._outline())
        for radius in other._radii():
            if not self.contains(radius):
                return False
        return self._contains_arc(other.arc())

    # A segment or arc with both ends inside can still leave the sector:
    # across the missing wedge of one wider than a half turn, or bulging
    # out through a radius or the arc. Where it crosses the boundary -- the
    # line of either radius, or the circle -- cuts it into pieces that are
    # each wholly inside or wholly outside, so the sector holds it exactly
    # when it holds the middle of every piece. A piece that only touches
    # the boundary is inside, within the slack of `contains(Point2D)`.
    def contains(self, l: Line) -> Bool:
        if self._is_rounded():
            return self._outline().contains(l)
        if not (self.contains(l.start) and self.contains(l.end)):
            return False
        var cuts = List[Float64]()
        for radius in self._radii():
            _cut_at_line(l, radius, cuts)
        _cut_at_circle(l, self.position, self.r, cuts)
        for middle in _segment_middles(l, cuts^):
            if not self.contains(middle):
                return False
        return True

    def contains[C: Curve](self, curve: C) -> Bool:
        """Whether the whole of `curve` (an `Arc`, `Bezier` or `Spline`) is
        inside: every segment of it flattened to within 1e-4 of its size,
        as `intersects` follows it, so a curve grazing the edge from inside
        is decided only that closely."""
        for segment in _curve_segments(curve):
            if not self.contains(segment):
                return False
        return True

    def _contains_arc(self, a: Arc) -> Bool:
        if not (self.contains(a.at(0.0)) and self.contains(a.at(1.0))):
            return False
        var crossings = List[Point2D]()
        for radius in self._radii():
            _circle_crossings(radius, a.position, a.r, crossings)
        var between = self.position - a.position
        var d = between.magnitude()
        if d > 0.0 and d <= a.r + self.r and d >= abs(a.r - self.r):
            var along = (d * d + a.r * a.r - self.r * self.r) / (2.0 * d)
            var h = sqrt(max(0.0, a.r * a.r - along * along))
            var u = between * (1.0 / d)
            var mid = a.position + u * along
            var side = Vector2D(-u.y, u.x) * h
            crossings.append(mid + side)
            crossings.append(mid - side)
        for middle in _arc_middles(a, crossings):
            if not self.contains(middle):
                return False
        return True

    def contains(self, p: Polygon) -> Bool:
        if self._is_rounded():
            return self._outline().contains(p)
        if p._is_rounded():
            return self.contains(p._outline())
        for i in range(len(p.vertices)):
            if not self.contains(p._edge(i)):
                return False
        return True

    def _is_rounded(self) -> Bool:
        if self.corner_radius <= 0.0:
            return False
        var radii = sector_corner_radii(
            self.r, self.sweep_angle, self.corner_radius
        )
        return radii[0] > 0.0 or radii[1] > 0.0

    def _outline(self) -> Polygon:
        """The rounded sector as a polygon, each curve flattened."""
        return Polygon(
            rounded_sector_vertices(
                self.position,
                self.r,
                self.start_angle,
                self.sweep_angle,
                self.corner_radius,
                _FILLET_STEP,
                _FILLET_STEP,
            )
        )

    def _contains_polygon[N: Int](self, pts: Array[Point2D, N]) -> Bool:
        for i in range(N):
            if not self.contains(Line(pts[i], pts[(i + 1) % N])):
                return False
        return True

    def _radii(self) -> Array[Line, 2]:
        """The two straight edges, from the tip out to where the arc starts
        and ends."""
        var a = self.arc()
        return [Line(self.position, a.at(0.0)), Line(self.position, a.at(1.0))]

    def _boundary_meets(self, l: Line) -> Bool:
        for radius in self._radii():
            if l.intersects(radius):
                return True
        return self.arc().intersects(l)

    def _boundary_meets(self, a: Arc) -> Bool:
        for radius in self._radii():
            if a.intersects(radius):
                return True
        return a.intersects(self.arc())

    def contains(self, e: Ellipse) -> Bool:
        # A sector's arc stays no arc mapped onto the ellipse's unit circle,
        # so the ellipse stands in as its outline polygon.
        if self._is_rounded():
            return self._outline().contains(e)
        if e._is_flat():
            return self.contains(e.bounds())
        return self.contains(e._outline())

    def contains(self, c: Capsule) -> Bool:
        # No holes, so it holds the capsule when it holds its outline: two
        # straight edges and two half circles.
        if self._is_rounded():
            return self._outline().contains(c)
        if c.r <= 0.0:
            return self.contains(c._spine())
        for side in c._sides():
            if not self.contains(side):
                return False
        for cap in c._caps():
            if not self._contains_arc(cap):
                return False
        return True

    def draw_to[T: DrawTarget](self, mut target: T):
        target._sector(self)

    def move_to(self, position: Point2D) -> Self:
        var moved = self.copy()
        moved.position = position
        return moved^

    def translate(self, delta: Vector2D) -> Self:
        var moved = self.copy()
        moved.position = moved.position + delta
        return moved^

    def _holds_strictly(self, p: Point2D) -> Bool:
        """Whether everything close round `p` is inside: inside, and off the
        boundary, which gets its usual slack, taken inward."""
        var reach = self.r * (1.0 - _RADIUS_EPSILON)
        if _distance_squared(p, self.position) >= reach * reach:
            return False
        var sweep = _normalized_sweep(self.start_angle, self.sweep_angle)
        if sweep[1] >= TAU:
            return True
        # Off the closed sweep that is left out, slack and all.
        return not _in_sweep(
            p - self.position, sweep[0] + sweep[1], TAU - sweep[1]
        )
