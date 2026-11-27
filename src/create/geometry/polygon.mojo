from std.math import min, max
from create.math import PI, TAU, Point, Vector
from create.math import OptionalNumber
from ._fillet import rounded_vertices
from .bezier import _curve_segments
from ._overlap import _regions_overlap
from .curve import Curve
from .shape import Shape
from ._shared import (
    _FILLET_STEP,
    _arc_middles,
    _circle_crossings,
    _closed_outline,
    _closest_on_segment,
    _cross,
    _cut_at_circle,
    _cut_at_line,
    _distance_squared,
    _orientation,
    _point_on_segment,
    _segment_middles,
    _swapped,
    _unit,
    _winds,
)
from .arc import Arc
from .capsule import Capsule
from .circle import Circle
from .ellipse import Ellipse, _UNIT_CIRCLE
from .line import Line
from .rectangle import Rectangle
from .sector import Sector
from .triangle import Triangle


struct Polygon(Copyable, Equatable, Movable, Shape, Writable):
    """A polygon through `vertices`, in order, closed back to the first:
    `regular`, `star`, `center`, `area`, `bounds`, `closest_point`,
    `contains`, `move_to`, `translate`.

    Any vertices make a polygon, concave or crossing itself. What is inside
    follows the nonzero rule: a point is inside when the edges wind round
    it, either way, so a pentagram given as five crossing vertices is solid
    through its middle. Vertex winding does not matter, and the boundary
    counts as inside. With fewer than three vertices, or all of them in
    line, the polygon collapses to its edges.

    It is a `Shape`: in every `overlaps` pair, `contains` both ways, and
    met by `Line.intersects` and `Arc.intersects`.

    Like a `Triangle`'s, the fields are the vertices and `center()` (the
    centroid) is derived; `move_to` moves the centroid. The centroid and
    `area` are those of a simple polygon -- one whose edges do not cross.

    `corner_radius` rounds every corner, as `canvas.polygon` draws it, and
    every test here sees the rounded shape. Each corner is clamped on its
    own so its rounding takes at most half of either edge beside it: a
    sharp tip rounds less without holding back the rest. A concave corner
    rounds too, filling its notch. The tests use the rounded outline with
    each fillet flattened, so a point within about 0.1% of the radius of a
    fillet may fall either way.
    """

    var vertices: List[Point]
    var corner_radius: Float64
    """How far each corner is rounded; 0 is sharp."""

    def __init__(
        out self, *vertices: Point, corner_radius: OptionalNumber = 0.0
    ):
        self.vertices = List[Point](capacity=len(vertices))
        for v in vertices:
            self.vertices.append(v)
        self.corner_radius = corner_radius.or_else(0.0)

    def __init__(
        out self,
        var vertices: List[Point],
        *,
        corner_radius: OptionalNumber = 0.0,
    ):
        self.vertices = vertices^
        self.corner_radius = corner_radius.or_else(0.0)

    @staticmethod
    def regular(
        position: Point,
        radius: Float64,
        sides: Int,
        start_angle: Float64 = TAU / 4.0,
        *,
        corner_radius: OptionalNumber = 0.0,
    ) -> Polygon:
        """A regular polygon of `sides` vertices on the circle around
        `position` with radius `radius`, the first at `start_angle` (radians
        counter-clockwise from +x; straight up by default), the rest
        following counter-clockwise."""
        var vertices = List[Point](capacity=max(sides, 0))
        for i in range(sides):
            var angle = start_angle + TAU * Float64(i) / Float64(sides)
            vertices.append(position + _unit(angle) * radius)
        return Polygon(vertices^, corner_radius=corner_radius)

    @staticmethod
    def regular(
        position: Point,
        radius: Int,
        sides: Int,
        start_angle: Float64 = TAU / 4.0,
        *,
        corner_radius: OptionalNumber = 0.0,
    ) -> Polygon:
        """A regular polygon of `sides` vertices on the circle around
        `position` with radius `radius`, the first at `start_angle` (radians
        counter-clockwise from +x; straight up by default), the rest
        following counter-clockwise."""
        return Polygon.regular(
            position,
            Float64(radius),
            sides,
            start_angle,
            corner_radius=corner_radius,
        )

    @staticmethod
    def star(
        position: Point,
        radius: Float64,
        inner_radius: Float64,
        tips: Int,
        start_angle: Float64 = TAU / 4.0,
        *,
        corner_radius: OptionalNumber = 0.0,
    ) -> Polygon:
        """A star of `tips` points about `position`: its tips on `radius`, the
        first at `start_angle` (straight up by default), and between each two
        tips a vertex on `inner_radius`, halfway round. The outline does not
        cross itself, so it is a simple polygon."""
        var vertices = List[Point](capacity=max(2 * tips, 0))
        for i in range(2 * tips):
            var angle = start_angle + PI * Float64(i) / Float64(tips)
            vertices.append(
                position
                + _unit(angle) * (radius if i % 2 == 0 else inner_radius)
            )
        return Polygon(vertices^, corner_radius=corner_radius)

    @staticmethod
    def star(
        position: Point,
        radius: Int,
        inner_radius: Int,
        tips: Int,
        start_angle: Float64 = TAU / 4.0,
        *,
        corner_radius: OptionalNumber = 0.0,
    ) -> Polygon:
        """A star of `tips` points about `position`: its tips on `radius`, the
        first at `start_angle` (straight up by default), and between each two
        tips a vertex on `inner_radius`, halfway round. The outline does not
        cross itself, so it is a simple polygon."""
        return Polygon.star(
            position,
            Float64(radius),
            Float64(inner_radius),
            tips,
            start_angle,
            corner_radius=corner_radius,
        )

    def __eq__(self, other: Polygon) -> Bool:
        return (
            self.vertices == other.vertices
            and self.corner_radius == other.corner_radius
        )

    def __ne__(self, other: Polygon) -> Bool:
        return not (self == other)

    def write_to[W: Writer](self, mut writer: W):
        writer.write("Polygon(vertices=[")
        for i in range(len(self.vertices)):
            if i > 0:
                writer.write(", ")
            writer.write(self.vertices[i])
        writer.write("]")
        if self.corner_radius != 0.0:
            writer.write(", corner_radius=", self.corner_radius)
        writer.write(")")

    def center(self) -> Point:
        """The centroid of the enclosed area; with no area, the mean of the
        vertices (the origin for none)."""
        if self._is_rounded():
            return self._outline().center()
        var n = len(self.vertices)
        if n == 0:
            return Point(0.0, 0.0)
        var area2 = self._signed_area2()
        if area2 == 0.0:
            var sx = 0.0
            var sy = 0.0
            for v in self.vertices:
                sx += v.x
                sy += v.y
            return Point(sx / Float64(n), sy / Float64(n))
        var cx = 0.0
        var cy = 0.0
        for i in range(n):
            var a = self.vertices[i]
            var b = self.vertices[(i + 1) % n]
            var cross = a.x * b.y - b.x * a.y
            cx += (a.x + b.x) * cross
            cy += (a.y + b.y) * cross
        return Point(cx / (3.0 * area2), cy / (3.0 * area2))

    def _signed_area2(self) -> Float64:
        """Twice the signed area by the shoelace formula: positive for
        counter-clockwise vertices."""
        var n = len(self.vertices)
        var sum = 0.0
        for i in range(n):
            var a = self.vertices[i]
            var b = self.vertices[(i + 1) % n]
            sum += a.x * b.y - b.x * a.y
        return sum

    def area(self) -> Float64:
        """How much room it encloses, its rounded corners taken into account."""
        if self._is_rounded():
            return self._outline().area()
        return abs(self._signed_area2()) / 2.0

    def bounds(self) -> Rectangle:
        """The tightest axis-aligned rectangle around the polygon; a
        zero-size one at the origin for none."""
        if self._is_rounded():
            return self._outline().bounds()
        if len(self.vertices) == 0:
            return Rectangle(Point(0.0, 0.0), 0.0, 0.0)
        var lo = self.vertices[0]
        var hi = self.vertices[0]
        for v in self.vertices:
            lo = Point(min(lo.x, v.x), min(lo.y, v.y))
            hi = Point(max(hi.x, v.x), max(hi.y, v.y))
        return Rectangle(lo.lerp(hi, 0.5), hi.x - lo.x, hi.y - lo.y)

    def closest_point(self, p: Point) -> Point:
        """`p` itself when inside, else the nearest point on an edge. A
        polygon with no vertices has no points, and returns `p`."""
        if self._is_rounded():
            return self._outline().closest_point(p)
        if len(self.vertices) == 0 or self.contains(p):
            return p
        var best = self.vertices[0]
        for i in range(len(self.vertices)):
            var e = self._edge(i)
            var q = _closest_on_segment(p, e.start, e.end)
            if _distance_squared(p, q) < _distance_squared(p, best):
                best = q
        return best

    def contains(self, p: Point) -> Bool:
        """Whether `p` is inside, its boundary included."""
        if self._is_rounded():
            return self._outline().contains(p)
        for i in range(len(self.vertices)):
            var e = self._edge(i)
            if _point_on_segment(p, e.start, e.end):
                return True
        return self._winding(p) != 0

    # A polygon may be concave, so a shape with its outline inside can
    # still bridge a notch; and it may wind round a hole, which a shape
    # can enclose with its whole outline inside. So it holds a shape when
    # it holds the shape's outline -- cut where it crosses the lines of the
    # edges, the middle of every piece inside, as for `Sector` -- and no
    # edge piece strictly inside the shape has the outside along it. A
    # rounded polygon does all this as its outline.
    def contains(self, l: Line) -> Bool:
        """Whether the whole of the other shape, or the line, lies inside, its
        boundary included. Rounded corners count, on both."""
        if self._is_rounded():
            return self._outline().contains(l)
        if not (self.contains(l.start) and self.contains(l.end)):
            return False
        var edges = self._edges()
        var cuts = List[Float64]()
        for edge in edges:
            _cut_at_line(l, edge, cuts)
        # A piece along an edge is on the boundary, so inside, though its
        # computed middle may land a rounding error outside.
        for middle in _segment_middles(l, cuts^):
            if not (self.contains(middle) or _runs_along(l, middle, edges)):
                return False
        return True

    def contains[C: Curve](self, curve: C) -> Bool:
        """Whether the whole of `curve` (an `Arc`, `Bezier` or `Spline`) is
        inside: every segment of it flattened to within 1e-4 of its size,
        as `intersects` follows it, so a curve grazing the edge from inside
        is decided only that closely."""
        for segment in _curve_segments(curve):
            if not self.contains(segment):
                return False
        return True

    def contains(self, r: Rectangle) -> Bool:
        """Whether the whole of the other shape, or the line, lies inside, its
        boundary included. Rounded corners count, on both."""
        if self._is_rounded():
            return self._outline().contains(r)
        if r._radius() > 0.0:
            return self.contains(r._outline())
        var outline = _closed_outline(r._points())
        for edge in outline:
            if not self.contains(edge):
                return False
        for p in self._rim(outline, []):
            if r._holds_strictly(p):
                return False
        return True

    def contains(self, t: Triangle) -> Bool:
        """Whether the whole of the other shape, or the line, lies inside, its
        boundary included. Rounded corners count, on both."""
        if self._is_rounded():
            return self._outline().contains(t)
        if t._radius() > 0.0:
            return self.contains(t._outline())
        var outline = _closed_outline(t._points())
        for edge in outline:
            if not self.contains(edge):
                return False
        for p in self._rim(outline, []):
            if t._holds_strictly(p):
                return False
        return True

    def contains(self, c: Circle) -> Bool:
        """Whether the whole of the other shape, or the line, lies inside, its
        boundary included. Rounded corners count, on both."""
        if self._is_rounded():
            return self._outline().contains(c)
        var outline = Arc(c.position, c.radius, 0.0, TAU)
        if not self._contains_arc(outline):
            return False
        for p in self._rim([], [outline]):
            if _distance_squared(p, c.position) < c.radius * c.radius:
                return False
        return True

    def contains(self, s: Sector) -> Bool:
        """Whether the whole of the other shape, or the line, lies inside, its
        boundary included. Rounded corners count, on both."""
        if self._is_rounded():
            return self._outline().contains(s)
        if s._is_rounded():
            return self.contains(s._outline())
        var radii = s._radii()
        var outline: List[Line] = [radii[0], radii[1]]
        for radius in outline:
            if not self.contains(radius):
                return False
        if not self._contains_arc(s.arc()):
            return False
        for p in self._rim(outline, [s.arc()]):
            if s._holds_strictly(p):
                return False
        return True

    def contains(self, other: Polygon) -> Bool:
        """Whether the whole of the other shape, or the line, lies inside, its
        boundary included. Rounded corners count, on both."""
        if self._is_rounded():
            return self._outline().contains(other)
        if other._is_rounded():
            return self.contains(other._outline())
        var outline = other._edges()
        for edge in outline:
            if not self.contains(edge):
                return False
        for p in self._rim(outline, []):
            if other._holds_strictly(p):
                return False
        return True

    def contains(self, e: Ellipse) -> Bool:
        """Whether the whole of the other shape, or the line, lies inside, its
        boundary included. Rounded corners count, on both."""
        # With `e` mapped onto the unit circle, the polygon mapped alike is
        # still one.
        if self._is_rounded():
            return self._outline().contains(e)
        if e._is_flat():
            return self.contains(e.bounds())
        return e._to_unit(self).contains(_UNIT_CIRCLE)

    def contains(self, c: Capsule) -> Bool:
        """Whether the whole of the other shape, or the line, lies inside, its
        boundary included. Rounded corners count, on both."""
        if self._is_rounded():
            return self._outline().contains(c)
        if c.radius <= 0.0:
            return self.contains(c._spine())
        var sides = c._sides()
        var caps = c._caps()
        for side in sides:
            if not self.contains(side):
                return False
        for cap in caps:
            if not self._contains_arc(cap):
                return False
        for p in self._rim(sides, caps):
            if c._holds_strictly(p):
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
        return _regions_overlap(other, self)

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
        """It moved so its `center()` is at `position`; this one is
        unchanged."""
        return self.translate(position - self.center())

    def translate(self, delta: Vector) -> Self:
        """It moved by `delta`; this one is unchanged."""
        var moved = self.copy()
        for i in range(len(moved.vertices)):
            moved.vertices[i] = moved.vertices[i] + delta
        return moved^

    def _is_rounded(self) -> Bool:
        return self.corner_radius > 0.0 and len(self.vertices) >= 3

    def _outline(self) -> Polygon:
        """The rounded polygon as a sharp one, each fillet flattened."""
        return Polygon(
            rounded_vertices(self.vertices, self.corner_radius, _FILLET_STEP)
        )

    def _edge(self, i: Int) -> Line:
        """Edge `i`, from vertex `i` to the next, the last closing back to
        the first."""
        return Line(
            self.vertices[i], self.vertices[(i + 1) % len(self.vertices)]
        )

    def _boundary_meets(self, l: Line) -> Bool:
        for i in range(len(self.vertices)):
            if l.intersects(self._edge(i)):
                return True
        return False

    def _boundary_meets(self, a: Arc) -> Bool:
        for i in range(len(self.vertices)):
            if a.intersects(self._edge(i)):
                return True
        return False

    def _winding(self, p: Point) -> Int:
        """How many times the edges wind counter-clockwise round `p`,
        clockwise counting negative. Each edge counts where it crosses the
        horizontal through `p` to its right, half-open in y so a vertex on
        that line is counted once; a point on an edge gets whatever the
        rounding of the crossing gives, so `contains` settles edges first.
        """
        var w = 0
        for i in range(len(self.vertices)):
            var e = self._edge(i)
            w += _winds(e.start, e.end, p)
        return w

    def _wound_beside(self, i: Int, p: Point) -> Bool:
        """Whether the polygon is wound on both sides of edge `i` at `p`,
        a point on it but on no edge crossing it. The windings just either
        side are exact: rays from there cross the same edges as the ray
        from `p`, save that the one from the left also crosses every edge
        running along edge `i` through `p`. A horizontal edge has no left,
        so its sides are read across in y, the axes swapped."""
        var e = self._edge(i)
        var swap = e.start.y == e.end.y
        var q = _swapped(p) if swap else p
        var right = 0
        var along = 0
        for j in range(len(self.vertices)):
            var f = self._edge(j)
            var a = _swapped(f.start) if swap else f.start
            var b = _swapped(f.end) if swap else f.end
            if a.y == b.y:
                continue
            if j == i or (
                _orientation(e.start, e.end, f.start) == 0
                and _orientation(e.start, e.end, f.end) == 0
                and min(a.y, b.y) <= q.y <= max(a.y, b.y)
            ):
                along += 1 if b.y > a.y else -1
            else:
                right += _winds(a, b, q)
        return right != 0 and right + along != 0

    def _rim(self, lines: List[Line], arcs: List[Arc]) -> List[Point]:
        """The middles of the edge pieces with the outside on one side,
        each edge cut where another edge, one of `lines` or a circle of
        `arcs` crosses it -- so each piece lies wholly inside or wholly
        outside a shape with that boundary, and on one side of it or the
        other runs the outside all along.

        A piece running along one of `lines` is on that shape's boundary,
        never strictly inside it, so it is left out: its middle, computed,
        can land a rounding error inside, where a shape sharing an edge
        with this polygon would read it as held strictly. Running along is
        decided exactly, as `_cut_at_line` decides it, which also cut the
        edge at the line's ends."""
        var rim = List[Point]()
        for i in range(len(self.vertices)):
            var e = self._edge(i)
            var cuts = List[Float64]()
            for j in range(len(self.vertices)):
                if j != i:
                    _cut_at_line(e, self._edge(j), cuts)
            for l in lines:
                _cut_at_line(e, l, cuts)
            for a in arcs:
                _cut_at_circle(e, a.position, a.radius, cuts)
            for middle in _segment_middles(e, cuts^):
                if not self._wound_beside(i, middle) and not _runs_along(
                    e, middle, lines
                ):
                    rim.append(middle)
        return rim^

    def _pieces(self) -> Tuple[List[Line], List[Line]]:
        """The edges cut wherever another edge crosses them, in two lists:
        the rim, pieces with the outside along one side, then the seams,
        pieces wound on both sides, running through the inside."""
        var rim = List[Line]()
        var seams = List[Line]()
        var n = len(self.vertices)
        for i in range(n):
            var e = self._edge(i)
            var d = e.end - e.start
            if e.start == e.end:
                continue
            var cuts = List[Point]()
            for j in range(n):
                var other = self._edge(j)
                if j == i or not e.intersects(other):
                    continue
                if _cross(d, other.end - other.start) == 0.0:
                    # Running along it: cut where the other's ends fall.
                    cuts.append(other.start)
                    cuts.append(other.end)
                    continue
                # A neighbour meets the edge only at their shared vertex.
                if j == (i + 1) % n or i == (j + 1) % n:
                    continue
                # Found along the lower of the two edges, so both are cut at
                # the very same point and their pieces share their ends.
                var first = e if i < j else other
                var second = other if i < j else e
                var fraction = List[Float64]()
                _cut_at_line(first, second, fraction)
                cuts.append(
                    first.start + (first.end - first.start) * fraction[0]
                )
            # In order along the edge; there are only a handful.
            var along = List[Float64](capacity=len(cuts))
            for p in cuts:
                along.append((p - e.start).dot(d) / d.magnitude_squared())
            for k in range(1, len(cuts)):
                var m = k
                while m > 0 and along[m - 1] > along[m]:
                    along.swap_elements(m - 1, m)
                    cuts.swap_elements(m - 1, m)
                    m -= 1
            var start = e.start
            var at = 0.0
            for k in range(len(cuts) + 1):
                var end = e.end
                if k < len(cuts):
                    if along[k] <= at or along[k] >= 1.0:
                        continue
                    at = along[k]
                    end = cuts[k]
                if end == start:
                    continue
                var piece = Line(start, end)
                if self._wound_beside(i, piece.midpoint()):
                    seams.append(piece)
                else:
                    rim.append(piece)
                start = end
        return (rim^, seams^)

    def _holds_strictly(self, p: Point) -> Bool:
        """Whether everything close round `p` is inside: `p` inside and
        off the boundary, which an edge through it is only when the
        outside lies along one side of it."""
        for i in range(len(self.vertices)):
            var e = self._edge(i)
            if e.start != e.end and _point_on_segment(p, e.start, e.end):
                return self._wound_beside(i, p)
        return self._winding(p) != 0

    def _edges(self) -> List[Line]:
        var edges = List[Line](capacity=len(self.vertices))
        for i in range(len(self.vertices)):
            edges.append(self._edge(i))
        return edges^

    def _contains_arc(self, a: Arc) -> Bool:
        if not (self.contains(a.at(0.0)) and self.contains(a.at(1.0))):
            return False
        var crossings = List[Point]()
        for i in range(len(self.vertices)):
            _circle_crossings(self._edge(i), a.position, a.radius, crossings)
        for middle in _arc_middles(a, crossings):
            if not self.contains(middle):
                return False
        return True


def _runs_along(e: Line, middle: Point, lines: List[Line]) -> Bool:
    """Whether the piece of `e` with middle `middle` lies on one of
    `lines`: `e` runs along its line, by the exact test `_cut_at_line`
    makes, and the middle falls between its ends."""
    var d = e.end - e.start
    for l in lines:
        var f = l.end - l.start
        if _cross(d, f) != 0.0 or _cross(l.start - e.start, d) != 0.0:
            continue
        var along = (middle - l.start).dot(f)
        if 0.0 <= along <= f.magnitude_squared():
            return True
    return False
