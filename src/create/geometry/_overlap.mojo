from create.math import Point2D
from .capsule import Capsule, _spine_distance
from .circle import Circle
from .ellipse import Ellipse, _UNIT_CIRCLE
from .line import Line
from .polygon import Polygon
from .rectangle import Rectangle
from .sector import Sector
from .triangle import Triangle


# The pair tests behind each region's `overlaps` method. A `Circle`,
# `Capsule`, `Rectangle` or `Triangle`, rounded or not, is a convex core
# grown by a radius, so any two of them overlap exactly when their cores
# come within the two radii: those sixteen pairs call `_overlaps` from
# `_collider.mojo` and need nothing here. Every other pair has one
# `_regions_overlap` overload, taking the pair in one order; the method
# for the other order swaps its arguments, so `a.overlaps(b)` and
# `b.overlaps(a)` always agree. `Line` and `Arc` have no interior and are
# deliberately excluded; see the comment above `Line.intersects`.
#
# A `Sector` is curved, and past a half turn not even convex, so against a
# polygon or another sector it takes the test any two regions share: one
# holds a point of the other (the tip, a vertex), or their boundaries cross
# (`_polygon_overlaps_sector`). The arc's boundary is found through `cos`
# and `sin`, so a sector touches within the slack `Arc.intersects` allows
# rather than exactly. A `Polygon` may be concave or cross itself, so it
# takes the same shared test, save that one vertex stands for a whole
# polygon: while no edges cross, the other shape's inside/outside cannot
# change along the polygon's boundary. Against these, a rounded rectangle
# or triangle stands in as its outline polygon; against a circle,
# `closest_point` sees its rounding already.
#
# Every test is boundary-inclusive: shapes that only touch (shared edge,
# shared corner, tangent circles) count as overlapping. Degenerate inputs
# -- a zero-size rectangle, a zero-radius circle, a collinear or fully
# degenerate triangle -- remain exact rather than reporting a false
# overlap.
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


def _regions_overlap(a: Sector, b: Circle) -> Bool:
    # `closest_point` already sees a rounded sector's rounding.
    return b.contains(a.closest_point(b.position))


def _regions_overlap(a: Sector, b: Rectangle) -> Bool:
    if a._is_rounded():
        return a._outline().overlaps(b)
    if b._radius() > 0.0:
        return a.overlaps(b._outline())
    return b.contains(a.position) or _polygon_overlaps_sector(b._points(), a)


def _regions_overlap(a: Sector, b: Triangle) -> Bool:
    if a._is_rounded():
        return a._outline().overlaps(b)
    if b._radius() > 0.0:
        return a.overlaps(b._outline())
    return b.contains(a.position) or _polygon_overlaps_sector(b._points(), a)


def _regions_overlap(a: Sector, b: Sector) -> Bool:
    if a._is_rounded():
        return a._outline().overlaps(b)
    if b._is_rounded():
        return a.overlaps(b._outline())
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


def _regions_overlap(a: Polygon, b: Circle) -> Bool:
    # `closest_point` already sees a rounded polygon's rounding.
    return b.contains(a.closest_point(b.position))


def _regions_overlap(a: Polygon, b: Rectangle) -> Bool:
    if a._is_rounded():
        return a._outline().overlaps(b)
    if b._radius() > 0.0:
        return a.overlaps(b._outline())
    if _edges_meet_polygon(b._points(), a):
        return True
    return len(a.vertices) > 0 and b.contains(a.vertices[0])


def _regions_overlap(a: Polygon, b: Triangle) -> Bool:
    if a._is_rounded():
        return a._outline().overlaps(b)
    if b._radius() > 0.0:
        return a.overlaps(b._outline())
    if _edges_meet_polygon(b._points(), a):
        return True
    return len(a.vertices) > 0 and b.contains(a.vertices[0])


def _regions_overlap(a: Polygon, b: Sector) -> Bool:
    if a._is_rounded():
        return a._outline().overlaps(b)
    if b._is_rounded():
        return a.overlaps(b._outline())
    if a.contains(b.position):
        return True
    for v in a.vertices:
        if b.contains(v):
            return True
    for i in range(len(a.vertices)):
        if b._boundary_meets(a._edge(i)):
            return True
    return False


def _regions_overlap(a: Polygon, b: Polygon) -> Bool:
    if a._is_rounded():
        return a._outline().overlaps(b)
    if b._is_rounded():
        return a.overlaps(b._outline())
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
def _regions_overlap(a: Ellipse, b: Circle) -> Bool:
    if a._is_flat():
        return a.bounds().overlaps(b)
    return b.contains(a.closest_point(b.position))


def _regions_overlap(a: Ellipse, b: Rectangle) -> Bool:
    if a._is_flat():
        return a.bounds().overlaps(b)
    if not b._is_plain():
        return a.overlaps(b._outline())
    return a._to_unit(b).overlaps(_UNIT_CIRCLE)


def _regions_overlap(a: Ellipse, b: Triangle) -> Bool:
    if a._is_flat():
        return a.bounds().overlaps(b)
    if b._radius() > 0.0:
        return a.overlaps(b._outline())
    return a._to_unit(b).overlaps(_UNIT_CIRCLE)


def _regions_overlap(a: Ellipse, b: Sector) -> Bool:
    if a._is_flat():
        return a.bounds().overlaps(b)
    return a._outline().overlaps(b)


def _regions_overlap(a: Ellipse, b: Polygon) -> Bool:
    if a._is_flat():
        return a.bounds().overlaps(b)
    if b._is_rounded():
        return a.overlaps(b._outline())
    return a._to_unit(b).overlaps(_UNIT_CIRCLE)


def _regions_overlap(a: Ellipse, b: Ellipse) -> Bool:
    # Mapped onto `a`'s unit circle, `b` is still an axis-aligned ellipse.
    if a._is_flat():
        return b.overlaps(a.bounds())
    if b._is_flat():
        return a.overlaps(b.bounds())
    return a._to_unit(b).overlaps(_UNIT_CIRCLE)


# A capsule against a curved or concave region: its spine comes within its
# radius of it (`_spine_distance`).
def _regions_overlap(a: Capsule, b: Ellipse) -> Bool:
    return _spine_distance(a._spine(), b) <= a.radius


def _regions_overlap(a: Capsule, b: Sector) -> Bool:
    return _spine_distance(a._spine(), b) <= a.radius


def _regions_overlap(a: Capsule, b: Polygon) -> Bool:
    return _spine_distance(a._spine(), b) <= a.radius
