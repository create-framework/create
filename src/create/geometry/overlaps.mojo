from std.iter import downcast
from create.math import Point2D
from ._collider import _Collider, _overlaps
from .drawable import Region
from .capsule import Capsule, _spine_distance
from .circle import Circle
from .ellipse import Ellipse, _UNIT_CIRCLE
from .line import Line
from .polygon import Polygon
from .rectangle import Rectangle
from .sector import Sector
from .triangle import Triangle


# `overlaps(a, b)` is the whole overlap-testing surface for regions: one
# function over every pair of `Rectangle`, `Circle`, `Ellipse`, `Capsule`,
# `Triangle`, `Sector` and `Polygon`, its test picked at compile time. A
# pair is tested in one order only, the lower `_rank` first, so
# `overlaps(a, b)` and `overlaps(b, a)` always agree. `Line` and `Arc` have
# no interior and are deliberately excluded; see the comment above
# `Line.intersects`.
#
# A `Circle`, `Capsule`, `Rectangle` or `Triangle`, rounded or not, is a
# convex core grown by a radius, so any two of them overlap exactly when
# their cores come within the two radii (`_overlaps`): one test for all
# sixteen pairs, save the shortcut for two sharp, upright rectangles. The
# rest need their own, `_overlap`'s overloads. A `Sector` is curved, and
# past a half turn not even convex, so against a polygon or another sector
# it takes the test any two regions share: one holds a point of the other
# (the tip, a vertex), or their boundaries cross
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
def overlaps[A: Region, B: Region](a: A, b: B) -> Bool:
    """Whether `a` and `b` share any point, their boundaries included: shapes
    that only touch, along an edge or at a corner, overlap.

    `a` and `b` are each a `Rectangle`, `Circle`, `Ellipse`, `Capsule`,
    `Triangle`, `Sector` or `Polygon`, in either order: `overlaps(a, b)` and
    `overlaps(b, a)` always agree. A curve has no inside; test one with
    `intersects`."""
    comptime if A == Rectangle and B == Rectangle:
        # The commonest test in a game: two sharp, upright rectangles
        # overlap when their spans do along both axes, four comparisons and
        # no polygon test.
        ref r = rebind[Rectangle](a)
        ref s = rebind[Rectangle](b)
        if r._is_plain() and s._is_plain():
            return (
                r.left() <= s.right()
                and s.left() <= r.right()
                and r.bottom() <= s.top()
                and s.bottom() <= r.top()
            )
        return _overlaps(r, s)
    elif conforms_to(A, _Collider) and conforms_to(B, _Collider):
        return _overlaps(
            rebind[downcast[A, _Collider]](a), rebind[downcast[B, _Collider]](b)
        )
    elif _rank[A]() > _rank[B]():
        return overlaps(b, a)
    elif A == Capsule and B == Ellipse:
        return _overlap(rebind[Capsule](a), rebind[Ellipse](b))
    elif A == Capsule and B == Polygon:
        return _overlap(rebind[Capsule](a), rebind[Polygon](b))
    elif A == Capsule and B == Sector:
        return _overlap(rebind[Capsule](a), rebind[Sector](b))
    elif A == Ellipse and B == Ellipse:
        return _overlap(rebind[Ellipse](a), rebind[Ellipse](b))
    elif A == Ellipse and B == Polygon:
        return _overlap(rebind[Ellipse](a), rebind[Polygon](b))
    elif A == Ellipse and B == Sector:
        return _overlap(rebind[Ellipse](a), rebind[Sector](b))
    elif A == Ellipse and B == Circle:
        return _overlap(rebind[Ellipse](a), rebind[Circle](b))
    elif A == Ellipse and B == Rectangle:
        return _overlap(rebind[Ellipse](a), rebind[Rectangle](b))
    elif A == Ellipse and B == Triangle:
        return _overlap(rebind[Ellipse](a), rebind[Triangle](b))
    elif A == Polygon and B == Polygon:
        return _overlap(rebind[Polygon](a), rebind[Polygon](b))
    elif A == Polygon and B == Sector:
        return _overlap(rebind[Polygon](a), rebind[Sector](b))
    elif A == Polygon and B == Circle:
        return _overlap(rebind[Polygon](a), rebind[Circle](b))
    elif A == Polygon and B == Rectangle:
        return _overlap(rebind[Polygon](a), rebind[Rectangle](b))
    elif A == Polygon and B == Triangle:
        return _overlap(rebind[Polygon](a), rebind[Triangle](b))
    elif A == Sector and B == Sector:
        return _overlap(rebind[Sector](a), rebind[Sector](b))
    elif A == Sector and B == Circle:
        return _overlap(rebind[Sector](a), rebind[Circle](b))
    elif A == Sector and B == Rectangle:
        return _overlap(rebind[Sector](a), rebind[Rectangle](b))
    elif A == Sector and B == Triangle:
        return _overlap(rebind[Sector](a), rebind[Triangle](b))
    else:
        comptime assert False, (
            "overlaps takes a Rectangle, Circle, Ellipse, Capsule, Triangle,"
            " Sector or Polygon"
        )


def _rank[T: Region]() -> Int:
    """Where `T` comes in the one order `overlaps` tests a pair in: the
    first of the pair is the one its `_overlap` overload takes first. -1
    for a type `overlaps` doesn't take."""
    comptime if T == Capsule:
        return 0
    elif T == Ellipse:
        return 1
    elif T == Polygon:
        return 2
    elif T == Sector:
        return 3
    elif T == Circle:
        return 4
    elif T == Rectangle:
        return 5
    elif T == Triangle:
        return 6
    else:
        return -1


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


def _overlap(a: Sector, b: Circle) -> Bool:
    # `closest_point` already sees a rounded sector's rounding.
    return b.contains(a.closest_point(b.position))


def _overlap(a: Sector, b: Rectangle) -> Bool:
    if a._is_rounded():
        return overlaps(a._outline(), b)
    if b._radius() > 0.0:
        return overlaps(a, b._outline())
    return b.contains(a.position) or _polygon_overlaps_sector(b._points(), a)


def _overlap(a: Sector, b: Triangle) -> Bool:
    if a._is_rounded():
        return overlaps(a._outline(), b)
    if b._radius() > 0.0:
        return overlaps(a, b._outline())
    return b.contains(a.position) or _polygon_overlaps_sector(b._points(), a)


def _overlap(a: Sector, b: Sector) -> Bool:
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


def _overlap(a: Polygon, b: Circle) -> Bool:
    # `closest_point` already sees a rounded polygon's rounding.
    return b.contains(a.closest_point(b.position))


def _overlap(a: Polygon, b: Rectangle) -> Bool:
    if a._is_rounded():
        return overlaps(a._outline(), b)
    if b._radius() > 0.0:
        return overlaps(a, b._outline())
    if _edges_meet_polygon(b._points(), a):
        return True
    return len(a.vertices) > 0 and b.contains(a.vertices[0])


def _overlap(a: Polygon, b: Triangle) -> Bool:
    if a._is_rounded():
        return overlaps(a._outline(), b)
    if b._radius() > 0.0:
        return overlaps(a, b._outline())
    if _edges_meet_polygon(b._points(), a):
        return True
    return len(a.vertices) > 0 and b.contains(a.vertices[0])


def _overlap(a: Polygon, b: Sector) -> Bool:
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


def _overlap(a: Polygon, b: Polygon) -> Bool:
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
def _overlap(a: Ellipse, b: Circle) -> Bool:
    if a._is_flat():
        return overlaps(a.bounds(), b)
    return b.contains(a.closest_point(b.position))


def _overlap(a: Ellipse, b: Rectangle) -> Bool:
    if a._is_flat():
        return overlaps(a.bounds(), b)
    if not b._is_plain():
        return overlaps(a, b._outline())
    return overlaps(a._to_unit(b), _UNIT_CIRCLE)


def _overlap(a: Ellipse, b: Triangle) -> Bool:
    if a._is_flat():
        return overlaps(a.bounds(), b)
    if b._radius() > 0.0:
        return overlaps(a, b._outline())
    return overlaps(a._to_unit(b), _UNIT_CIRCLE)


def _overlap(a: Ellipse, b: Sector) -> Bool:
    if a._is_flat():
        return overlaps(a.bounds(), b)
    return overlaps(a._outline(), b)


def _overlap(a: Ellipse, b: Polygon) -> Bool:
    if a._is_flat():
        return overlaps(a.bounds(), b)
    if b._is_rounded():
        return overlaps(a, b._outline())
    return overlaps(a._to_unit(b), _UNIT_CIRCLE)


def _overlap(a: Ellipse, b: Ellipse) -> Bool:
    # Mapped onto `a`'s unit circle, `b` is still an axis-aligned ellipse.
    if a._is_flat():
        return overlaps(b, a.bounds())
    if b._is_flat():
        return overlaps(a, b.bounds())
    return overlaps(a._to_unit(b), _UNIT_CIRCLE)


# A capsule against a curved or concave region: its spine comes within its
# radius of it (`_spine_distance`).
def _overlap(a: Capsule, b: Ellipse) -> Bool:
    return _spine_distance(a._spine(), b) <= a.radius


def _overlap(a: Capsule, b: Sector) -> Bool:
    return _spine_distance(a._spine(), b) <= a.radius


def _overlap(a: Capsule, b: Polygon) -> Bool:
    return _spine_distance(a._spine(), b) <= a.radius
