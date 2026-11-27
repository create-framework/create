from std.math import cos, sin, sqrt
from create.math import PI, TAU, Number, Point, Vector
from .bezier import _curve_segments
from ._overlap import _regions_overlap
from .curve import Curve
from .shape import Shape
from ._shared import _distance_squared, _swapped
from .capsule import Capsule
from .circle import Circle
from .line import Line
from .polygon import Polygon
from .rectangle import Rectangle
from .sector import Sector
from .triangle import Triangle


comptime _ELLIPSE_OUTLINE_SEGMENTS = 224
"""How many chords an ellipse's outline polygon has, a multiple of four so a
vertex lands on each end of both axes. Taken evenly in the angle of
`(cos t, sin t)`, each chord sits inside the ellipse by at most
`max(width, height) / 2 * (TAU / 224)^2 / 8`: within 1e-4 of its larger
side, as a curve is followed."""

comptime _ELLIPSE_ROOT_STEPS = 1100
"""The most halvings `_ellipse_root` takes. It stops once the midpoint
rounds to an end, which a `Float64` reaches within 53 plus its exponent range
(1022) of them, so this is never the limit in practice."""


def _ellipse_root(r0: Float64, z0: Float64, z1: Float64, g: Float64) -> Float64:
    """The root of `(r0 z0 / (s + r0))^2 + (z1 / (s + 1))^2 = 1` for
    `s > -1`, by bisection: the one parameter of the closest point on an
    ellipse (Eberly, "Distance from a Point to an Ellipse"). The function
    falls as `s` grows, from above 1 just past -1, so the root is bracketed
    by `z1 - 1` and the length of `(r0 z0, z1)` less 1."""
    var n0 = r0 * z0
    var s0 = z1 - 1.0
    var s1 = 0.0 if g < 0.0 else sqrt(n0 * n0 + z1 * z1) - 1.0
    var s = 0.0
    for _ in range(_ELLIPSE_ROOT_STEPS):
        s = (s0 + s1) / 2.0
        if s == s0 or s == s1:
            break
        var ratio0 = n0 / (s + r0)
        var ratio1 = z1 / (s + 1.0)
        var value = ratio0 * ratio0 + ratio1 * ratio1 - 1.0
        if value > 0.0:
            s0 = s
        elif value < 0.0:
            s1 = s
        else:
            break
    return s


def _closest_on_ellipse(a: Float64, b: Float64, p: Point) -> Point:
    """The point of the curve `x^2/a^2 + y^2/b^2 = 1` nearest `p`, both
    relative to the ellipse's centre, from inside or out; `a` and `b` are
    positive. Accurate to rounding: the closest point's one unknown is the
    root `_ellipse_root` brackets, and each quadrant is a reflection of the
    first."""
    if a < b:
        return _swapped(_closest_on_ellipse(b, a, _swapped(p)))
    var y0 = abs(p.x)
    var y1 = abs(p.y)
    var x0: Float64
    var x1: Float64
    if y1 > 0.0:
        if y0 > 0.0:
            var z0 = y0 / a
            var z1 = y1 / b
            var g = z0 * z0 + z1 * z1 - 1.0
            if g != 0.0:
                var r0 = (a / b) * (a / b)
                var s = _ellipse_root(r0, z0, z1, g)
                x0 = r0 * y0 / (s + r0)
                x1 = y1 / (s + 1.0)
            else:
                x0 = y0
                x1 = y1
        else:
            x0 = 0.0
            x1 = b
    else:
        # On the major axis: inside the centre of curvature at its end, the
        # nearest points are off the axis, a mirrored pair; past it, the end.
        var numerator = a * y0
        var denominator = a * a - b * b
        if numerator < denominator:
            var along = numerator / denominator
            x0 = a * along
            x1 = b * sqrt(1.0 - along * along)
        else:
            x0 = a
            x1 = 0.0
    return Point(x0 if p.x >= 0.0 else -x0, x1 if p.y >= 0.0 else -x1)


struct Ellipse(
    Copyable, Equatable, ImplicitlyCopyable, Movable, Shape, Writable
):
    """An axis-aligned ellipse: `center`, `area`, `bounds`, `closest_point`,
    `contains`, `move_to`, `translate`.

    `position` is the centre and `width`/`height` the full width and height,
    as for `Rectangle`, whose `bounds()` it fills; a turned ellipse is drawn
    through `canvas.transform`. With `width == height` it is the circle of
    diameter `width`, and every test agrees with that `Circle`'s.

    `contains` treats the boundary as inside, and `closest_point` returns
    the query point itself when it is inside. A zero `width` or `height`
    collapses the ellipse to the segment (or point) its `bounds()` is, and
    every test treats it as that zero-size `Rectangle`, exactly.
    `width`/`height` are assumed non-negative.

    An ellipse is a circle stretched along its axes, so a test against a
    shape that stretching keeps a shape of its kind (a point, a `Line`,
    a sharp `Rectangle`, `Triangle` or `Polygon`) runs exactly on the
    unit circle with the other shape mapped there. Against a `Circle` or
    another `Ellipse` it is exact too, through the closest point on the
    ellipse, accurate to rounding. Against a `Sector` and its arc, the
    ellipse stands in as its outline polygon, within 1e-4 of its larger
    side; a curve is followed as closely, and a rounded shape is tested as
    its own outline, as everywhere.
    """

    var position: Point
    var width: Float64
    var height: Float64

    def __init__(out self, position: Point, width: Number, height: Number):
        self.position = position
        self.width = Float64(width)
        self.height = Float64(height)

    def __eq__(self, other: Ellipse) -> Bool:
        return (
            self.position == other.position
            and self.width == other.width
            and self.height == other.height
        )

    def __ne__(self, other: Ellipse) -> Bool:
        return not (self == other)

    def write_to[W: Writer](self, mut writer: W):
        writer.write(
            "Ellipse(position=",
            self.position,
            ", width=",
            self.width,
            ", height=",
            self.height,
            ")",
        )

    def center(self) -> Point:
        """Its centre: `position`."""
        return self.position

    def area(self) -> Float64:
        """How much room it covers: π times half its width times half its
        height."""
        return PI * self.width * self.height / 4.0

    def bounds(self) -> Rectangle:
        """The tightest axis-aligned rectangle around the ellipse."""
        return Rectangle(self.position, self.width, self.height)

    def closest_point(self, p: Point) -> Point:
        """Its point nearest `p`: `p` itself when inside, otherwise the
        nearest point on its edge."""
        if self._is_flat():
            return self.bounds().closest_point(p)
        if self.contains(p):
            return p
        return self._closest_on_boundary(p)

    def contains(self, p: Point) -> Bool:
        """Whether `p` is inside, its boundary included."""
        if self._is_flat():
            return self.bounds().contains(p)
        var q = self._to_unit(p)
        return q.x * q.x + q.y * q.y <= 1.0

    # An ellipse is convex, so it holds a straight-edged shape exactly when
    # it holds its corners. Collapsed, it is its bounds, and a rounded shape
    # is tested as its outline polygon.
    def contains(self, r: Rectangle) -> Bool:
        """Whether the whole of the other shape, or the line, lies inside, its
        boundary included. Rounded corners count, on both."""
        if self._is_flat():
            return self.bounds().contains(r)
        if r._radius() > 0.0:
            return self.contains(r._outline())
        for p in r._points():
            if not self.contains(p):
                return False
        return True

    def contains(self, c: Circle) -> Bool:
        """Whether `c` is inside: its centre is, and no nearer the curve
        than its radius."""
        if self._is_flat():
            return self.bounds().contains(c)
        if not self.contains(c.position):
            return False
        var edge = self._closest_on_boundary(c.position)
        return _distance_squared(edge, c.position) >= c.radius * c.radius

    def contains(self, t: Triangle) -> Bool:
        """Whether the whole of the other shape, or the line, lies inside, its
        boundary included. Rounded corners count, on both."""
        if self._is_flat():
            return self.bounds().contains(t)
        if t._radius() > 0.0:
            return self.contains(t._outline())
        for p in t._points():
            if not self.contains(p):
                return False
        return True

    def contains(self, l: Line) -> Bool:
        """Whether the whole of the other shape, or the line, lies inside, its
        boundary included. Rounded corners count, on both."""
        if self._is_flat():
            return self.bounds().contains(l)
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
        """Whether `s` is inside: its tip and its arc are, since every point
        of a sector lies between the two and the ellipse is convex."""
        if self._is_flat():
            return self.bounds().contains(s)
        if s._is_rounded():
            return self.contains(s._outline())
        return self.contains(s.position) and self.contains(s.arc())

    def contains(self, p: Polygon) -> Bool:
        """Whether the whole of the other shape, or the line, lies inside, its
        boundary included. Rounded corners count, on both."""
        if self._is_flat():
            return self.bounds().contains(p)
        if p._is_rounded():
            return self.contains(p._outline())
        for v in p.vertices:
            if not self.contains(v):
                return False
        return True

    def contains(self, other: Ellipse) -> Bool:
        """Whether `other` is inside: with `other` mapped onto the unit
        circle, this one, mapped alike, still an ellipse, holds that
        circle."""
        if other._is_flat():
            return self.contains(other.bounds())
        if self._is_flat():
            return self.bounds().contains(other)
        return other._to_unit(self).contains(_UNIT_CIRCLE)

    def contains(self, c: Capsule) -> Bool:
        """Whether the whole of the other shape, or the line, lies inside, its
        boundary included. Rounded corners count, on both."""
        # Convex, so it holds the capsule when it holds the discs at both
        # ends, whose hull the capsule is.
        for end in c._ends():
            if not self.contains(end):
                return False
        return True

    def overlaps(self, other: Rectangle) -> Bool:
        """Whether this and `other` share any point, their boundaries
        included: shapes that only touch, along an edge or at a corner,
        overlap. Symmetric: `other.overlaps(self)` gives the same answer."""
        return _regions_overlap(self, other)

    def overlaps(self, other: Circle) -> Bool:
        """Whether this and `other` share any point, their boundaries
        included: shapes that only touch, along an edge or at a corner,
        overlap. Symmetric: `other.overlaps(self)` gives the same answer."""
        return _regions_overlap(self, other)

    def overlaps(self, other: Ellipse) -> Bool:
        """Whether this and `other` share any point, their boundaries
        included: shapes that only touch, along an edge or at a corner,
        overlap. Symmetric: `other.overlaps(self)` gives the same answer."""
        return _regions_overlap(self, other)

    def overlaps(self, other: Capsule) -> Bool:
        """Whether this and `other` share any point, their boundaries
        included: shapes that only touch, along an edge or at a corner,
        overlap. Symmetric: `other.overlaps(self)` gives the same answer."""
        return _regions_overlap(other, self)

    def overlaps(self, other: Triangle) -> Bool:
        """Whether this and `other` share any point, their boundaries
        included: shapes that only touch, along an edge or at a corner,
        overlap. Symmetric: `other.overlaps(self)` gives the same answer."""
        return _regions_overlap(self, other)

    def overlaps(self, other: Sector) -> Bool:
        """Whether this and `other` share any point, their boundaries
        included: shapes that only touch, along an edge or at a corner,
        overlap. Symmetric: `other.overlaps(self)` gives the same answer."""
        return _regions_overlap(self, other)

    def overlaps(self, other: Polygon) -> Bool:
        """Whether this and `other` share any point, their boundaries
        included: shapes that only touch, along an edge or at a corner,
        overlap. Symmetric: `other.overlaps(self)` gives the same answer."""
        return _regions_overlap(self, other)

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

    def _is_flat(self) -> Bool:
        """Whether the ellipse has collapsed to a segment or a point."""
        return self.width <= 0.0 or self.height <= 0.0

    def _closest_on_boundary(self, p: Point) -> Point:
        """The point of the curve nearest `p`, from inside or out. Not
        flat."""
        var near = _closest_on_ellipse(
            self.width / 2.0,
            self.height / 2.0,
            Point(p.x - self.position.x, p.y - self.position.y),
        )
        return self.position + Vector(near)

    def _vertices(self, segments: Int) -> List[Point]:
        """`segments` points on the curve, evenly spaced in the angle of
        `(cos t, sin t)` and counter-clockwise from the right end of the
        width: the outline polygon's vertices. A multiple of four lands one
        on each end of both axes, so their bounds are the ellipse's."""
        var a = self.width / 2.0
        var b = self.height / 2.0
        var points = List[Point](capacity=segments)
        for i in range(segments):
            var t = TAU * Float64(i) / Float64(segments)
            points.append(self.position + Vector(a * cos(t), b * sin(t)))
        return points^

    def _outline(self) -> Polygon:
        """The ellipse as a polygon inside it, within 1e-4 of its larger
        side."""
        return Polygon(self._vertices(_ELLIPSE_OUTLINE_SEGMENTS))

    # The map taking this ellipse onto the unit circle about the origin: a
    # translation and a scale along each axis, so it keeps a line a line,
    # an axis-aligned rectangle one, and an axis-aligned ellipse one. Only
    # for an ellipse that is not flat, and a sharp shape.
    def _to_unit(self, p: Point) -> Point:
        return Point(
            (p.x - self.position.x) * 2.0 / self.width,
            (p.y - self.position.y) * 2.0 / self.height,
        )

    def _to_unit(self, l: Line) -> Line:
        return Line(self._to_unit(l.start), self._to_unit(l.end))

    def _to_unit(self, r: Rectangle) -> Rectangle:
        return Rectangle(
            self._to_unit(r.position),
            r.width * 2.0 / self.width,
            r.height * 2.0 / self.height,
        )

    def _to_unit(self, t: Triangle) -> Triangle:
        return Triangle(
            self._to_unit(t.a), self._to_unit(t.b), self._to_unit(t.c)
        )

    def _to_unit(self, p: Polygon) -> Polygon:
        var vertices = List[Point](capacity=len(p.vertices))
        for v in p.vertices:
            vertices.append(self._to_unit(v))
        return Polygon(vertices^)

    def _to_unit(self, e: Ellipse) -> Ellipse:
        return Ellipse(
            self._to_unit(e.position),
            e.width * 2.0 / self.width,
            e.height * 2.0 / self.height,
        )


comptime _UNIT_CIRCLE = Circle(Point(0.0, 0.0), 1.0)
"""Where `Ellipse._to_unit` takes its ellipse."""
