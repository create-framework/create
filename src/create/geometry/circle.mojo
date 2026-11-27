from std.math import sqrt
from create.math import PI, Point, Vector
from .bezier import _curve_segments
from ._overlap import _regions_overlap
from .curve import Curve
from .shape import Shape
from ._collider import _Collider, _Core, _contains, _overlaps
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
    Shape,
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

    var position: Point
    var radius: Float64

    def __init__(out self, position: Point, radius: Float64):
        self.position = position
        self.radius = radius

    def __init__(out self, position: Point, radius: Int):
        self = Circle(position, Float64(radius))

    def __eq__(self, other: Circle) -> Bool:
        return self.position == other.position and self.radius == other.radius

    def __ne__(self, other: Circle) -> Bool:
        return not (self == other)

    def write_to[W: Writer](self, mut writer: W):
        writer.write(
            "Circle(position=", self.position, ", radius=", self.radius, ")"
        )

    def center(self) -> Point:
        """Its centre: `position`."""
        return self.position

    def area(self) -> Float64:
        """How much room it covers: π times its radius squared."""
        return PI * self.radius * self.radius

    def diameter(self) -> Float64:
        """How wide it is across: twice its radius."""
        return self.radius * 2.0

    def bounds(self) -> Rectangle:
        """The tightest axis-aligned rectangle around the circle."""
        return Rectangle(self.position, self.diameter(), self.diameter())

    def closest_point(self, p: Point) -> Point:
        """Its point nearest `p`: `p` itself when inside, otherwise the
        nearest point on its edge."""
        var d = p - self.position
        var distance_squared = d.dot(d)
        if (
            distance_squared == 0.0
            or distance_squared <= self.radius * self.radius
        ):
            return p
        return self.position + d * (self.radius / sqrt(distance_squared))

    def contains(self, p: Point) -> Bool:
        """Whether `p` is inside, its boundary included."""
        return _distance_squared(p, self.position) <= self.radius * self.radius

    # A `Circle`, `Capsule`, `Rectangle` or `Triangle`, rounded or not, or
    # a `Line`, is a convex core grown by a radius, and is held exactly when
    # a disc of its radius round every corner of its core is (`_contains`).
    def contains(self, other: Circle) -> Bool:
        """Whether the whole of the other shape, or the line, lies inside, its
        boundary included. Rounded corners count, on both."""
        return _contains(self, other)

    def contains(self, r: Rectangle) -> Bool:
        """Whether the whole of the other shape, or the line, lies inside, its
        boundary included. Rounded corners count, on both."""
        return _contains(self, r)

    def contains(self, t: Triangle) -> Bool:
        """Whether the whole of the other shape, or the line, lies inside, its
        boundary included. Rounded corners count, on both."""
        return _contains(self, t)

    def contains(self, l: Line) -> Bool:
        """Whether the whole of the other shape, or the line, lies inside, its
        boundary included. Rounded corners count, on both."""
        return _contains(self, l)

    def contains(self, c: Capsule) -> Bool:
        """Whether the whole of the other shape, or the line, lies inside, its
        boundary included. Rounded corners count, on both."""
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

    def contains(self, s: Sector) -> Bool:
        """Whether the whole of the other shape, or the line, lies inside, its
        boundary included. Rounded corners count, on both."""
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

    def contains(self, p: Polygon) -> Bool:
        """Whether the whole of the other shape, or the line, lies inside, its
        boundary included. Rounded corners count, on both."""
        if p._is_rounded():
            return self.contains(p._outline())
        for v in p.vertices:
            if not self.contains(v):
                return False
        return True

    def contains(self, e: Ellipse) -> Bool:
        """Whether the whole of the other shape, or the line, lies inside, its
        boundary included. Rounded corners count, on both."""
        # A circle is the ellipse of its diameter, which takes it exactly.
        return Ellipse(
            self.position, self.diameter(), self.diameter()
        ).contains(e)

    def overlaps(self, other: Rectangle) -> Bool:
        """Whether this and `other` share any point, their boundaries
        included: shapes that only touch, along an edge or at a corner,
        overlap. Symmetric: `other.overlaps(self)` gives the same answer."""
        return _overlaps(self, other)

    def overlaps(self, other: Circle) -> Bool:
        """Whether this and `other` share any point, their boundaries
        included: shapes that only touch, along an edge or at a corner,
        overlap. Symmetric: `other.overlaps(self)` gives the same answer."""
        return _overlaps(self, other)

    def overlaps(self, other: Ellipse) -> Bool:
        """Whether this and `other` share any point, their boundaries
        included: shapes that only touch, along an edge or at a corner,
        overlap. Symmetric: `other.overlaps(self)` gives the same answer."""
        return _regions_overlap(other, self)

    def overlaps(self, other: Capsule) -> Bool:
        """Whether this and `other` share any point, their boundaries
        included: shapes that only touch, along an edge or at a corner,
        overlap. Symmetric: `other.overlaps(self)` gives the same answer."""
        return _overlaps(self, other)

    def overlaps(self, other: Triangle) -> Bool:
        """Whether this and `other` share any point, their boundaries
        included: shapes that only touch, along an edge or at a corner,
        overlap. Symmetric: `other.overlaps(self)` gives the same answer."""
        return _overlaps(self, other)

    def overlaps(self, other: Sector) -> Bool:
        """Whether this and `other` share any point, their boundaries
        included: shapes that only touch, along an edge or at a corner,
        overlap. Symmetric: `other.overlaps(self)` gives the same answer."""
        return _regions_overlap(other, self)

    def overlaps(self, other: Polygon) -> Bool:
        """Whether this and `other` share any point, their boundaries
        included: shapes that only touch, along an edge or at a corner,
        overlap. Symmetric: `other.overlaps(self)` gives the same answer."""
        return _regions_overlap(other, self)

    def move_to(self, position: Point) -> Self:
        """It moved so its `position` is at `position`; this one is
        unchanged."""
        var moved = self.copy()
        moved.position = position
        return moved^

    def translate(self, delta: Vector) -> Self:
        """It moved by `delta`; this one is unchanged."""
        var moved = self.copy()
        moved.position = moved.position + delta
        return moved^

    comptime _corner_count = 1

    def _core(self) -> _Core[Self._corner_count]:
        """The centre, grown by the radius."""
        return _Core[1]([self.position], self.radius)
