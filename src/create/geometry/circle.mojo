from std.math import sqrt
from create.math import PI, Point2D, Vector2D
from .bezier import _curve_segments
from .drawable import Curve, DrawTarget, Region
from ._shared import _RADIUS_EPSILON, _distance_squared
from .capsule import Capsule
from .ellipse import Ellipse
from .line import Line
from .polygon import Polygon
from .rectangle import Rectangle
from .sector import Sector
from .triangle import Triangle


struct Circle(
    Copyable, Equatable, ImplicitlyCopyable, Movable, Region, Writable
):
    """A circle: `center`, `area`, `diameter`, `closest_point`, `contains`,
    `move_to`, `translate`.

    `position` is the centre and `r` the radius -- there is no orientation, so
    unlike `Rectangle`/`Triangle` there is nothing y-up affects beyond the
    centre's own coordinates.

    `contains` treats the boundary as inside (`distance <= r`), and
    `closest_point` returns the query point itself when it is already
    inside or exactly at the centre, rather than an arbitrary point on the
    circumference. A zero `r` collapses the circle to a point; `contains`
    then holds only for that exact point, and `overlaps`/`intersects`
    remain exact rather than always-false. `r` is assumed non-negative.
    """

    var position: Point2D
    var r: Float64

    def __init__(out self, position: Point2D, r: Float64):
        self.position = position
        self.r = r

    def __init__(out self, position: Point2D, r: Int):
        self = Circle(position, Float64(r))

    def __eq__(self, other: Circle) -> Bool:
        return self.position == other.position and self.r == other.r

    def __ne__(self, other: Circle) -> Bool:
        return not (self == other)

    def write_to[W: Writer](self, mut writer: W):
        writer.write("Circle(position=", self.position, ", r=", self.r, ")")

    def center(self) -> Point2D:
        return self.position

    def area(self) -> Float64:
        return PI * self.r * self.r

    def diameter(self) -> Float64:
        return self.r * 2.0

    def bounds(self) -> Rectangle:
        """The tightest axis-aligned rectangle around the circle."""
        return Rectangle(self.position, self.diameter(), self.diameter())

    def closest_point(self, p: Point2D) -> Point2D:
        var d = p - self.position
        var distance_squared = d.dot(d)
        if distance_squared == 0.0 or distance_squared <= self.r * self.r:
            return p
        return self.position + d * (self.r / sqrt(distance_squared))

    def contains(self, p: Point2D) -> Bool:
        return _distance_squared(p, self.position) <= self.r * self.r

    def contains(self, other: Circle) -> Bool:
        var distance = sqrt(_distance_squared(other.position, self.position))
        return distance + other.r <= self.r

    def contains(self, r: Rectangle) -> Bool:
        if r._radius() > 0.0:
            return self.contains(r._outline())
        for p in r._points():
            if not self.contains(p):
                return False
        return True

    def contains(self, t: Triangle) -> Bool:
        if t._radius() > 0.0:
            return self.contains(t._outline())
        for p in t._points():
            if not self.contains(p):
                return False
        return True

    def contains(self, l: Line) -> Bool:
        return self.contains(l.start) and self.contains(l.end)

    def contains[C: Curve](self, curve: C) -> Bool:
        """Whether the whole of `curve` (an `Arc`, `Bezier` or `Spline`) is
        inside: every segment of it flattened to within 1e-4 of its size,
        as `intersects` follows it, so a curve grazing the edge from inside
        is decided only that closely."""
        for segment in _curve_segments(curve):
            if not self.contains(segment):
                return False
        return True

    def contains(self, s: Sector) -> Bool:
        # A sector is its tip fanned out to its arc, and a disc is convex,
        # so it holds the sector when it holds the tip and the arc's point
        # furthest from its centre. That point comes through `cos` and
        # `sin`, so it gets an arc's slack, as in `Sector.contains`.
        if s._is_rounded():
            return self.contains(s._outline())
        if not self.contains(s.position):
            return False
        var far = s.arc()._furthest_along(s.position - self.position)
        var reach = self.r * (1.0 + _RADIUS_EPSILON)
        return _distance_squared(far, self.position) <= reach * reach

    def contains(self, p: Polygon) -> Bool:
        if p._is_rounded():
            return self.contains(p._outline())
        for v in p.vertices:
            if not self.contains(v):
                return False
        return True

    def contains(self, e: Ellipse) -> Bool:
        # A circle is the ellipse of its diameter, which takes it exactly.
        return Ellipse(
            self.position, self.diameter(), self.diameter()
        ).contains(e)

    def contains(self, c: Capsule) -> Bool:
        # Convex, so it holds the capsule when it holds the discs at both
        # ends, whose hull the capsule is.
        for end in c._ends():
            if not self.contains(end):
                return False
        return True

    def draw_to[T: DrawTarget](self, mut target: T):
        target._circle(self)

    def move_to(self, position: Point2D) -> Self:
        var moved = self.copy()
        moved.position = position
        return moved^

    def translate(self, delta: Vector2D) -> Self:
        var moved = self.copy()
        moved.position = moved.position + delta
        return moved^
