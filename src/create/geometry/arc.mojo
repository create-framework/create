from std.math import acos, ceil, cos, min, max, sin, sqrt, tan
from create.math import TAU, Point2D, Vector2D
from .bezier import Bezier, _curve_segments
from .spline import Spline
from .drawable import Curve, DrawTarget
from ._shared import (
    _MAX_ARC_BEZIER_ANGLE,
    _MAX_ARC_FLATTEN_SEGMENTS,
    _RADIUS_EPSILON,
    _cross,
    _distance_squared,
    _in_sweep,
    _normalized_sweep,
    _unit,
)
from .capsule import Capsule, _spine_distance
from .circle import Circle
from .ellipse import Ellipse
from .line import Line
from .overlaps import overlaps
from .polygon import Polygon
from .rectangle import Rectangle
from .sector import Sector
from .triangle import Triangle


struct Arc(Copyable, Curve, Equatable, ImplicitlyCopyable, Movable, Writable):
    """A circular arc: part of the circle around `position` with radius `r`,
    from `start_angle` round by `sweep_angle`. `end_angle`, `at`, `tangent`,
    `length`, `at_distance`, `split`, `bounds`, `flatten`, `beziers`,
    `closest_point`, `intersects`, `move_to`, `translate`.

    Angles are radians, counted counter-clockwise from the +x axis: y is up,
    so this is the direction `rotate` turns. The sweep is signed -- positive
    runs counter-clockwise, negative clockwise -- so every arc has one
    spelling and reversing one is negating its sweep. A sweep of a full turn
    (`TAU`) or more is the whole circle. The fields keep what was given; the
    methods read the sweep clamped to a turn.

    Like `Line` and `Bezier`, an arc is a curve with no interior: there is
    no `area`, `contains` or `overlaps` for it. `position` is the circle's
    centre, which the arc passes through only when `r` is zero, and
    `move_to` moves that centre. A zero `r` or sweep collapses the arc to a
    point.
    """

    var position: Point2D
    var r: Float64
    var start_angle: Float64
    var sweep_angle: Float64

    def __init__(
        out self,
        position: Point2D,
        r: Float64,
        start_angle: Float64,
        sweep_angle: Float64,
    ):
        self.position = position
        self.r = r
        self.start_angle = start_angle
        self.sweep_angle = sweep_angle

    def __init__(
        out self,
        position: Point2D,
        r: Int,
        start_angle: Float64,
        sweep_angle: Float64,
    ):
        self = Arc(position, Float64(r), start_angle, sweep_angle)

    def __eq__(self, other: Arc) -> Bool:
        return (
            self.position == other.position
            and self.r == other.r
            and self.start_angle == other.start_angle
            and self.sweep_angle == other.sweep_angle
        )

    def __ne__(self, other: Arc) -> Bool:
        return not (self == other)

    def write_to[W: Writer](self, mut writer: W):
        writer.write(
            "Arc(position=",
            self.position,
            ", r=",
            self.r,
            ", start_angle=",
            self.start_angle,
            ", sweep_angle=",
            self.sweep_angle,
            ")",
        )

    def end_angle(self) -> Float64:
        """`start_angle + sweep_angle`: where the arc ends, as an angle."""
        return self.start_angle + self.sweep_angle

    def _sweep(self) -> Float64:
        """The signed sweep, clamped to a full turn either way."""
        return max(-TAU, min(self.sweep_angle, TAU))

    def _point_at_angle(self, angle: Float64) -> Point2D:
        return self.position + _unit(angle) * self.r

    def at(self, t: Float64) -> Point2D:
        """The point at parameter `t`: 0 at the start, 1 at the end, and
        proportional to distance along the arc in between. Not clamped:
        outside 0..1 it carries on round the circle."""
        return self._point_at_angle(self.start_angle + self._sweep() * t)

    def tangent(self, t: Float64) -> Vector2D:
        """The derivative at `t`: the direction of travel, with a magnitude
        that is the arc's length (the speed per unit of `t`, the same
        everywhere). Zero for a collapsed arc."""
        var sweep = self._sweep()
        var angle = self.start_angle + sweep * t
        return Vector2D(-sin(angle), cos(angle)) * (self.r * sweep)

    def length(self) -> Float64:
        """The distance along the arc from start to end. Exact."""
        return self.r * abs(self._sweep())

    def at_distance(self, distance: Float64) -> Point2D:
        """The point `distance` along the arc from its start, clamped to the
        arc's ends. An arc has constant speed, so this is `at` with `t`
        scaled: exact, and as cheap as `at`."""
        var total = self.length()
        if distance <= 0.0 or total == 0.0:
            return self.at(0.0)
        if distance >= total:
            return self.at(1.0)
        return self.at(distance / total)

    def split(self, t: Float64) -> Tuple[Arc, Arc]:
        """The arc cut at `t` into two on the same circle, together tracing
        exactly the original: the first runs from the start to `at(t)`, the
        second from `at(t)` to the end. A sweep past a full turn is clamped
        to one first, as everywhere else."""
        var sweep = self._sweep()
        var cut = self.start_angle + sweep * t
        return (
            Arc(self.position, self.r, self.start_angle, sweep * t),
            Arc(self.position, self.r, cut, sweep * (1.0 - t)),
        )

    def bounds(self) -> Rectangle:
        """The tightest axis-aligned rectangle around the arc: its two ends,
        widened to each of the circle's four extremes the arc passes."""
        var s = _normalized_sweep(self.start_angle, self.sweep_angle)
        var a = self.at(0.0)
        var b = self.at(1.0)
        var lo = Point2D(min(a.x, b.x), min(a.y, b.y))
        var hi = Point2D(max(a.x, b.x), max(a.y, b.y))
        if _in_sweep(Vector2D(1.0, 0.0), s[0], s[1]):
            hi.x = self.position.x + self.r
        if _in_sweep(Vector2D(0.0, 1.0), s[0], s[1]):
            hi.y = self.position.y + self.r
        if _in_sweep(Vector2D(-1.0, 0.0), s[0], s[1]):
            lo.x = self.position.x - self.r
        if _in_sweep(Vector2D(0.0, -1.0), s[0], s[1]):
            lo.y = self.position.y - self.r
        return Rectangle(lo.lerp(hi, 0.5), hi.x - lo.x, hi.y - lo.y)

    def flatten(self, tolerance: Float64) -> List[Point2D]:
        """Points along the arc, from start to end inclusive, such that the
        straight segments between them stray from the arc by at most
        `tolerance`.

        The points are evenly spaced, as few as the tolerance allows, and
        capped at 1024 segments. A collapsed arc still gives two points.
        """
        var sweep = abs(self._sweep())
        var n = 1
        if tolerance > 0.0 and tolerance < self.r and sweep > 0.0:
            # A chord spanning angle `a` strays r * (1 - cos(a / 2)) from
            # the circle at its middle.
            var widest = 2.0 * acos(1.0 - tolerance / self.r)
            n = Int(ceil(sweep / widest))
            n = max(1, min(n, _MAX_ARC_FLATTEN_SEGMENTS))
        var points = List[Point2D](capacity=n + 1)
        for i in range(n + 1):
            points.append(self.at(Float64(i) / Float64(n)))
        return points^

    def beziers(self) -> List[Bezier]:
        """The arc as cubic Béziers, each ending where the next starts, in
        pieces of at most 45°. An approximation -- no cubic is exactly a
        circle -- but within about 4e-6 of the radius. A full circle ends
        exactly where it starts. A collapsed arc gives no curves.
        """
        var curves = List[Bezier]()
        var sweep = self._sweep()
        if self.r == 0.0 or sweep == 0.0:
            return curves^
        var n = Int(ceil(abs(sweep) / _MAX_ARC_BEZIER_ANGLE))
        var step = sweep / Float64(n)
        # Each control sits on the tangent at its end, this far out along
        # it: the length that makes the cubic's midpoint land on the circle.
        var reach = self.r * 4.0 / 3.0 * tan(step / 4.0)
        var first = self.at(0.0)
        var start = first
        for i in range(n):
            var a0 = self.start_angle + step * Float64(i)
            var a1 = a0 + step
            var end = self._point_at_angle(a1)
            if i == n - 1 and abs(sweep) == TAU:
                end = first
            curves.append(
                Bezier(
                    start,
                    start + Vector2D(-sin(a0), cos(a0)) * reach,
                    end - Vector2D(-sin(a1), cos(a1)) * reach,
                    end,
                )
            )
            start = end
        return curves^

    def closest_point(self, p: Point2D) -> Point2D:
        """The point on the arc nearest `p`: straight out from the centre
        when `p` lies within the sweep, otherwise the nearer end. From the
        centre itself every point is as near, and the start is returned."""
        var v = p - self.position
        if v.magnitude_squared() == 0.0:
            return self.at(0.0)
        var s = _normalized_sweep(self.start_angle, self.sweep_angle)
        if _in_sweep(v, s[0], s[1]):
            return self.position + v * (self.r / v.magnitude())
        var a = self.at(0.0)
        var b = self.at(1.0)
        return a if _distance_squared(p, a) <= _distance_squared(p, b) else b

    def _furthest_along(self, direction: Vector2D) -> Point2D:
        """The point on the arc furthest in `direction`: straight out that
        way from the centre when the sweep reaches it, otherwise the end
        further that way. A zero `direction` gives the start."""
        if direction.magnitude_squared() > 0.0 and self._spans(
            self.position + direction
        ):
            return self.position + direction * (self.r / direction.magnitude())
        var a = self.at(0.0)
        var b = self.at(1.0)
        return a if (a - b).dot(direction) >= 0.0 else b

    def _spans(self, p: Point2D) -> Bool:
        """Whether the direction from the centre to `p` lies within the
        sweep, however far `p` is from the circle."""
        var s = _normalized_sweep(self.start_angle, self.sweep_angle)
        return _in_sweep(p - self.position, s[0], s[1])

    # The `intersects` family is documented above `Line.intersects`.
    def intersects(self, p: Point2D) -> Bool:
        var off = abs((p - self.position).magnitude() - self.r)
        return off <= _RADIUS_EPSILON * self.r and self._spans(p)

    def intersects(self, l: Line) -> Bool:
        var d = l.end - l.start
        var len_sq = d.magnitude_squared()
        if len_sq == 0.0:
            return self.intersects(l.start)
        var f = l.start - self.position
        # The line through the segment comes nearest the centre at `t_near`
        # along it, `h` away, and crosses the circle `half` either side of
        # there. Each crossing, pulled back onto the segment, is a meeting
        # exactly when it is on the arc; a tangent just short of the circle
        # after rounding still gets its one touching point.
        var length = sqrt(len_sq)
        var h = abs(_cross(d, f)) / length
        if h > self.r * (1.0 + _RADIUS_EPSILON):
            return False
        var t_near = -f.dot(d) / len_sq
        var half = sqrt(max(0.0, self.r * self.r - h * h)) / length
        var t0 = max(0.0, min(t_near - half, 1.0))
        var t1 = max(0.0, min(t_near + half, 1.0))
        return self.intersects(l.start + d * t0) or self.intersects(
            l.start + d * t1
        )

    def intersects(self, other: Arc) -> Bool:
        if self.r == 0.0:
            return other.intersects(self.position)
        if other.r == 0.0:
            return self.intersects(other.position)
        var between = other.position - self.position
        var d = between.magnitude()
        var slack = _RADIUS_EPSILON * (self.r + other.r)
        if d <= slack:
            # One circle: the arcs meet where their sweeps overlap, which
            # is exactly when one holds an end of the other.
            if abs(self.r - other.r) > slack:
                return False
            return (
                self._spans(other.at(0.0))
                or self._spans(other.at(1.0))
                or other._spans(self.at(0.0))
                or other._spans(self.at(1.0))
            )
        if d > self.r + other.r + slack or d < abs(self.r - other.r) - slack:
            return False
        # The circles cross on the chord `along` from this centre towards
        # the other, `h` either side of the line between them.
        var along = (d * d + self.r * self.r - other.r * other.r) / (2.0 * d)
        var h = sqrt(max(0.0, self.r * self.r - along * along))
        var u = between * (1.0 / d)
        var mid = self.position + u * along
        var side = Vector2D(-u.y, u.x) * h
        var p = mid + side
        var q = mid - side
        return (self._spans(p) and other._spans(p)) or (
            self._spans(q) and other._spans(q)
        )

    def intersects(self, c: Circle) -> Bool:
        return c.contains(self.closest_point(c.position))

    def intersects(self, c: Capsule) -> Bool:
        return _spine_distance(c._spine(), self) <= c.r

    def intersects(self, e: Ellipse) -> Bool:
        # An arc mapped onto the ellipse's unit circle is no arc, so it is
        # followed as a curve is, by its segments.
        if not overlaps(self.bounds(), e.bounds()):
            return False
        for segment in _curve_segments(self):
            if segment.intersects(e):
                return True
        return False

    def intersects(self, r: Rectangle) -> Bool:
        if r._radius() > 0.0:
            return self.intersects(r._outline())
        if r.contains(self.at(0.0)) or r.contains(self.at(1.0)):
            return True
        var pts = r._points()
        for i in range(4):
            if self.intersects(Line(pts[i], pts[(i + 1) % 4])):
                return True
        return False

    def intersects(self, t: Triangle) -> Bool:
        if t._radius() > 0.0:
            return self.intersects(t._outline())
        if t.contains(self.at(0.0)) or t.contains(self.at(1.0)):
            return True
        var pts = t._points()
        for i in range(3):
            if self.intersects(Line(pts[i], pts[(i + 1) % 3])):
                return True
        return False

    def intersects(self, s: Sector) -> Bool:
        if s._is_rounded():
            return self.intersects(s._outline())
        if s.contains(self.at(0.0)) or s.contains(self.at(1.0)):
            return True
        return s._boundary_meets(self)

    def intersects(self, p: Polygon) -> Bool:
        if p._is_rounded():
            return self.intersects(p._outline())
        if p.contains(self.at(0.0)) or p.contains(self.at(1.0)):
            return True
        return p._boundary_meets(self)

    def intersects(self, b: Bezier) -> Bool:
        return b.intersects(self)

    def intersects(self, s: Spline) -> Bool:
        return s.intersects(self)

    def draw_to[T: DrawTarget](self, mut target: T):
        # Converted here, in local space: the transform maps Béziers
        # exactly, so a non-uniform scale draws the arc of an ellipse.
        target._curves(self.beziers())

    def move_to(self, position: Point2D) -> Self:
        var moved = self.copy()
        moved.position = position
        return moved^

    def translate(self, delta: Vector2D) -> Self:
        var moved = self.copy()
        moved.position = moved.position + delta
        return moved^
