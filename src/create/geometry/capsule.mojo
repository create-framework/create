from std.math import atan2, min, sqrt
from create.math import PI, Point, Vector
from .bezier import _curve_segments
from ._overlap import _regions_overlap
from .drawable import Curve, DrawTarget, Shape
from ._collider import _Collider, _Core, _contains, _overlaps
from ._shared import _distance_squared, _unit
from .arc import Arc
from .circle import Circle
from .ellipse import Ellipse
from .line import Line
from .polygon import Polygon
from .rectangle import Rectangle
from .sector import Sector
from .triangle import Triangle


struct Capsule(
    Copyable,
    Equatable,
    ImplicitlyCopyable,
    Movable,
    Shape,
    Writable,
    _Collider,
):
    """A capsule: every point within `radius` of the segment from `start` to
    `end` -- a rectangle along the segment, capped by a half disc at each
    end. `center`, `area`, `bounds`, `closest_point`, `contains`,
    `move_to`, `translate`.

    Like a `Line`, it lies along any direction and is placed by its ends,
    so `center()` is the segment's midpoint and `move_to` moves that. A
    stadium is also a `Rectangle` with `corner_radius=height / 2`, turned by
    `rotation=angle`; a capsule is the one placed by its ends, the usual round
    collider for a moving body. With `start == end` it is the `Circle` of
    `radius` there, and a zero `radius` collapses it to the segment.

    `contains` treats the boundary as inside, and `closest_point` returns
    the query point itself when it is inside. Every test is a distance from
    the segment, so they are exact: against a point, a line, a circle,
    another capsule, an arc, an ellipse and every straight-edged shape,
    rounded rectangles and triangles included. A shape inside it only needs
    its corners (or its ends' discs) inside, since a capsule is convex.
    Holding a `Sector`'s arc or an `Ellipse`, it follows them as a curve is
    followed, within 1e-4 of their size, and a rounded polygon or sector is
    tested as its outline, as everywhere. `radius` is assumed non-negative.
    """

    var start: Point
    var end: Point
    var radius: Float64

    def __init__(out self, start: Point, end: Point, radius: Float64):
        self.start = start
        self.end = end
        self.radius = radius

    def __init__(out self, start: Point, end: Point, radius: Int):
        self = Capsule(start, end, Float64(radius))

    def __eq__(self, other: Capsule) -> Bool:
        return (
            self.start == other.start
            and self.end == other.end
            and self.radius == other.radius
        )

    def __ne__(self, other: Capsule) -> Bool:
        return not (self == other)

    def write_to[W: Writer](self, mut writer: W):
        writer.write(
            "Capsule(start=",
            self.start,
            ", end=",
            self.end,
            ", radius=",
            self.radius,
            ")",
        )

    def center(self) -> Point:
        return self._spine().midpoint()

    def area(self) -> Float64:
        return (
            2.0 * self.radius * self._spine().length()
            + PI * self.radius * self.radius
        )

    def bounds(self) -> Rectangle:
        """The tightest axis-aligned rectangle around the capsule: the
        segment's, grown by `radius` all round."""
        return Rectangle(
            self.center(),
            abs(self.end.x - self.start.x) + 2.0 * self.radius,
            abs(self.end.y - self.start.y) + 2.0 * self.radius,
        )

    def closest_point(self, p: Point) -> Point:
        var q = self._spine().closest_point(p)
        var d = p - q
        var distance_squared = d.dot(d)
        if distance_squared <= self.radius * self.radius:
            return p
        return q + d * (self.radius / sqrt(distance_squared))

    def contains(self, p: Point) -> Bool:
        return _distance_squared(self._spine().closest_point(p), p) <= (
            self.radius * self.radius
        )

    # A `Circle`, `Capsule`, `Rectangle` or `Triangle`, rounded or not, or
    # a `Line`, is a convex core grown by a radius, and is held exactly when
    # a disc of its radius round every corner of its core is (`_contains`).
    def contains(self, l: Line) -> Bool:
        return _contains(self, l)

    def contains(self, radius: Rectangle) -> Bool:
        return _contains(self, radius)

    def contains(self, c: Circle) -> Bool:
        return _contains(self, c)

    def contains(self, t: Triangle) -> Bool:
        return _contains(self, t)

    def contains(self, other: Capsule) -> Bool:
        return _contains(self, other)

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
        of a sector lies between the two and the capsule is convex."""
        if s._is_rounded():
            return self.contains(s._outline())
        return self.contains(s.position) and self.contains(s.arc())

    def contains(self, p: Polygon) -> Bool:
        if p._is_rounded():
            return self.contains(p._outline())
        for v in p.vertices:
            if not self.contains(v):
                return False
        return True

    def contains(self, e: Ellipse) -> Bool:
        """Whether `e` is inside, its curve followed by its outline
        polygon."""
        if e._is_flat():
            return self.contains(e.bounds())
        return self.contains(e._outline())

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
        return _regions_overlap(self, other)

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
        return _regions_overlap(self, other)

    def overlaps(self, other: Polygon) -> Bool:
        """Whether this and `other` share any point, their boundaries
        included: shapes that only touch, along an edge or at a corner,
        overlap. Symmetric: `other.overlaps(self)` gives the same answer."""
        return _regions_overlap(self, other)

    def draw_to[T: DrawTarget](self, mut target: T):
        target._capsule(self)

    def move_to(self, position: Point) -> Self:
        return self.translate(position - self.center())

    def translate(self, delta: Vector) -> Self:
        var moved = self.copy()
        moved.start = moved.start + delta
        moved.end = moved.end + delta
        return moved^

    comptime _corner_count = 2

    def _core(self) -> _Core[Self._corner_count]:
        """The spine, grown by the radius."""
        return _Core[2]([self.start, self.end], self.radius)

    def _spine(self) -> Line:
        """The segment the capsule is the points within `radius` of."""
        return Line(self.start, self.end)

    def _ends(self) -> Array[Circle, 2]:
        """The discs at either end, whose hull the capsule is: a convex
        region holds the capsule when it holds both."""
        return [Circle(self.start, self.radius), Circle(self.end, self.radius)]

    def _direction(self) -> Vector:
        """The unit direction from `start` to `end`, +x when they meet."""
        var along = self.end - self.start
        var length = along.magnitude()
        if length == 0.0:
            return Vector(1.0, 0.0)
        return along * (1.0 / length)

    def _sides(self) -> List[Line]:
        """The two straight edges, counter-clockwise round the capsule."""
        var u = self._direction()
        var n = Vector(-u.y, u.x) * self.radius
        return [
            Line(self.start - n, self.end - n),
            Line(self.end + n, self.start + n),
        ]

    def _caps(self) -> List[Arc]:
        """The two half circles, counter-clockwise round the capsule: about
        `end`, then about `start`."""
        var u = self._direction()
        var angle = atan2(u.y, u.x)
        return [
            Arc(self.end, self.radius, angle - PI / 2.0, PI),
            Arc(self.start, self.radius, angle + PI / 2.0, PI),
        ]

    def _vertices(self, steps: Int) -> List[Point]:
        """The capsule's outline as a polygon, counter-clockwise: each half
        circle in `steps` chords, its ends on the straight edges. With the
        ends meeting, the circle once round."""
        var u = self._direction()
        var angle = atan2(u.y, u.x)
        var points = List[Point](capacity=2 * steps + 2)
        for i in range(steps + 1):
            var t = angle - PI / 2.0 + PI * Float64(i) / Float64(steps)
            points.append(self.end + _unit(t) * self.radius)
        var first = 1 if self.start == self.end else 0
        var last = steps - 1 if self.start == self.end else steps
        for i in range(first, last + 1):
            var t = angle + PI / 2.0 + PI * Float64(i) / Float64(steps)
            points.append(self.start + _unit(t) * self.radius)
        return points^

    def _holds_strictly(self, p: Point) -> Bool:
        """Whether everything close round `p` is inside: inside, and off the
        boundary."""
        return _distance_squared(self._spine().closest_point(p), p) < (
            self.radius * self.radius
        )


# How far a segment -- a capsule's spine, or a `Line` meeting a capsule --
# comes to each kind of shape: zero where they meet, so a capsule overlaps a
# shape exactly when its spine comes within its radius. Two convex pieces
# that don't meet are nearest at an end of one, or where the gap between
# them is perpendicular to both; for a segment and a circle's arc or an
# ellipse, those are the curve's points facing straight across the
# segment, which each function tries alongside the ends.
def _spine_distance(l: Line, p: Point) -> Float64:
    return sqrt(_distance_squared(l.closest_point(p), p))


def _spine_distance(l: Line, other: Line) -> Float64:
    if l.intersects(other):
        return 0.0
    return min(
        min(_spine_distance(l, other.start), _spine_distance(l, other.end)),
        min(_spine_distance(other, l.start), _spine_distance(other, l.end)),
    )


def _across(l: Line, p: Point) -> Float64:
    """The distance from `p` straight across to the segment, or the
    largest `Float64` when the perpendicular foot falls off it."""
    var along = l.end - l.start
    var length_squared = along.dot(along)
    if length_squared == 0.0:
        return Float64.MAX
    var t = (p - l.start).dot(along) / length_squared
    if t < 0.0 or t > 1.0:
        return Float64.MAX
    return sqrt(_distance_squared(l.start + along * t, p))


def _spine_distance(l: Line, a: Arc) -> Float64:
    if l.intersects(a):
        return 0.0
    var best = min(
        min(
            sqrt(_distance_squared(a.closest_point(l.start), l.start)),
            sqrt(_distance_squared(a.closest_point(l.end), l.end)),
        ),
        min(_spine_distance(l, a.at(0.0)), _spine_distance(l, a.at(1.0))),
    )
    var along = l.end - l.start
    var length = along.magnitude()
    if length > 0.0:
        var n = Vector(-along.y, along.x) * (a.radius / length)
        for k in range(2):
            var p = a.position + (n if k == 0 else -n)
            if a._spans(p):
                best = min(best, _across(l, p))
    return best


def _spine_distance(l: Line, e: Ellipse) -> Float64:
    if e._is_flat():
        var b = e.bounds()
        return _spine_distance(
            l, Line((b.left(), b.bottom()), (b.right(), b.top()))
        )
    if l.intersects(e):
        return 0.0
    var best = min(
        sqrt(_distance_squared(e.closest_point(l.start), l.start)),
        sqrt(_distance_squared(e.closest_point(l.end), l.end)),
    )
    var along = l.end - l.start
    var a = e.width / 2.0
    var b = e.height / 2.0
    # The points of the curve whose normal is the segment's: the support
    # points across it, `(a^2 nx, b^2 ny)` scaled onto the curve.
    var reach = sqrt(a * a * along.y * along.y + b * b * along.x * along.x)
    if reach > 0.0:
        var offset = Vector(-a * a * along.y, b * b * along.x) * (1.0 / reach)
        for k in range(2):
            best = min(
                best, _across(l, e.position + (offset if k == 0 else -offset))
            )
    return best


def _spine_distance(l: Line, p: Polygon) -> Float64:
    if p._is_rounded():
        return _spine_distance(l, p._outline())
    if l.intersects(p):
        return 0.0
    var best = Float64.MAX
    for i in range(len(p.vertices)):
        best = min(best, _spine_distance(l, p._edge(i)))
    return best


def _spine_distance(l: Line, s: Sector) -> Float64:
    if s._is_rounded():
        return _spine_distance(l, s._outline())
    if l.intersects(s):
        return 0.0
    var radii = s._radii()
    return min(
        min(_spine_distance(l, radii[0]), _spine_distance(l, radii[1])),
        _spine_distance(l, s.arc()),
    )
