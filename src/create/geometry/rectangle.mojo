from std.math import cos, min, max, sin
from create.math import PI, Point, Vector
from create.math._optional_float64 import _OptionalFloat64
from ._fillet import rect_corner_radius
from .bezier import _curve_segments
from ._overlap import _regions_overlap
from .drawable import Curve, DrawTarget, Region
from ._collider import _Collider, _Core, _contains, _overlaps
from ._shared import (
    _distance_squared,
    _rounded_closest,
    _rounded_outline,
    _unit,
)
from .capsule import Capsule
from .circle import Circle
from .ellipse import Ellipse
from .line import Line
from .polygon import Polygon
from .sector import Sector
from .triangle import Triangle


struct Rectangle(
    Copyable,
    Equatable,
    ImplicitlyCopyable,
    Movable,
    Region,
    Writable,
    _Collider,
):
    """A rectangle, upright unless turned by `rotation`: `center`, `area`,
    `bounds`, `left`/`right`/`bottom`/`top`, `closest_point`, `contains`,
    `move_to`, `translate`.

    Locations are `Point` and displacements `Vector`, throughout this
    module; extents are plain scalars, like `Circle`'s radius. Width and
    height are two independent lengths rather than a coordinate pair, so
    they are not grouped: read them as `width`/`height` and pair them however
    the caller needs.

    `position` is the centre, not a corner -- consistent with every shape in
    this module and with `canvas.rectangle`. `width`/`height` are the full
    width and height, so `left()`/`right()`/`bottom()`/`top()` are
    `+-width/2`/`+-height/2` from the centre. Coordinates follow world space: y
    grows upward, so `top()` is `position.y + height/2` and `bottom()` is
    `position.y - height/2`.

    `contains` and `closest_point` treat the boundary as inside -- a point
    exactly on an edge is contained, and `closest_point` returns it
    unchanged. A zero `width`/`height` collapses the rectangle to a segment or a
    point; `contains`/`overlaps` remain exact for it rather than reporting
    a false containment or overlap. `width`/`height` are assumed non-negative.

    `corner_radius` rounds all four corners, as `canvas.rectangle` draws
    them, and every test here sees the rounded shape: a point in a sharp
    corner's cut-away is outside. It is clamped to half the shorter side.
    `left()`/`right()`/`bottom()`/`top()` stay the bounding box's.

    `rotation` turns the rectangle about `position`, in radians
    counter-clockwise (y is up), as `canvas.transform(rotate(...))` turns
    what it draws; `width` and `height` stay its own width and height. Every
    test sees the turned shape, exactly, and `left()`/`right()`/`bottom()`/
    `top()` and `bounds()` are its upright bounding box's. Drawn, it is the
    upright rectangle turned, so a gradient fill, the rounding and the
    stroke turn with it, while a shadow's offset stays screen-fixed unless
    `shadow_follows_transform` is set, as for any turned shape.
    """

    var position: Point
    var width: Float64
    var height: Float64
    var corner_radius: Float64
    """How far each corner is rounded, in the units of `width`/`height`; 0 is
    sharp."""
    var rotation: Float64
    """How far the rectangle is turned about `position`, in radians
    counter-clockwise; 0 is upright."""

    def __init__(
        out self,
        position: Point,
        width: Float64,
        height: Float64,
        *,
        corner_radius: _OptionalFloat64 = 0.0,
        rotation: _OptionalFloat64 = 0.0,
    ):
        self.position = position
        self.width = width
        self.height = height
        self.corner_radius = corner_radius.or_else(0.0)
        self.rotation = rotation.or_else(0.0)

    def __init__(
        out self,
        position: Point,
        width: Int,
        height: Int,
        *,
        corner_radius: _OptionalFloat64 = 0.0,
        rotation: _OptionalFloat64 = 0.0,
    ):
        self = Rectangle(
            position,
            Float64(width),
            Float64(height),
            corner_radius=corner_radius,
            rotation=rotation,
        )

    def __eq__(self, other: Rectangle) -> Bool:
        return (
            self.position == other.position
            and self.width == other.width
            and self.height == other.height
            and self.corner_radius == other.corner_radius
            and self.rotation == other.rotation
        )

    def __ne__(self, other: Rectangle) -> Bool:
        return not (self == other)

    def write_to[W: Writer](self, mut writer: W):
        writer.write(
            "Rectangle(position=",
            self.position,
            ", width=",
            self.width,
            ", height=",
            self.height,
        )
        if self.corner_radius != 0.0:
            writer.write(", corner_radius=", self.corner_radius)
        if self.rotation != 0.0:
            writer.write(", rotation=", self.rotation)
        writer.write(")")

    def center(self) -> Point:
        return self.position

    def area(self) -> Float64:
        var r = self._radius()
        return self.width * self.height - (4.0 - PI) * r * r

    def bounds(self) -> Rectangle:
        """The tightest axis-aligned rectangle around this one: upright,
        itself, sharp, since rounding never pulls in an edge's middle;
        turned, as far as its rounded corners reach along each axis."""
        var half = self._half_extents()
        return Rectangle(self.position, 2.0 * half[0], 2.0 * half[1])

    def closest_point(self, p: Point) -> Point:
        var r = self._radius()
        if r > 0.0:
            return _rounded_closest(self._inner().closest_point(p), p, r)
        if self.rotation != 0.0:
            var q = self._to_local(p)
            var half_w = self.width / 2.0
            var half_h = self.height / 2.0
            if abs(q.x) <= half_w and abs(q.y) <= half_h:
                return p
            return self._from_local(
                Vector(
                    max(-half_w, min(q.x, half_w)),
                    max(-half_h, min(q.y, half_h)),
                )
            )
        return Point(
            max(self.left(), min(p.x, self.right())),
            max(self.bottom(), min(p.y, self.top())),
        )

    def left(self) -> Float64:
        return self.position.x - self._half_extents()[0]

    def right(self) -> Float64:
        return self.position.x + self._half_extents()[0]

    def bottom(self) -> Float64:
        return self.position.y - self._half_extents()[1]

    def top(self) -> Float64:
        return self.position.y + self._half_extents()[1]

    def contains(self, p: Point) -> Bool:
        var r = self._radius()
        if r > 0.0:
            return _distance_squared(self._inner().closest_point(p), p) <= r * r
        if self.rotation != 0.0:
            var q = self._to_local(p)
            return (
                abs(q.x) <= self.width / 2.0 and abs(q.y) <= self.height / 2.0
            )
        return (
            self.left() <= p.x <= self.right()
            and self.bottom() <= p.y <= self.top()
        )

    # A `Circle`, `Capsule`, `Rectangle` or `Triangle`, rounded or not, or
    # a `Line`, is a convex core grown by a radius, and is held exactly when
    # a disc of its radius round every corner of its core is (`_contains`).
    def contains(self, other: Rectangle) -> Bool:
        return _contains(self, other)

    def contains(self, c: Circle) -> Bool:
        return _contains(self, c)

    def contains(self, t: Triangle) -> Bool:
        return _contains(self, t)

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

    # A rounded or turned rectangle holds the rest as its outline polygon,
    # and a rounded shape is tested as its own.
    def contains(self, s: Sector) -> Bool:
        if not self._is_plain():
            return self._outline().contains(s)
        return self.contains(s.bounds())

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
        if not self._is_plain():
            return self._outline().contains(e)
        return self.contains(e.bounds())

    def overlaps(self, other: Rectangle) -> Bool:
        """Whether this and `other` share any point, their boundaries
        included: shapes that only touch, along an edge or at a corner,
        overlap. Symmetric: `other.overlaps(self)` gives the same answer."""
        # The commonest test in a game: two sharp, upright rectangles
        # overlap when their spans do along both axes, four comparisons and
        # no polygon test.
        if self._is_plain() and other._is_plain():
            return (
                self.left() <= other.right()
                and other.left() <= self.right()
                and self.bottom() <= other.top()
                and other.bottom() <= self.top()
            )
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

    def draw_to[T: DrawTarget](self, mut target: T):
        target._rectangle(self)

    def move_to(self, position: Point) -> Self:
        var moved = self.copy()
        moved.position = position
        return moved^

    def translate(self, delta: Vector) -> Self:
        var moved = self.copy()
        moved.position = moved.position + delta
        return moved^

    comptime _corner_count = 4

    def _core(self) -> _Core[Self._corner_count]:
        """The inner rectangle, grown by the corner radius."""
        var r = self._radius()
        if r > 0.0:
            return _Core[Self._corner_count](self._inner()._points(), r)
        return _Core[Self._corner_count](self._points(), 0.0)

    def _radius(self) -> Float64:
        """The corner radius as drawn: clamped to half the shorter side."""
        return rect_corner_radius(self.corner_radius, self.width, self.height)

    def _is_plain(self) -> Bool:
        """Whether the rectangle is sharp and upright: its own bounds."""
        return self._radius() <= 0.0 and self.rotation == 0.0

    def _inner(self) -> Rectangle:
        """The sharp rectangle every edge moves in to by the radius: the
        rounded one is the points within the radius of it."""
        var r = self._radius()
        return Rectangle(
            self.position,
            self.width - 2.0 * r,
            self.height - 2.0 * r,
            rotation=self.rotation,
        )

    def _outline(self) -> Polygon:
        """The rectangle as a polygon: its corners, or rounded, each fillet
        flattened."""
        var r = self._radius()
        if r <= 0.0:
            var corners = List[Point](capacity=4)
            for p in self._points():
                corners.append(p)
            return Polygon(corners^)
        return _rounded_outline(self._inner()._points(), self._points(), r)

    def _half_extents(self) -> Tuple[Float64, Float64]:
        """Half the width and height of the bounding box: the inner
        rectangle's, turned, grown by the corner radius."""
        if self.rotation == 0.0:
            return (self.width / 2.0, self.height / 2.0)
        var r = self._radius()
        var c = abs(cos(self.rotation))
        var s = abs(sin(self.rotation))
        var half_w = self.width / 2.0 - r
        var half_h = self.height / 2.0 - r
        return (half_w * c + half_h * s + r, half_w * s + half_h * c + r)

    def _to_local(self, p: Point) -> Vector:
        """`p` from the centre, in the rectangle's own upright frame."""
        return (p - self.position).rotate(-self.rotation)

    def _from_local(self, v: Vector) -> Point:
        """Back from the rectangle's own frame: `_to_local` undone."""
        return self.position + v.rotate(self.rotation)

    def _points(self) -> Array[Point, 4]:
        """The corners, counter-clockwise from the upright rectangle's
        bottom left."""
        if self.rotation != 0.0:
            var u = _unit(self.rotation) * (self.width / 2.0)
            var v = _unit(self.rotation + PI / 2.0) * (self.height / 2.0)
            return [
                self.position - u - v,
                self.position + u - v,
                self.position + u + v,
                self.position - u + v,
            ]
        return [
            Point(self.left(), self.bottom()),
            Point(self.right(), self.bottom()),
            Point(self.right(), self.top()),
            Point(self.left(), self.top()),
        ]

    def _holds_strictly(self, p: Point) -> Bool:
        """Whether everything close round `p` is inside: inside, and off the
        boundary."""
        if self.rotation != 0.0:
            var q = self._to_local(p)
            return abs(q.x) < self.width / 2.0 and abs(q.y) < self.height / 2.0
        return (
            self.left() < p.x < self.right()
            and self.bottom() < p.y < self.top()
        )
