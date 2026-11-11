from std.math import max
from create.math import Point2D
from ._shared import _distance_squared, _polygons_overlap
from .capsule import Capsule, _spine_distance
from .circle import Circle
from .ellipse import Ellipse, _UNIT_CIRCLE
from .line import Line
from .polygon import Polygon
from .rectangle import Rectangle
from .sector import Sector
from .triangle import Triangle


# `overlaps(a, b)` is the whole overlap-testing surface for regions: one
# specialized, exact overload per unordered shape pair (`Rectangle`,
# `Circle`, `Ellipse`, `Capsule`, `Triangle`, `Sector`, `Polygon` -- `Line`
# and `Arc`
# have no
# interior and are
# deliberately excluded, see the taxonomy comment above `Line.intersects`),
# so a symmetric relation reads as a symmetric call -- `overlaps(a, b)` and
# `overlaps(b, a)` always agree, and the reverse-order overload is a
# one-line delegation to the other. Each pair picks the cheapest exact
# test for that combination rather than routing through a single generic
# algorithm -- `Circle` vs. anything else is a `closest_point`-then-
# `contains` check (exact only because a circle's containment is radial
# from its centre), and any pair of straight-edged shapes is SAT over
# `_polygons_overlap`. A `Sector` is curved, and past a half turn not even
# convex, so against a polygon or another sector it is not SAT but the
# test any two regions share: one holds a point of the other (the tip, a
# vertex), or their boundaries cross (`_polygon_overlaps_sector`). The
# arc's boundary is found through `cos` and `sin`, so a sector touches
# within the slack `Arc.intersects` allows rather than exactly. A `Polygon`
# may be concave or cross itself, so it takes the same shared test, save
# that one vertex stands for a whole polygon: while no edges cross, the
# other shape's inside/outside cannot change along the polygon's boundary.
#
# A rounded rectangle or triangle is tested as rounded. Against a circle
# that comes free with its `closest_point`; two rectangles overlap when
# their inner rectangles come within the two radii; otherwise the rounded
# shape stands in as its outline polygon.
#
# Every overload is boundary-inclusive: shapes that only touch (shared
# edge, shared corner, tangent circles) count as overlapping. Degenerate
# inputs -- a zero-size rectangle, a zero-radius circle, a collinear or
# fully degenerate triangle -- remain exact rather than reporting a false
# overlap; `_polygons_overlap`'s own comment covers how SAT stays sound
# when a polygon collapses to a segment or a point.
def overlaps(a: Rectangle, b: Rectangle) -> Bool:
    var ra = a._radius()
    var rb = b._radius()
    if ra > 0.0 or rb > 0.0:
        var ia = a._inner()
        var ib = b._inner()
        var dx = max(
            abs(ia.position.x - ib.position.x) - (ia.w + ib.w) / 2, 0.0
        )
        var dy = max(
            abs(ia.position.y - ib.position.y) - (ia.h + ib.h) / 2, 0.0
        )
        return dx * dx + dy * dy <= (ra + rb) * (ra + rb)
    return (
        a.left() <= b.right()
        and a.right() >= b.left()
        and a.bottom() <= b.top()
        and a.top() >= b.bottom()
    )


def overlaps(a: Circle, b: Circle) -> Bool:
    var rsum = a.r + b.r
    return _distance_squared(a.position, b.position) <= rsum * rsum


def overlaps(a: Circle, b: Rectangle) -> Bool:
    return a.contains(b.closest_point(a.position))


def overlaps(a: Rectangle, b: Circle) -> Bool:
    return overlaps(b, a)


def overlaps(a: Circle, b: Triangle) -> Bool:
    return a.contains(b.closest_point(a.position))


def overlaps(a: Triangle, b: Circle) -> Bool:
    return overlaps(b, a)


def overlaps(a: Rectangle, b: Triangle) -> Bool:
    if a._radius() > 0.0:
        return overlaps(a._outline(), b)
    if b._radius() > 0.0:
        return overlaps(a, b._outline())
    return _polygons_overlap(a._points(), b._points())


def overlaps(a: Triangle, b: Rectangle) -> Bool:
    return overlaps(b, a)


def overlaps(a: Triangle, b: Triangle) -> Bool:
    if a._radius() > 0.0:
        return overlaps(a._outline(), b)
    if b._radius() > 0.0:
        return overlaps(a, b._outline())
    return _polygons_overlap(a._points(), b._points())


def _polygon_overlaps_sector[N: Int](pts: Array[Point2D, N], s: Sector) -> Bool:
    """Whether the sector holds a vertex of the polygon, or an edge of the
    polygon crosses the sector's boundary. With the polygon holding the
    sector's tip, which the caller tests, that is every way to overlap."""
    for p in pts:
        if s.contains(p):
            return True
    for i in range(N):
        if s._boundary_meets(Line(pts[i], pts[(i + 1) % N])):
            return True
    return False


def overlaps(a: Sector, b: Circle) -> Bool:
    # `closest_point` already sees a rounded sector's rounding.
    return b.contains(a.closest_point(b.position))


def overlaps(a: Circle, b: Sector) -> Bool:
    return overlaps(b, a)


def overlaps(a: Sector, b: Rectangle) -> Bool:
    if a._is_rounded():
        return overlaps(a._outline(), b)
    if b._radius() > 0.0:
        return overlaps(a, b._outline())
    return b.contains(a.position) or _polygon_overlaps_sector(b._points(), a)


def overlaps(a: Rectangle, b: Sector) -> Bool:
    return overlaps(b, a)


def overlaps(a: Sector, b: Triangle) -> Bool:
    if a._is_rounded():
        return overlaps(a._outline(), b)
    if b._radius() > 0.0:
        return overlaps(a, b._outline())
    return b.contains(a.position) or _polygon_overlaps_sector(b._points(), a)


def overlaps(a: Triangle, b: Sector) -> Bool:
    return overlaps(b, a)


def overlaps(a: Sector, b: Sector) -> Bool:
    if a._is_rounded():
        return overlaps(a._outline(), b)
    if b._is_rounded():
        return overlaps(a, b._outline())
    if a.contains(b.position) or b.contains(a.position):
        return True
    for radius in a._radii():
        if b._boundary_meets(radius):
            return True
    return b._boundary_meets(a.arc())


def _edges_meet_polygon[N: Int](pts: Array[Point2D, N], p: Polygon) -> Bool:
    """Whether an edge of the straight-edged region with corners `pts`
    meets `p`: reaches into it, or crosses one of its edges."""
    for i in range(N):
        if Line(pts[i], pts[(i + 1) % N]).intersects(p):
            return True
    return False


def overlaps(a: Polygon, b: Circle) -> Bool:
    # `closest_point` already sees a rounded polygon's rounding.
    return b.contains(a.closest_point(b.position))


def overlaps(a: Circle, b: Polygon) -> Bool:
    return overlaps(b, a)


def overlaps(a: Polygon, b: Rectangle) -> Bool:
    if a._is_rounded():
        return overlaps(a._outline(), b)
    if b._radius() > 0.0:
        return overlaps(a, b._outline())
    if _edges_meet_polygon(b._points(), a):
        return True
    return len(a.vertices) > 0 and b.contains(a.vertices[0])


def overlaps(a: Rectangle, b: Polygon) -> Bool:
    return overlaps(b, a)


def overlaps(a: Polygon, b: Triangle) -> Bool:
    if a._is_rounded():
        return overlaps(a._outline(), b)
    if b._radius() > 0.0:
        return overlaps(a, b._outline())
    if _edges_meet_polygon(b._points(), a):
        return True
    return len(a.vertices) > 0 and b.contains(a.vertices[0])


def overlaps(a: Triangle, b: Polygon) -> Bool:
    return overlaps(b, a)


def overlaps(a: Polygon, b: Sector) -> Bool:
    if a._is_rounded():
        return overlaps(a._outline(), b)
    if b._is_rounded():
        return overlaps(a, b._outline())
    if a.contains(b.position):
        return True
    for v in a.vertices:
        if b.contains(v):
            return True
    for i in range(len(a.vertices)):
        if b._boundary_meets(a._edge(i)):
            return True
    return False


def overlaps(a: Sector, b: Polygon) -> Bool:
    return overlaps(b, a)


def overlaps(a: Polygon, b: Polygon) -> Bool:
    if a._is_rounded():
        return overlaps(a._outline(), b)
    if b._is_rounded():
        return overlaps(a, b._outline())
    for i in range(len(a.vertices)):
        if a._edge(i).intersects(b):
            return True
    return len(b.vertices) > 0 and a.contains(b.vertices[0])


# An ellipse against a straight-edged shape is the unit circle against that
# shape mapped onto it (`Ellipse._to_unit`), which stays straight-edged, so
# those pairs are the circle's exact tests. Against a circle or another
# ellipse, it is the closest point on an ellipse (accurate to rounding), and
# against a sector, whose arc that map would bend, its outline polygon. A
# flat ellipse is its zero-size bounds throughout.
def overlaps(a: Ellipse, b: Circle) -> Bool:
    if a._is_flat():
        return overlaps(a.bounds(), b)
    return b.contains(a.closest_point(b.position))


def overlaps(a: Circle, b: Ellipse) -> Bool:
    return overlaps(b, a)


def overlaps(a: Ellipse, b: Rectangle) -> Bool:
    if a._is_flat():
        return overlaps(a.bounds(), b)
    if b._radius() > 0.0:
        return overlaps(a, b._outline())
    return overlaps(a._to_unit(b), _UNIT_CIRCLE)


def overlaps(a: Rectangle, b: Ellipse) -> Bool:
    return overlaps(b, a)


def overlaps(a: Ellipse, b: Triangle) -> Bool:
    if a._is_flat():
        return overlaps(a.bounds(), b)
    if b._radius() > 0.0:
        return overlaps(a, b._outline())
    return overlaps(a._to_unit(b), _UNIT_CIRCLE)


def overlaps(a: Triangle, b: Ellipse) -> Bool:
    return overlaps(b, a)


def overlaps(a: Ellipse, b: Sector) -> Bool:
    if a._is_flat():
        return overlaps(a.bounds(), b)
    return overlaps(a._outline(), b)


def overlaps(a: Sector, b: Ellipse) -> Bool:
    return overlaps(b, a)


def overlaps(a: Ellipse, b: Polygon) -> Bool:
    if a._is_flat():
        return overlaps(a.bounds(), b)
    if b._is_rounded():
        return overlaps(a, b._outline())
    return overlaps(a._to_unit(b), _UNIT_CIRCLE)


def overlaps(a: Polygon, b: Ellipse) -> Bool:
    return overlaps(b, a)


def overlaps(a: Ellipse, b: Ellipse) -> Bool:
    # Mapped onto `a`'s unit circle, `b` is still an axis-aligned ellipse.
    if a._is_flat():
        return overlaps(b, a.bounds())
    if b._is_flat():
        return overlaps(a, b.bounds())
    return overlaps(a._to_unit(b), _UNIT_CIRCLE)


# A capsule overlaps a region exactly when its spine comes within its
# radius of it (`_spine_distance`).
def overlaps(a: Capsule, b: Rectangle) -> Bool:
    return _spine_distance(a._spine(), b) <= a.r


def overlaps(a: Rectangle, b: Capsule) -> Bool:
    return overlaps(b, a)


def overlaps(a: Capsule, b: Circle) -> Bool:
    return _spine_distance(a._spine(), b) <= a.r


def overlaps(a: Circle, b: Capsule) -> Bool:
    return overlaps(b, a)


def overlaps(a: Capsule, b: Ellipse) -> Bool:
    return _spine_distance(a._spine(), b) <= a.r


def overlaps(a: Ellipse, b: Capsule) -> Bool:
    return overlaps(b, a)


def overlaps(a: Capsule, b: Triangle) -> Bool:
    return _spine_distance(a._spine(), b) <= a.r


def overlaps(a: Triangle, b: Capsule) -> Bool:
    return overlaps(b, a)


def overlaps(a: Capsule, b: Sector) -> Bool:
    return _spine_distance(a._spine(), b) <= a.r


def overlaps(a: Sector, b: Capsule) -> Bool:
    return overlaps(b, a)


def overlaps(a: Capsule, b: Polygon) -> Bool:
    return _spine_distance(a._spine(), b) <= a.r


def overlaps(a: Polygon, b: Capsule) -> Bool:
    return overlaps(b, a)


def overlaps(a: Capsule, b: Capsule) -> Bool:
    return _spine_distance(a._spine(), b) <= a.r
