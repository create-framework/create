from std.math import min, max, sqrt
from create.math import PI, Point2D, Vector2D
from create.math._optional_float64 import _OptionalFloat64
from ._fillet import triangle_corner_radius
from .bezier import _curve_segments
from .drawable import Curve, DrawTarget, Region
from ._collider import _Collider, _Core, _contains
from ._shared import (
    _closest_on_segment,
    _distance_squared,
    _orientation,
    _point_on_segment,
    _rounded_closest,
    _rounded_outline,
)
from .capsule import Capsule
from .circle import Circle
from .ellipse import Ellipse, _UNIT_CIRCLE
from .line import Line
from .polygon import Polygon
from .rectangle import Rectangle
from .sector import Sector


struct Triangle(
    Copyable,
    Equatable,
    ImplicitlyCopyable,
    Movable,
    Region,
    Writable,
    _Collider,
):
    """A triangle defined by its three vertices `a`, `b`, `c`: `center`,
    `area`, `closest_point`, `contains`, `move_to`, `translate`.

    Unlike `Rectangle`/`Circle`, a `Triangle` is not centre-positioned in
    its fields -- `center()` (the centroid) is derived, and `move_to`
    translates all three vertices so the centroid lands on the given
    point. Vertex winding (clockwise or counter-clockwise) does not matter
    to any method here; `contains` and `area` both work from unsigned or
    sign-normalized quantities.

    `contains` treats every edge as inside (boundary-inclusive), matching
    `Rectangle`/`Circle`. When the three vertices are collinear (including
    all three coincident), the hull has zero area and collapses to the
    longest edge as a segment; `contains`/`overlaps`/`area` all remain
    exact for this degenerate case rather than reporting a false
    containment, overlap, or a divide-by-zero.

    `corner_radius` rounds all three corners by one radius, as
    `canvas.triangle` draws them, and every test here sees the rounded
    shape. It is clamped so no corner's rounding overruns half of either
    edge beside it; one thin corner limits all three.
    """

    var a: Point2D
    var b: Point2D
    var c: Point2D
    var corner_radius: Float64
    """How far each corner is rounded; 0 is sharp."""

    def __init__(
        out self,
        a: Point2D,
        b: Point2D,
        c: Point2D,
        *,
        corner_radius: _OptionalFloat64 = 0.0,
    ):
        self.a = a
        self.b = b
        self.c = c
        self.corner_radius = corner_radius.or_else(0.0)

    def __eq__(self, other: Triangle) -> Bool:
        return (
            self.a == other.a
            and self.b == other.b
            and self.c == other.c
            and self.corner_radius == other.corner_radius
        )

    def __ne__(self, other: Triangle) -> Bool:
        return not (self == other)

    def write_to[W: Writer](self, mut writer: W):
        writer.write("Triangle(a=", self.a, ", b=", self.b, ", c=", self.c)
        if self.corner_radius != 0.0:
            writer.write(", corner_radius=", self.corner_radius)
        writer.write(")")

    def center(self) -> Point2D:
        return Point2D(
            (self.a.x + self.b.x + self.c.x) / 3.0,
            (self.a.y + self.b.y + self.c.y) / 3.0,
        )

    def _signed_area2(self) -> Float64:
        var ab = self.b - self.a
        var ac = self.c - self.a
        return ab.x * ac.y - ab.y * ac.x

    def area(self) -> Float64:
        var r = self._radius()
        if r > 0.0:
            # The inner triangle, a band along each of its edges, and a
            # whole circle's worth of corners.
            var inner = self._inner()
            var perimeter = (
                sqrt(_distance_squared(inner.a, inner.b))
                + sqrt(_distance_squared(inner.b, inner.c))
                + sqrt(_distance_squared(inner.c, inner.a))
            )
            return inner.area() + perimeter * r + PI * r * r
        return abs(self._signed_area2()) / 2.0

    def bounds(self) -> Rectangle:
        """The tightest axis-aligned rectangle around the triangle. Rounded,
        it is the inner triangle's grown by the radius, so a sharp tip's
        rounding pulls it in."""
        var r = self._radius()
        var t = self._inner() if r > 0.0 else self
        var lo = Point2D(
            min(min(t.a.x, t.b.x), t.c.x) - r,
            min(min(t.a.y, t.b.y), t.c.y) - r,
        )
        var hi = Point2D(
            max(max(t.a.x, t.b.x), t.c.x) + r,
            max(max(t.a.y, t.b.y), t.c.y) + r,
        )
        return Rectangle(lo.lerp(hi, 0.5), hi.x - lo.x, hi.y - lo.y)

    def closest_point(self, p: Point2D) -> Point2D:
        var r = self._radius()
        if r > 0.0:
            return _rounded_closest(self._inner().closest_point(p), p, r)
        if self.contains(p):
            return p
        var p1 = _closest_on_segment(p, self.a, self.b)
        var p2 = _closest_on_segment(p, self.b, self.c)
        var p3 = _closest_on_segment(p, self.c, self.a)
        var d1 = _distance_squared(p1, p)
        var d2 = _distance_squared(p2, p)
        var d3 = _distance_squared(p3, p)
        if d1 <= d2 and d1 <= d3:
            return p1
        if d2 <= d3:
            return p2
        return p3

    def contains(self, p: Point2D) -> Bool:
        var r = self._radius()
        if r > 0.0:
            return _distance_squared(self._inner().closest_point(p), p) <= r * r
        if self._signed_area2() == 0.0:
            # Degenerate hull: a segment (or a point). Contained iff on the
            # longest edge -- the other two edges are contained within it.
            var len_ab = _distance_squared(self.b, self.a)
            var len_bc = _distance_squared(self.c, self.b)
            var len_ca = _distance_squared(self.a, self.c)
            if len_ab >= len_bc and len_ab >= len_ca:
                return _point_on_segment(p, self.a, self.b)
            if len_bc >= len_ca:
                return _point_on_segment(p, self.b, self.c)
            return _point_on_segment(p, self.c, self.a)
        var d1 = _orientation(self.a, self.b, p)
        var d2 = _orientation(self.b, self.c, p)
        var d3 = _orientation(self.c, self.a, p)
        var has_neg = (d1 < 0) or (d2 < 0) or (d3 < 0)
        var has_pos = (d1 > 0) or (d2 > 0) or (d3 > 0)
        return not (has_neg and has_pos)

    # A `Circle`, `Capsule`, `Rectangle` or `Triangle`, rounded or not, or
    # a `Line`, is a convex core grown by a radius, and is held exactly when
    # a disc of its radius round every corner of its core is (`_contains`).
    def contains(self, other: Triangle) -> Bool:
        return _contains(self, other)

    def contains(self, r: Rectangle) -> Bool:
        return _contains(self, r)

    def contains(self, c: Circle) -> Bool:
        return _contains(self, c)

    def contains(self, l: Line) -> Bool:
        return _contains(self, l)

    def contains(self, c: Capsule) -> Bool:
        return _contains(self, c)

    def contains[C: Curve](self, curve: C) -> Bool:
        """Whether the whole of `curve` (an `Arc`, `Bezier` or `Spline`) is
        inside: every segment of it flattened to within 1e-4 of its size,
        as `intersects` follows it, so a curve grazing the edge from inside
        is decided only that closely."""
        for segment in _curve_segments(curve):
            if not self.contains(segment):
                return False
        return True

    # A rounded triangle holds the rest as its outline polygon, and a
    # rounded shape is tested as its own.
    def contains(self, s: Sector) -> Bool:
        if self._radius() > 0.0:
            return self._outline().contains(s)
        if s._is_rounded():
            return self.contains(s._outline())
        # A sector is its tip fanned out to its arc, and a triangle is
        # convex, so it holds the sector when it holds the tip and, for
        # each edge, the arc's point furthest across it. Both ways across
        # are tried, so a degenerate triangle needs no winding.
        if not self.contains(s.position):
            return False
        var a = s.arc()
        var pts = self._points()
        for i in range(3):
            var e = pts[(i + 1) % 3] - pts[i]
            var normal = Vector2D(-e.y, e.x)
            if not (
                self.contains(a._furthest_along(normal))
                and self.contains(a._furthest_along(-normal))
            ):
                return False
        return True

    def contains(self, p: Polygon) -> Bool:
        if self._radius() > 0.0:
            return self._outline().contains(p)
        if p._is_rounded():
            return self.contains(p._outline())
        for v in p.vertices:
            if not self.contains(v):
                return False
        return True

    def contains(self, e: Ellipse) -> Bool:
        # With `e` mapped onto the unit circle, the triangle mapped alike is
        # still one.
        if self._radius() > 0.0:
            return self._outline().contains(e)
        if e._is_flat():
            return self.contains(e.bounds())
        return e._to_unit(self).contains(_UNIT_CIRCLE)

    def draw_to[T: DrawTarget](self, mut target: T):
        target._triangle(self)

    def move_to(self, position: Point2D) -> Self:
        return self.translate(position - self.center())

    def translate(self, delta: Vector2D) -> Self:
        var moved = self.copy()
        moved.a = moved.a + delta
        moved.b = moved.b + delta
        moved.c = moved.c + delta
        return moved^

    comptime _corner_count = 3

    def _core(self) -> _Core[Self._corner_count]:
        """The inner triangle, grown by the corner radius."""
        var r = self._radius()
        if r > 0.0:
            return _Core[Self._corner_count](self._inner()._points(), r)
        return _Core[Self._corner_count](self._points(), 0.0)

    def _radius(self) -> Float64:
        """The corner radius as drawn, clamped as `canvas.triangle` clamps
        it; 0 for a degenerate triangle."""
        if self.corner_radius <= 0.0:
            return 0.0
        return triangle_corner_radius(
            self.corner_radius,
            self.a.x,
            self.a.y,
            self.b.x,
            self.b.y,
            self.c.x,
            self.c.y,
        )

    def _inner(self) -> Triangle:
        """The sharp triangle every edge moves in to by the radius: the
        rounded one is the points within the radius of it, each corner's
        fillet centred on its inner corner. Moving every edge in by the
        same distance scales the triangle about its incentre."""
        var la = sqrt(_distance_squared(self.b, self.c))
        var lb = sqrt(_distance_squared(self.c, self.a))
        var lc = sqrt(_distance_squared(self.a, self.b))
        var perimeter = la + lb + lc
        var incentre = Point2D(
            (self.a.x * la + self.b.x * lb + self.c.x * lc) / perimeter,
            (self.a.y * la + self.b.y * lb + self.c.y * lc) / perimeter,
        )
        var inradius = abs(self._signed_area2()) / perimeter
        var k = max((inradius - self._radius()) / inradius, 0.0)
        return Triangle(
            incentre + (self.a - incentre) * k,
            incentre + (self.b - incentre) * k,
            incentre + (self.c - incentre) * k,
        )

    def _outline(self) -> Polygon:
        return _rounded_outline(
            self._inner()._points(), self._points(), self._radius()
        )

    def _points(self) -> Array[Point2D, 3]:
        return [self.a, self.b, self.c]

    def _holds_strictly(self, p: Point2D) -> Bool:
        """Whether everything close round `p` is inside: inside, and off the
        boundary."""
        var d1 = _orientation(self.a, self.b, p)
        var d2 = _orientation(self.b, self.c, p)
        var d3 = _orientation(self.c, self.a, p)
        return d1 != 0 and d1 == d2 and d2 == d3
