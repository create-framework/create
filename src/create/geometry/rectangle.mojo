from std.math import min, max
from create.math import PI, Point2D, Vector2D
from create.math._optional_float64 import _OptionalFloat64
from ._fillet import rect_corner_radius
from .bezier import _curve_segments
from .drawable import Curve, DrawTarget, Region
from ._collider import _Collider, _Core, _contains
from ._shared import _distance_squared, _rounded_closest, _rounded_outline
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
    """An axis-aligned rectangle: `center`, `area`, `left`/`right`/`bottom`/
    `top`, `closest_point`, `contains`, `move_to`, `translate`.

    Locations are `Point2D` and displacements `Vector2D`, throughout this
    module; extents are plain scalars, like `Circle`'s radius. Width and
    height are two independent lengths rather than a coordinate pair, so
    they are not grouped: read them as `w`/`h` and pair them however the
    caller needs.

    `position` is the centre, not a corner -- consistent with every shape in
    this module and with `canvas.rectangle`. `w`/`h` are full width and
    height, so `left()`/`right()`/`bottom()`/`top()` are `+-w/2`/`+-h/2`
    from the centre. Coordinates follow world space: y grows upward, so
    `top()` is `position.y + h/2` and `bottom()` is `position.y - h/2`.

    `contains` and `closest_point` treat the boundary as inside -- a point
    exactly on an edge is contained, and `closest_point` returns it
    unchanged. A zero `w`/`h` collapses the rectangle to a segment or a
    point; `contains`/`overlaps` remain exact for it rather than reporting
    a false containment or overlap. `w`/`h` are assumed non-negative.

    `corner_radius` rounds all four corners, as `canvas.rectangle` draws
    them, and every test here sees the rounded shape: a point in a sharp
    corner's cut-away is outside. It is clamped to half the shorter side.
    `left()`/`right()`/`bottom()`/`top()` stay the bounding box's.
    """

    var position: Point2D
    var w: Float64
    var h: Float64
    var corner_radius: Float64
    """How far each corner is rounded, in the units of `w`/`h`; 0 is sharp."""

    def __init__(
        out self,
        position: Point2D,
        w: Float64,
        h: Float64,
        *,
        corner_radius: _OptionalFloat64 = 0.0,
    ):
        self.position = position
        self.w = w
        self.h = h
        self.corner_radius = corner_radius.or_else(0.0)

    def __init__(
        out self,
        position: Point2D,
        w: Int,
        h: Int,
        *,
        corner_radius: _OptionalFloat64 = 0.0,
    ):
        self = Rectangle(
            position, Float64(w), Float64(h), corner_radius=corner_radius
        )

    def __eq__(self, other: Rectangle) -> Bool:
        return (
            self.position == other.position
            and self.w == other.w
            and self.h == other.h
            and self.corner_radius == other.corner_radius
        )

    def __ne__(self, other: Rectangle) -> Bool:
        return not (self == other)

    def write_to[W: Writer](self, mut writer: W):
        writer.write(
            "Rectangle(position=",
            self.position,
            ", w=",
            self.w,
            ", h=",
            self.h,
        )
        if self.corner_radius != 0.0:
            writer.write(", corner_radius=", self.corner_radius)
        writer.write(")")

    def center(self) -> Point2D:
        return self.position

    def area(self) -> Float64:
        var r = self._radius()
        return self.w * self.h - (4.0 - PI) * r * r

    def bounds(self) -> Rectangle:
        """The tightest axis-aligned rectangle around this one: itself,
        sharp, since rounding never pulls in an edge's middle."""
        return Rectangle(self.position, self.w, self.h)

    def closest_point(self, p: Point2D) -> Point2D:
        var r = self._radius()
        if r > 0.0:
            return _rounded_closest(self._inner().closest_point(p), p, r)
        return Point2D(
            max(self.left(), min(p.x, self.right())),
            max(self.bottom(), min(p.y, self.top())),
        )

    def left(self) -> Float64:
        return self.position.x - self.w / 2.0

    def right(self) -> Float64:
        return self.position.x + self.w / 2.0

    def bottom(self) -> Float64:
        return self.position.y - self.h / 2.0

    def top(self) -> Float64:
        return self.position.y + self.h / 2.0

    def contains(self, p: Point2D) -> Bool:
        var r = self._radius()
        if r > 0.0:
            return _distance_squared(self._inner().closest_point(p), p) <= r * r
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

    # A rounded rectangle holds the rest as its outline polygon, and a
    # rounded shape is tested as its own.
    def contains(self, s: Sector) -> Bool:
        if self._radius() > 0.0:
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
        if self._radius() > 0.0:
            return self._outline().contains(e)
        return self.contains(e.bounds())

    def draw_to[T: DrawTarget](self, mut target: T):
        target._rectangle(self)

    def move_to(self, position: Point2D) -> Self:
        var moved = self.copy()
        moved.position = position
        return moved^

    def translate(self, delta: Vector2D) -> Self:
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
        return rect_corner_radius(self.corner_radius, self.w, self.h)

    def _inner(self) -> Rectangle:
        """The sharp rectangle every edge moves in to by the radius: the
        rounded one is the points within the radius of it."""
        var r = self._radius()
        return Rectangle(self.position, self.w - 2.0 * r, self.h - 2.0 * r)

    def _outline(self) -> Polygon:
        return _rounded_outline(
            self._inner()._points(), self._points(), self._radius()
        )

    def _points(self) -> Array[Point2D, 4]:
        return [
            Point2D(self.left(), self.bottom()),
            Point2D(self.right(), self.bottom()),
            Point2D(self.right(), self.top()),
            Point2D(self.left(), self.top()),
        ]

    def _holds_strictly(self, p: Point2D) -> Bool:
        """Whether everything close round `p` is inside: inside, and off the
        boundary."""
        return (
            self.left() < p.x < self.right()
            and self.bottom() < p.y < self.top()
        )
