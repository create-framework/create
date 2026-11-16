from std.iter import downcast
from std.math import sqrt
from create.math import PI, Point2D, Vector2D
from .bezier import _curve_segments
from .drawable import Curve, DrawTarget, Region, Shape
from ._collider import _Collider, _Core, _contains
from ._shared import _RADIUS_EPSILON, _distance_squared
from .capsule import Capsule
from .ellipse import Ellipse
from .line import Line
from .polygon import Polygon
from .rectangle import Rectangle
from .sector import Sector
from .triangle import Triangle


struct Circle(
    Copyable,
    Equatable,
    ImplicitlyCopyable,
    Movable,
    Region,
    Writable,
    _Collider,
):
    """A circle: `center`, `area`, `diameter`, `closest_point`, `contains`,
    `move_to`, `translate`.

    `position` is the centre -- there is no orientation, so unlike
    `Rectangle`/`Triangle` there is nothing y-up affects beyond the centre's
    own coordinates.

    `contains` treats the boundary as inside (`distance <= r`), and
    `closest_point` returns the query point itself when it is already
    inside or exactly at the centre, rather than an arbitrary point on the
    circumference. A zero `radius` collapses the circle to a point; `contains`
    then holds only for that exact point, and `overlaps`/`intersects`
    remain exact rather than always-false. `radius` is assumed non-negative.
    """

    var position: Point2D
    var radius: Float64

    def __init__(out self, position: Point2D, radius: Float64):
        self.position = position
        self.radius = radius

    def __init__(out self, position: Point2D, radius: Int):
        self = Circle(position, Float64(radius))

    def __eq__(self, other: Circle) -> Bool:
        return self.position == other.position and self.radius == other.radius

    def __ne__(self, other: Circle) -> Bool:
        return not (self == other)

    def write_to[W: Writer](self, mut writer: W):
        writer.write(
            "Circle(position=", self.position, ", radius=", self.radius, ")"
        )

    def center(self) -> Point2D:
        return self.position

    def area(self) -> Float64:
        return PI * self.radius * self.radius

    def diameter(self) -> Float64:
        return self.radius * 2.0

    def bounds(self) -> Rectangle:
        """The tightest axis-aligned rectangle around the circle."""
        return Rectangle(self.position, self.diameter(), self.diameter())

    def closest_point(self, p: Point2D) -> Point2D:
        var d = p - self.position
        var distance_squared = d.dot(d)
        if (
            distance_squared == 0.0
            or distance_squared <= self.radius * self.radius
        ):
            return p
        return self.position + d * (self.radius / sqrt(distance_squared))

    def contains(self, p: Point2D) -> Bool:
        return _distance_squared(p, self.position) <= self.radius * self.radius

    def contains[S: Shape](self, shape: S) -> Bool:
        """Whether the whole of `shape` is inside, its boundary included.

        `shape` is a region (`Rectangle`, `Circle`, `Ellipse`, `Capsule`,
        `Triangle`, `Sector` or `Polygon`) or a curve. A `Line` is decided
        exactly; an `Arc`, `Bezier` or `Spline` segment by segment, flattened
        to within 1e-4 of its size as `intersects` follows it, so a curve
        grazing the edge from inside is decided only that closely."""
        # A `Circle`, `Capsule`, `Rectangle` or `Triangle`, rounded or not, or
        # a `Line`, is a convex core grown by a radius, and is held exactly when
        # a disc of its radius round every corner of its core is (`_contains`).
        comptime if conforms_to(S, _Collider):
            return _contains(self, rebind[downcast[S, _Collider]](shape))
        elif S == Sector:
            ref s = rebind[Sector](shape)
            # A sector is its tip fanned out to its arc, and a disc is convex,
            # so it holds the sector when it holds the tip and the arc's point
            # furthest from its centre. That point comes through `cos` and
            # `sin`, so it gets an arc's slack, as in `Sector.contains`.
            if s._is_rounded():
                return self.contains(s._outline())
            if not self.contains(s.position):
                return False
            var far = s.arc()._furthest_along(s.position - self.position)
            var reach = self.radius * (1.0 + _RADIUS_EPSILON)
            return _distance_squared(far, self.position) <= reach * reach
        elif S == Polygon:
            ref p = rebind[Polygon](shape)
            if p._is_rounded():
                return self.contains(p._outline())
            for v in p.vertices:
                if not self.contains(v):
                    return False
            return True
        elif S == Ellipse:
            ref e = rebind[Ellipse](shape)
            # A circle is the ellipse of its diameter, which takes it exactly.
            return Ellipse(
                self.position, self.diameter(), self.diameter()
            ).contains(e)
        elif conforms_to(S, Curve):
            for segment in _curve_segments(rebind[downcast[S, Curve]](shape)):
                if not self.contains(segment):
                    return False
            return True
        else:
            comptime assert False, "contains takes a region or a curve"

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

    comptime _corner_count = 1

    def _core(self) -> _Core[Self._corner_count]:
        """The centre, grown by the radius."""
        return _Core[1]([self.position], self.radius)
