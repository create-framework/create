from std.math import min, max
from create.math import Point2D
from ._shared import (
    _distance_squared,
    _orientation,
    _segments_meet,
)


# A circle, a capsule, a rectangle and a triangle, rounded or not, are each
# a convex core grown by a disc: every point within a radius of a point, a
# segment, a rectangle or a triangle. Two such shapes meet exactly when
# their cores come within the sum of the radii, and one holds the other
# exactly when it holds a disc of the other's radius round every corner of
# the other's core. So one distance between convex polygons of up to four
# corners decides every pair, a `Line` taking part as a core of radius 0.
# The corner count is a parameter, so each pair compiles to its own
# unrolled test with no branch on the kinds.
struct _Core[count: Int](Copyable, Movable):
    """A shape as the convex polygon of `corners` (a point, a segment, a
    triangle or a rectangle, in order round it) grown by `radius`: every
    point within `radius` of the polygon."""

    comptime edge_count = 1 if Self.count <= 2 else Self.count
    """A point is one edge of no length, a segment one edge; a polygon
    closes back to its first corner."""

    var corners: Array[Point2D, Self.count]
    var radius: Float64

    def __init__(
        out self, var corners: Array[Point2D, Self.count], radius: Float64
    ):
        self.corners = corners^
        self.radius = radius

    def _edge_end(self, i: Int) -> Point2D:
        return self.corners[i + 1 if i + 1 < Self.count else 0]

    def _low(self) -> Point2D:
        """The bottom-left corner of the polygon's bounds."""
        var low = self.corners[0]
        comptime for i in range(1, Self.count):
            low = Point2D(
                min(low.x, self.corners[i].x), min(low.y, self.corners[i].y)
            )
        return low

    def _high(self) -> Point2D:
        """The top-right corner of the polygon's bounds."""
        var high = self.corners[0]
        comptime for i in range(1, Self.count):
            high = Point2D(
                max(high.x, self.corners[i].x), max(high.y, self.corners[i].y)
            )
        return high

    def _has_area(self) -> Bool:
        """Whether the polygon has an inside: three corners or more, not
        all in line."""
        comptime for i in range(1, Self.count - 1):
            if (
                _orientation(
                    self.corners[0], self.corners[i], self.corners[i + 1]
                )
                != 0
            ):
                return True
        return False

    def _holds(self, p: Point2D) -> Bool:
        """Whether `p` is inside a polygon with an inside, edges included:
        on no edge's outer side, whichever way the corners run."""
        var has_negative = False
        var has_positive = False
        comptime for i in range(Self.count):
            var side = _orientation(self.corners[i], self._edge_end(i), p)
            has_negative = has_negative or side < 0
            has_positive = has_positive or side > 0
        return not (has_negative and has_positive)

    def _distance_squared_to(self, p: Point2D) -> Float64:
        """The squared distance from `p` to the polygon: 0 inside it."""
        comptime if Self.count == 1:
            return _distance_squared(p, self.corners[0])
        if self._has_area() and self._holds(p):
            return 0.0
        return self._edge_distance_squared(p)

    def _edge_distance_squared(self, p: Point2D) -> Float64:
        """The squared distance from `p` to the nearest edge."""
        var best = Float64.MAX
        comptime for i in range(Self.edge_count):
            best = min(
                best,
                _segment_distance_squared(
                    p, self.corners[i], self._edge_end(i)
                ),
            )
        return best


def _segment_distance_squared(p: Point2D, a: Point2D, b: Point2D) -> Float64:
    """The squared distance from `p` to the segment from `a` to `b`. Beside
    the segment it is the cross product squared over the length squared,
    rounded once, rather than measured to a closest point that has itself
    been rounded: so a point on the segment, or touching a radius round it,
    is found exactly whenever the cross product and the division are, as
    with whole coordinates."""
    var along = b - a
    var offset = p - a
    var length_squared = along.dot(along)
    var t = offset.dot(along)
    if length_squared == 0.0 or t <= 0.0:
        return offset.dot(offset)
    if t >= length_squared:
        return _distance_squared(p, b)
    var across = along.x * offset.y - along.y * offset.x
    return across * across / length_squared


def _cores_overlap[N: Int, M: Int](a: _Core[N], b: _Core[M]) -> Bool:
    """Whether the polygons come within the sum of the radii: they meet --
    an edge of one crosses an edge of the other, or one holds a corner of
    the other -- or, apart, a corner of one is that near an edge of the
    other, where two disjoint convex polygons are nearest."""
    var reach = a.radius + b.radius
    comptime if N == 1 and M == 1:
        return _distance_squared(a.corners[0], b.corners[0]) <= reach * reach
    # Bounds further apart than that along either axis: the common miss.
    var low_a = a._low()
    var high_a = a._high()
    var low_b = b._low()
    var high_b = b._high()
    if (
        low_b.x - high_a.x > reach
        or low_a.x - high_b.x > reach
        or low_b.y - high_a.y > reach
        or low_a.y - high_b.y > reach
    ):
        return False
    var reach_squared = reach * reach
    comptime if N == 1:
        return b._distance_squared_to(a.corners[0]) <= reach_squared
    comptime if M == 1:
        return a._distance_squared_to(b.corners[0]) <= reach_squared
    comptime for i in range(_Core[N].edge_count):
        comptime for j in range(_Core[M].edge_count):
            if _segments_meet(
                a.corners[i], a._edge_end(i), b.corners[j], b._edge_end(j)
            ):
                return True
    # No edges cross, so one is inside the other or they are apart.
    if a._has_area() and a._holds(b.corners[0]):
        return True
    if b._has_area() and b._holds(a.corners[0]):
        return True
    if reach == 0.0:
        return False
    comptime for i in range(N):
        if b._edge_distance_squared(a.corners[i]) <= reach_squared:
            return True
    comptime for j in range(M):
        if a._edge_distance_squared(b.corners[j]) <= reach_squared:
            return True
    return False


def _core_holds[N: Int, M: Int](outer: _Core[N], inner: _Core[M]) -> Bool:
    """Whether `outer` holds `inner`, the hull of the discs of its radius
    round its corners: each disc is inside when its centre lies within
    `outer.radius - inner.radius` of `outer`'s polygon, counted negative,
    as a depth, inside it."""
    var reach = outer.radius - inner.radius
    var has_area = outer._has_area()
    comptime for k in range(M):
        var p = inner.corners[k]
        if has_area and outer._holds(p):
            if reach < 0.0 and outer._edge_distance_squared(p) < reach * reach:
                return False
        elif reach < 0.0 or outer._edge_distance_squared(p) > reach * reach:
            return False
    return True


trait _Collider:
    """A shape that is a `_Core`: the rounded convex shapes, and `Line`."""

    comptime _corner_count: Int
    """How many corners its core has: 1, 2, 3 or 4."""

    def _core(self) -> _Core[Self._corner_count]:
        ...


def _overlaps[A: _Collider, B: _Collider](a: A, b: B) -> Bool:
    """Whether `a` and `b` meet, boundaries included. Exact: decided by
    the signs of cross products where the cores touch, and by squared
    distances against the squared sum of the radii otherwise."""
    return _cores_overlap(a._core(), b._core())


def _contains[A: _Collider, B: _Collider](outer: A, inner: B) -> Bool:
    """Whether `outer` holds the whole of `inner`, boundaries included."""
    return _core_holds(outer._core(), inner._core())
