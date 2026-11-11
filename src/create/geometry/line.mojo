from std.math import min, max, sqrt
from create.math import Point2D, Vector2D
from .bezier import Bezier
from .spline import Spline
from .drawable import Curve, DrawTarget
from ._shared import (
    _closest_on_segment,
    _distance_squared,
    _orientation,
    _point_on_segment,
)
from .arc import Arc
from .capsule import Capsule, _spine_distance
from .circle import Circle
from .ellipse import Ellipse, _UNIT_CIRCLE
from .polygon import Polygon
from .rectangle import Rectangle
from .sector import Sector
from .triangle import Triangle


struct Line(Copyable, Curve, Equatable, ImplicitlyCopyable, Movable, Writable):
    """A line segment from `start` to `end`: `length`, `at`, `tangent`,
    `at_distance`, `split`, `midpoint`, `bounds`, `flatten`,
    `beziers`, `closest_point`, `intersects`, `move_to`, `translate`.

    A `Curve`, like `Arc`, `Bezier` and `Spline`: a straight one, as in
    mathematics, with `t` proportional to distance. It has no interior, so
    unlike the `Region`s it has no `center()`, `area()` or `overlaps`, and
    is the *subject* of `l.intersects(x)` -- see the comment above
    `intersects` for why that method exists only on curves.

    `intersects` and `_point_on_segment`-based checks treat the endpoints
    and any touching/collinear-overlapping point as inclusive. A
    zero-length line (`start == end`) is a degenerate point segment:
    `intersects` and `closest_point` remain exact for it (a point can
    still "intersect" the collapsed line if it coincides with it).
    """

    var start: Point2D
    var end: Point2D

    def __init__(out self, start: Point2D, end: Point2D):
        self.start = start
        self.end = end

    def __eq__(self, other: Line) -> Bool:
        return self.start == other.start and self.end == other.end

    def __ne__(self, other: Line) -> Bool:
        return not (self == other)

    def write_to[W: Writer](self, mut writer: W):
        writer.write("Line(start=", self.start, ", end=", self.end, ")")

    def length(self) -> Float64:
        return sqrt(_distance_squared(self.end, self.start))

    def at(self, t: Float64) -> Point2D:
        """The point at parameter `t`: `start` at 0, `end` at 1, and
        proportional to distance in between. Not clamped: outside 0..1 it
        carries on along the line, as `lerp` extrapolates."""
        return self.start.lerp(self.end, t)

    def tangent(self, t: Float64) -> Vector2D:
        """The derivative at `t`: `end - start`, the same everywhere — the
        direction of travel, with the line's length as its magnitude. Zero
        for a zero-length line."""
        return self.end - self.start

    def at_distance(self, distance: Float64) -> Point2D:
        """The point `distance` along the line from `start`, clamped to the
        line's ends. Exact, and as cheap as `at`."""
        var total = self.length()
        if distance <= 0.0 or total == 0.0:
            return self.start
        if distance >= total:
            return self.end
        return self.at(distance / total)

    def split(self, t: Float64) -> Tuple[Line, Line]:
        """The line cut at `t` into two, together tracing exactly the
        original: the first runs `start` to `at(t)`, the second `at(t)` to
        `end`."""
        var cut = self.at(t)
        return (Line(self.start, cut), Line(cut, self.end))

    def bounds(self) -> Rectangle:
        """The tightest axis-aligned rectangle around the line: the box its
        two ends span, zero-width or zero-height when it is axis-aligned."""
        var lo = Point2D(
            min(self.start.x, self.end.x), min(self.start.y, self.end.y)
        )
        var hi = Point2D(
            max(self.start.x, self.end.x), max(self.start.y, self.end.y)
        )
        return Rectangle(lo.lerp(hi, 0.5), hi.x - lo.x, hi.y - lo.y)

    def flatten(self, tolerance: Float64) -> List[Point2D]:
        """`start` and `end`: a line is already straight, whatever the
        tolerance."""
        return [self.start, self.end]

    def beziers(self) -> List[Bezier]:
        """The line as one cubic Bézier, its controls at the thirds, so it
        traces the line exactly and at the same speed."""
        return [
            Bezier(
                self.start,
                self.start.lerp(self.end, 1.0 / 3.0),
                self.start.lerp(self.end, 2.0 / 3.0),
                self.end,
            )
        ]

    def intersects(self, other: Line) -> Bool:
        var o1 = _orientation(self.start, self.end, other.start)
        var o2 = _orientation(self.start, self.end, other.end)
        var o3 = _orientation(other.start, other.end, self.start)
        var o4 = _orientation(other.start, other.end, self.end)

        if (
            o1 != 0
            and o2 != 0
            and o1 != o2
            and o3 != 0
            and o4 != 0
            and o3 != o4
        ):
            return True
        # Collinear arms -- inclusive: touching or overlapping counts.
        if o1 == 0 and _point_on_segment(other.start, self.start, self.end):
            return True
        if o2 == 0 and _point_on_segment(other.end, self.start, self.end):
            return True
        if o3 == 0 and _point_on_segment(self.start, other.start, other.end):
            return True
        if o4 == 0 and _point_on_segment(self.end, other.start, other.end):
            return True
        return False

    # `x.intersects(y)` is the curve-as-subject relation, for every
    # `Curve` -- asymmetric, unlike `overlaps`, because a curve has no interior
    # and cannot be an operand of a symmetric region test. Two curves meet
    # where they cross or touch: exactly for two `Line`s, within
    # `_RADIUS_EPSILON` once an `Arc` is involved, since its points are
    # rounded. A region is tested by the cheapest exact method for that
    # shape -- `Circle` via `closest_point`-then-`contains` (exact only
    # because a circle's containment is radial from its centre), `Rectangle`
    # and `Triangle` via endpoint containment (covers a curve wholly inside,
    # which no edge test would catch) plus their edges as `Line`s, and
    # `Sector` and `Polygon` the same way, a sector's edges being two radii
    # and an `Arc`. `Bezier` and `Spline` have no exact test against most
    # shapes, so they flatten themselves and test the segments (see
    # `Bezier.intersects`); a `Line` or `Arc` hands a test against one back
    # to it.
    def intersects(self, p: Point2D) -> Bool:
        return _point_on_segment(p, self.start, self.end)

    def intersects(self, a: Arc) -> Bool:
        return a.intersects(self)

    def intersects(self, b: Bezier) -> Bool:
        return b.intersects(self)

    def intersects(self, s: Spline) -> Bool:
        return s.intersects(self)

    def intersects(self, s: Sector) -> Bool:
        if s._is_rounded():
            return self.intersects(s._outline())
        if s.contains(self.start) or s.contains(self.end):
            return True
        return s._boundary_meets(self)

    def intersects(self, p: Polygon) -> Bool:
        if p._is_rounded():
            return self.intersects(p._outline())
        if p.contains(self.start) or p.contains(self.end):
            return True
        return p._boundary_meets(self)

    def intersects(self, c: Circle) -> Bool:
        return c.contains(self.closest_point(c.position))

    def intersects(self, c: Capsule) -> Bool:
        return _spine_distance(c._spine(), self) <= c.r

    def intersects(self, e: Ellipse) -> Bool:
        # Mapped onto the unit circle with `e`, the line is still one.
        if e._is_flat():
            return self.intersects(e.bounds())
        return e._to_unit(self).intersects(_UNIT_CIRCLE)

    def intersects(self, r: Rectangle) -> Bool:
        if r._radius() > 0.0:
            return self.intersects(r._outline())
        if r.contains(self.start) or r.contains(self.end):
            return True
        var pts = r._points()
        for i in range(4):
            var edge = Line(pts[i], pts[(i + 1) % 4])
            if self.intersects(edge):
                return True
        return False

    def intersects(self, t: Triangle) -> Bool:
        if t._radius() > 0.0:
            return self.intersects(t._outline())
        if t.contains(self.start) or t.contains(self.end):
            return True
        var pts = t._points()
        for i in range(3):
            var edge = Line(pts[i], pts[(i + 1) % 3])
            if self.intersects(edge):
                return True
        return False

    def closest_point(self, p: Point2D) -> Point2D:
        return _closest_on_segment(p, self.start, self.end)

    def midpoint(self) -> Point2D:
        return self.start.lerp(self.end, 0.5)

    def draw_to[T: DrawTarget](self, mut target: T):
        target._line(self)

    def move_to(self, position: Point2D) -> Self:
        return self.translate(position - self.midpoint())

    def translate(self, delta: Vector2D) -> Self:
        var moved = self.copy()
        moved.start = moved.start + delta
        moved.end = moved.end + delta
        return moved^
