from std.testing import (
    TestSuite,
    assert_equal,
    assert_true,
    assert_false,
    assert_almost_equal,
)
from create.math import PI
from create.geometry import Rectangle, Circle, Line, Triangle
from create.math.point import Point
from create.math.vector import Vector


# Rectangle — x,y is center
def test_rect_bounds() raises -> None:
    var r = Rectangle((0.0, 0.0), 10.0, 6.0)
    assert_equal(r.left(), -5.0)
    assert_equal(r.right(), 5.0)
    assert_equal(r.bottom(), -3.0)
    assert_equal(r.top(), 3.0)


def test_rect_center() raises -> None:
    var r = Rectangle((4.0, 2.0), 10.0, 6.0)
    var c = r.center()
    assert_equal(c.x, 4.0)
    assert_equal(c.y, 2.0)


def test_rect_contains_inside() raises -> None:
    var r = Rectangle((0.0, 0.0), 10.0, 10.0)
    assert_true(r.contains((0.0, 0.0)))
    assert_true(r.contains((4.9, 4.9)))


def test_rect_contains_outside() raises -> None:
    var r = Rectangle((0.0, 0.0), 10.0, 10.0)
    assert_equal(r.contains((6.0, 0.0)), False)
    assert_equal(r.contains((0.0, 6.0)), False)


def test_rect_contains_on_edge() raises -> None:
    var r = Rectangle((0.0, 0.0), 10.0, 10.0)
    assert_true(r.contains((5.0, 0.0)))
    assert_true(r.contains((0.0, 5.0)))


def test_rect_closest_point_outside() raises -> None:
    var r = Rectangle((0.0, 0.0), 10.0, 10.0)
    var p = r.closest_point((10.0, 0.0))
    assert_equal(p.x, 5.0)
    assert_equal(p.y, 0.0)


def test_rect_closest_point_inside() raises -> None:
    var r = Rectangle((0.0, 0.0), 10.0, 10.0)
    var p = r.closest_point((1.0, 1.0))
    assert_equal(p.x, 1.0)
    assert_equal(p.y, 1.0)


def test_rect_closest_point_vector() raises -> None:
    var r = Rectangle((0.0, 0.0), 10.0, 10.0)
    var p = r.closest_point(Point(10.0, 0.0))
    assert_equal(p.x, 5.0)
    assert_equal(p.y, 0.0)


def test_rect_int_constructor() raises -> None:
    var r = Rectangle(Point(1.0, 2.0), 10, 6)
    assert_equal(r.position.x, 1.0)
    assert_equal(r.position.y, 2.0)
    assert_equal(r.width, 10.0)
    assert_equal(r.height, 6.0)


def test_rect_move_to() raises -> None:
    var r = Rectangle((0.0, 0.0), 10.0, 10.0)
    r = r.move_to((5.0, 5.0))
    assert_equal(r.position.x, 5.0)
    assert_equal(r.position.y, 5.0)


def test_rect_translate() raises -> None:
    var r = Rectangle((0.0, 0.0), 10.0, 10.0)
    r = r.translate(Vector(2.0, 3.0))
    assert_equal(r.position.x, 2.0)
    assert_equal(r.position.y, 3.0)


# Circle
def test_circle_center() raises -> None:
    var c = Circle((3.0, 4.0), 5.0)
    var ctr = c.center()
    assert_equal(ctr.x, 3.0)
    assert_equal(ctr.y, 4.0)


def test_circle_contains_inside() raises -> None:
    var c = Circle((0.0, 0.0), 5.0)
    assert_true(c.contains((0.0, 0.0)))
    assert_true(c.contains((3.0, 4.0)))


def test_circle_contains_outside() raises -> None:
    var c = Circle((0.0, 0.0), 5.0)
    assert_equal(c.contains((4.0, 4.0)), False)


def test_circle_contains_on_edge() raises -> None:
    var c = Circle((0.0, 0.0), 5.0)
    assert_true(c.contains((5.0, 0.0)))


def test_circle_closest_point_outside() raises -> None:
    var c = Circle((0.0, 0.0), 5.0)
    var p = c.closest_point((10.0, 0.0))
    assert_almost_equal(p.x, 5.0, atol=1e-9)
    assert_almost_equal(p.y, 0.0, atol=1e-9)


def test_circle_closest_point_inside() raises -> None:
    var c = Circle((0.0, 0.0), 5.0)
    var p = c.closest_point((1.0, 0.0))
    assert_equal(p.x, 1.0)
    assert_equal(p.y, 0.0)


def test_circle_closest_point_vector() raises -> None:
    var c = Circle((0.0, 0.0), 5.0)
    var p = c.closest_point(Point(10.0, 0.0))
    assert_almost_equal(p.x, 5.0, atol=1e-9)
    assert_almost_equal(p.y, 0.0, atol=1e-9)


def test_circle_move_to() raises -> None:
    var c = Circle((0.0, 0.0), 5.0)
    c = c.move_to((3.0, 4.0))
    assert_equal(c.position.x, 3.0)
    assert_equal(c.position.y, 4.0)


def test_circle_translate() raises -> None:
    var c = Circle((0.0, 0.0), 5.0)
    c = c.translate(Vector(2.0, 3.0))
    assert_equal(c.position.x, 2.0)
    assert_equal(c.position.y, 3.0)


# Line
def test_line_length() raises -> None:
    var l = Line((0.0, 0.0), (3.0, 4.0))
    assert_almost_equal(l.length(), 5.0, atol=1e-9)


def test_line_split_meets_at_the_cut() raises -> None:
    var l = Line((0.0, 0.0), (4.0, 2.0))
    var halves = l.split(0.25)
    assert_equal(halves[0], Line((0.0, 0.0), (1.0, 0.5)))
    assert_equal(halves[1], Line((1.0, 0.5), (4.0, 2.0)))


def test_line_closest_point_perpendicular() raises -> None:
    var l = Line((0.0, 0.0), (4.0, 0.0))
    var p = l.closest_point((2.0, 5.0))
    assert_equal(p.x, 2.0)
    assert_equal(p.y, 0.0)


def test_line_closest_point_clamps_past_endpoint() raises -> None:
    var l = Line((0.0, 0.0), (4.0, 0.0))
    var p = l.closest_point((10.0, 3.0))
    assert_equal(p.x, 4.0)
    assert_equal(p.y, 0.0)


def test_line_closest_point_vector() raises -> None:
    var l = Line((0.0, 0.0), (4.0, 0.0))
    var p = l.closest_point(Point(2.0, 5.0))
    assert_equal(p.x, 2.0)
    assert_equal(p.y, 0.0)


def test_line_midpoint() raises -> None:
    var l = Line((0.0, 0.0), (4.0, 0.0))
    var m = l.midpoint()
    assert_equal(m.x, 2.0)
    assert_equal(m.y, 0.0)


def test_line_at_runs_start_to_end_and_beyond() raises -> None:
    var l = Line((0.0, 0.0), (4.0, 2.0))
    assert_equal(l.at(0.0), l.start)
    assert_equal(l.at(1.0), l.end)
    assert_equal(l.at(0.5), l.midpoint())
    assert_equal(l.at(1.5), Point(6.0, 3.0))


def test_line_tangent_is_the_whole_line() raises -> None:
    var l = Line((1.0, 1.0), (4.0, 5.0))
    assert_equal(l.tangent(0.0), Vector(3.0, 4.0))
    assert_equal(l.tangent(0.7), Vector(3.0, 4.0))


def test_line_at_distance_clamps_to_its_ends() raises -> None:
    var l = Line((0.0, 0.0), (3.0, 4.0))
    assert_equal(l.at_distance(l.length() / 2.0), l.midpoint())
    assert_equal(l.at_distance(-1.0), l.start)
    assert_equal(l.at_distance(10.0), l.end)
    var point = Line((2.0, 2.0), (2.0, 2.0))
    assert_equal(point.at_distance(1.0), point.start)


def test_line_bounds() raises -> None:
    var b = Line((4.0, -1.0), (0.0, 3.0)).bounds()
    assert_equal(b, Rectangle((2.0, 1.0), 4.0, 4.0))
    var flat = Line((0.0, 1.0), (4.0, 1.0)).bounds()
    assert_equal(flat.height, 0.0)


def test_line_flatten_is_its_ends() raises -> None:
    var l = Line((0.0, 0.0), (4.0, 2.0))
    var points = l.flatten(0.01)
    assert_equal(len(points), 2)
    assert_equal(points[0], l.start)
    assert_equal(points[1], l.end)


def test_line_beziers_trace_it_exactly() raises -> None:
    var l = Line((0.0, 0.0), (6.0, 3.0))
    var curves = l.beziers()
    assert_equal(len(curves), 1)
    for i in range(11):
        var t = Float64(i) / 10.0
        var p = curves[0].at(t)
        assert_almost_equal(p.x, l.at(t).x, atol=1e-12)
        assert_almost_equal(p.y, l.at(t).y, atol=1e-12)


def test_line_move_to_places_midpoint() raises -> None:
    var l = Line((0.0, 0.0), (4.0, 0.0))
    l = l.move_to((10.0, 10.0))
    assert_almost_equal(l.length(), 4.0, atol=1e-9)
    var m = l.midpoint()
    assert_equal(m.x, 10.0)
    assert_equal(m.y, 10.0)
    assert_equal(l.start.x, 8.0)
    assert_equal(l.start.y, 10.0)
    assert_equal(l.end.x, 12.0)
    assert_equal(l.end.y, 10.0)


def test_line_translate() raises -> None:
    var l = Line((0.0, 0.0), (4.0, 0.0))
    l = l.translate(Vector(1.0, 2.0))
    assert_equal(l.start.x, 1.0)
    assert_equal(l.start.y, 2.0)
    assert_equal(l.end.x, 5.0)
    assert_equal(l.end.y, 2.0)


def test_line_intersects_crossing() raises -> None:
    var a = Line((0.0, 0.0), (2.0, 2.0))
    var b = Line((0.0, 2.0), (2.0, 0.0))
    assert_true(a.intersects(b))


def test_line_intersects_parallel() raises -> None:
    var a = Line((0.0, 0.0), (2.0, 0.0))
    var b = Line((0.0, 1.0), (2.0, 1.0))
    assert_equal(a.intersects(b), False)


def test_line_intersects_same_line() raises -> None:
    var a = Line((0.0, 0.0), (4.0, 0.0))
    var b = Line((0.0, 0.0), (4.0, 0.0))
    assert_true(a.intersects(b))


def test_line_intersects_partially_overlapping_collinear() raises -> None:
    var a = Line((0.0, 0.0), (4.0, 0.0))
    var b = Line((2.0, 0.0), (6.0, 0.0))
    assert_true(a.intersects(b))


def test_line_intersects_disjoint_collinear() raises -> None:
    var a = Line((0.0, 0.0), (2.0, 0.0))
    var b = Line((3.0, 0.0), (5.0, 0.0))
    assert_equal(a.intersects(b), False)


def test_line_intersects_t_intersection() raises -> None:
    # Endpoint of b sits on interior of a — CCW test detects this as intersection
    var a = Line((0.0, 0.0), (4.0, 0.0))
    var b = Line((2.0, 0.0), (2.0, 2.0))
    assert_true(a.intersects(b))


def test_line_intersects_point_on_segment() raises -> None:
    var l = Line((0.0, 0.0), (4.0, 0.0))
    assert_true(l.intersects((2.0, 0.0)))
    assert_true(l.intersects(Point(2.0, 0.0)))


def test_line_intersects_point_off_segment() raises -> None:
    var l = Line((0.0, 0.0), (4.0, 0.0))
    assert_equal(l.intersects((2.0, 1.0)), False)


def test_line_intersects_circle_passing_through() raises -> None:
    # Crosses the circle without either endpoint inside it.
    var l = Line((-5.0, 0.0), (5.0, 0.0))
    var c = Circle((0.0, 0.0), 2.0)
    assert_true(l.intersects(c))


def test_line_intersects_circle_clamped_short() raises -> None:
    # The infinite extension would hit the circle; the finite segment stops short.
    var l = Line((-5.0, 5.0), (-3.0, 5.0))
    var c = Circle((0.0, 0.0), 2.0)
    assert_equal(l.intersects(c), False)


def test_line_intersects_rectangle_fully_inside() raises -> None:
    var l = Line((-1.0, 0.0), (1.0, 0.0))
    var r = Rectangle((0.0, 0.0), 10.0, 10.0)
    assert_true(l.intersects(r))


def test_line_intersects_rectangle_crossing_one_edge() raises -> None:
    var l = Line((0.0, 0.0), (10.0, 0.0))
    var r = Rectangle((8.0, 0.0), 4.0, 4.0)
    assert_true(l.intersects(r))


def test_line_intersects_rectangle_no() raises -> None:
    var l = Line((-10.0, -10.0), (-8.0, -10.0))
    var r = Rectangle((0.0, 0.0), 4.0, 4.0)
    assert_equal(l.intersects(r), False)


def test_line_intersects_rectangle_touching_boundary() raises -> None:
    var l = Line((2.0, 0.0), (6.0, 0.0))
    var r = Rectangle((0.0, 0.0), 4.0, 4.0)
    assert_true(l.intersects(r))


def test_line_intersects_triangle_fully_inside() raises -> None:
    var l = Line((1.0, 0.5), (2.0, 0.5))
    var t = Triangle((0.0, 0.0), (6.0, 0.0), (0.0, 6.0))
    assert_true(l.intersects(t))


def test_line_intersects_triangle_crossing() raises -> None:
    # Both endpoints outside the triangle; the segment cuts through the hull.
    var l = Line((-2.0, 1.0), (8.0, 1.0))
    var t = Triangle((0.0, 0.0), (6.0, 0.0), (0.0, 6.0))
    assert_true(l.intersects(t))


def test_line_intersects_triangle_no() raises -> None:
    var l = Line((-10.0, -10.0), (-8.0, -10.0))
    var t = Triangle((0.0, 0.0), (6.0, 0.0), (0.0, 6.0))
    assert_equal(l.intersects(t), False)


# Triangle
def test_triangle_center() raises -> None:
    var t = Triangle((0.0, 0.0), (6.0, 0.0), (3.0, 6.0))
    var c = t.center()
    assert_almost_equal(c.x, 3.0, atol=1e-9)
    assert_almost_equal(c.y, 2.0, atol=1e-9)


def test_triangle_closest_point_vector() raises -> None:
    var t = Triangle((0.0, 0.0), (6.0, 0.0), (3.0, 6.0))
    var p = t.closest_point(Point(3.0, 2.0))
    assert_equal(p.x, 3.0)
    assert_equal(p.y, 2.0)


def test_triangle_contains_inside() raises -> None:
    var t = Triangle((0.0, 0.0), (6.0, 0.0), (3.0, 6.0))
    assert_true(t.contains((3.0, 2.0)))


def test_triangle_contains_outside() raises -> None:
    var t = Triangle((0.0, 0.0), (6.0, 0.0), (3.0, 6.0))
    assert_equal(t.contains((0.0, 5.0)), False)


def test_triangle_contains_vertex() raises -> None:
    # A vertex of the triangle is on its boundary — should be contained
    var t = Triangle((0.0, 0.0), (6.0, 0.0), (3.0, 6.0))
    assert_true(t.contains((0.0, 0.0)))


def test_triangle_translate() raises -> None:
    var t = Triangle((0.0, 0.0), (2.0, 0.0), (1.0, 2.0))
    t = t.translate(Vector(1.0, 1.0))
    assert_equal(t.a.x, 1.0)
    assert_equal(t.a.y, 1.0)
    assert_equal(t.b.x, 3.0)
    assert_equal(t.b.y, 1.0)


def test_triangle_move_to() raises -> None:
    # Triangle with center (1.5, 1.0); move center to (4.5, 4.0)
    var t = Triangle((0.0, 0.0), (3.0, 0.0), (1.5, 3.0))
    t = t.move_to((4.5, 4.0))
    assert_almost_equal(t.a.x, 3.0, atol=1e-9)
    assert_almost_equal(t.a.y, 3.0, atol=1e-9)
    assert_almost_equal(t.b.x, 6.0, atol=1e-9)
    assert_almost_equal(t.b.y, 3.0, atol=1e-9)
    assert_almost_equal(t.c.x, 4.5, atol=1e-9)
    assert_almost_equal(t.c.y, 6.0, atol=1e-9)


def test_rect_contains_vector() raises -> None:
    var r = Rectangle((0.0, 0.0), 10.0, 10.0)
    var inside = Point(2.0, 2.0)
    var outside = Point(8.0, 0.0)
    assert_true(r.contains(inside))
    assert_equal(r.contains(outside), False)


def test_circle_contains_vector() raises -> None:
    var c = Circle((0.0, 0.0), 5.0)
    var inside = Point(3.0, 4.0)
    var outside = Point(4.0, 4.0)
    assert_true(c.contains(inside))
    assert_equal(c.contains(outside), False)


# overlaps — one exact test per unordered shape pair, reached from either
# shape's method. Every case below checks both orderings agree.
def test_overlaps_rect_rect_yes() raises -> None:
    var a = Rectangle((0.0, 0.0), 10.0, 10.0)
    var b = Rectangle((4.0, 0.0), 10.0, 10.0)
    assert_true(a.overlaps(b))
    assert_equal(a.overlaps(b), b.overlaps(a))


def test_overlaps_rect_rect_no() raises -> None:
    var a = Rectangle((0.0, 0.0), 10.0, 10.0)
    var b = Rectangle((20.0, 0.0), 10.0, 10.0)
    assert_equal(a.overlaps(b), False)
    assert_equal(a.overlaps(b), b.overlaps(a))


def test_overlaps_rect_rect_touching_edge() raises -> None:
    # Touching counts as overlap everywhere, matching every contains()
    var a = Rectangle((0.0, 0.0), 10.0, 10.0)  # right=5
    var b = Rectangle((10.0, 0.0), 10.0, 10.0)  # left=5
    assert_true(a.overlaps(b))


def test_overlaps_rect_rect_touching_corner() raises -> None:
    var a = Rectangle((0.0, 0.0), 10.0, 10.0)  # right=5, top=5
    var b = Rectangle((10.0, 10.0), 10.0, 10.0)  # left=5, bottom=5
    assert_true(a.overlaps(b))


def test_overlaps_circle_circle_yes() raises -> None:
    var a = Circle((0.0, 0.0), 5.0)
    var b = Circle((8.0, 0.0), 5.0)
    assert_true(a.overlaps(b))
    assert_equal(a.overlaps(b), b.overlaps(a))


def test_overlaps_circle_circle_no() raises -> None:
    var a = Circle((0.0, 0.0), 5.0)
    var b = Circle((20.0, 0.0), 5.0)
    assert_equal(a.overlaps(b), False)
    assert_equal(a.overlaps(b), b.overlaps(a))


def test_overlaps_circle_circle_touching_boundary() raises -> None:
    # Circles touching at exactly one point — distance == r1+r2
    var a = Circle((0.0, 0.0), 5.0)
    var b = Circle((10.0, 0.0), 5.0)
    # distance_squared = 100, (r1+r2)^2 = 100: <=, so overlaps is True
    assert_true(a.overlaps(b))


def test_overlaps_rect_circle_yes() raises -> None:
    var r = Rectangle((0.0, 0.0), 10.0, 10.0)
    var c = Circle((6.0, 0.0), 3.0)
    assert_true(r.overlaps(c))
    assert_equal(r.overlaps(c), c.overlaps(r))


def test_overlaps_rect_circle_no() raises -> None:
    var r = Rectangle((0.0, 0.0), 10.0, 10.0)
    var c = Circle((10.0, 0.0), 1.0)
    assert_equal(r.overlaps(c), False)
    assert_equal(r.overlaps(c), c.overlaps(r))


def test_overlaps_rect_circle_touching_boundary() raises -> None:
    var r = Rectangle((0.0, 0.0), 10.0, 10.0)  # right=5
    var c = Circle((8.0, 0.0), 3.0)  # left edge at 5
    assert_true(r.overlaps(c))
    assert_equal(r.overlaps(c), c.overlaps(r))


def test_overlaps_rect_circle_regression_far_corner() raises -> None:
    # A long thin rectangle whose centre is far from the circle's nearest
    # corner: a.overlaps(b) reads only a's centre distance to b's nearest
    # point, so under the old generic (a.contains(b.closest_point(a.center)))
    # this pair gave a false negative depending on argument order. The
    # specialized overload here is exact regardless of which shape is a/b.
    var r = Rectangle((0.0, 0.0), 100.0, 2.0)  # x in [-50, 50], y in [-1, 1]
    var c = Circle((30.0, -20.0), 20.5)  # nearest rect point (30, -1)
    assert_true(r.overlaps(c))
    assert_equal(r.overlaps(c), c.overlaps(r))


def test_overlaps_circle_triangle_yes() raises -> None:
    var t = Triangle((0.0, 0.0), (6.0, 0.0), (3.0, 6.0))
    var c = Circle((3.0, 2.0), 1.0)  # centre inside the triangle
    assert_true(c.overlaps(t))
    assert_equal(c.overlaps(t), t.overlaps(c))


def test_overlaps_circle_triangle_no() raises -> None:
    var t = Triangle((0.0, 0.0), (6.0, 0.0), (3.0, 6.0))
    var c = Circle((100.0, 100.0), 1.0)
    assert_equal(c.overlaps(t), False)
    assert_equal(c.overlaps(t), t.overlaps(c))


def test_overlaps_circle_triangle_edge_only() raises -> None:
    # Circle's centre is outside the triangle; only the circle's rim reaches it.
    var t = Triangle((0.0, 0.0), (6.0, 0.0), (3.0, 6.0))
    var c = Circle((3.0, -2.0), 2.5)
    assert_true(c.overlaps(t))
    assert_equal(c.overlaps(t), t.overlaps(c))


def test_overlaps_rect_triangle_yes() raises -> None:
    var t = Triangle((0.0, 0.0), (6.0, 0.0), (3.0, 6.0))
    var r = Rectangle((3.0, 2.0), 2.0, 2.0)  # centre inside the triangle
    assert_true(r.overlaps(t))
    assert_equal(r.overlaps(t), t.overlaps(r))


def test_overlaps_rect_triangle_no() raises -> None:
    var t = Triangle((0.0, 0.0), (6.0, 0.0), (3.0, 6.0))
    var r = Rectangle((100.0, 100.0), 2.0, 2.0)
    assert_equal(r.overlaps(t), False)
    assert_equal(r.overlaps(t), t.overlaps(r))


def test_overlaps_rect_triangle_edge_only() raises -> None:
    # Neither shape's centre lies inside the other — a config a purely
    # centre-based generic test would get wrong.
    var rect = Rectangle((0.0, 0.0), 20.0, 2.0)
    var tri = Triangle((-1.0, -2.0), (1.0, 0.5), (3.0, -2.0))
    assert_equal(rect.contains(tri.center()), False)
    assert_equal(tri.contains(rect.center()), False)
    assert_true(rect.overlaps(tri))
    assert_equal(rect.overlaps(tri), tri.overlaps(rect))


def test_overlaps_triangle_triangle_yes() raises -> None:
    var a = Triangle((0.0, 0.0), (4.0, 0.0), (2.0, 4.0))
    var b = Triangle((1.0, 0.0), (5.0, 0.0), (3.0, 4.0))
    assert_true(a.overlaps(b))
    assert_equal(a.overlaps(b), b.overlaps(a))


def test_overlaps_triangle_triangle_no() raises -> None:
    var a = Triangle((0.0, 0.0), (2.0, 0.0), (1.0, 2.0))
    var b = Triangle((10.0, 0.0), (12.0, 0.0), (11.0, 2.0))
    assert_equal(a.overlaps(b), False)
    assert_equal(a.overlaps(b), b.overlaps(a))


def test_overlaps_triangle_triangle_touching_edge() raises -> None:
    # Mirrored across the shared base edge (0,0)-(4,0)
    var a = Triangle((0.0, 0.0), (4.0, 0.0), (2.0, 4.0))
    var b = Triangle((0.0, 0.0), (4.0, 0.0), (2.0, -4.0))
    assert_true(a.overlaps(b))
    assert_equal(a.overlaps(b), b.overlaps(a))


def test_overlaps_circle_triangle_symmetric_edge_case() raises -> None:
    var circ = Circle((6.0, -3.0), 2.0)
    var tri = Triangle((7.0, -4.0), (9.0, 2.0), (11.0, -4.0))
    assert_equal(circ.contains(tri.center()), False)
    assert_equal(tri.contains(circ.position), False)
    assert_equal(circ.overlaps(tri), tri.overlaps(circ))


# Degenerate geometry
def test_line_zero_length() raises -> None:
    var l = Line((2.0, 3.0), (2.0, 3.0))
    assert_equal(l.length(), 0.0)


def test_line_zero_length_intersects_when_on_segment() raises -> None:
    var l = Line((2.0, 3.0), (2.0, 3.0))
    var crossing = Line((0.0, 0.0), (4.0, 4.0))
    assert_equal(l.intersects(crossing), False)
    var touching = Line((2.0, 3.0), (5.0, 6.0))
    assert_true(l.intersects(touching))
    var far = Line((10.0, 10.0), (20.0, 20.0))
    assert_equal(l.intersects(far), False)


def test_circle_zero_radius_contains_only_center() raises -> None:
    var c = Circle((3.0, 4.0), 0.0)
    assert_true(c.contains((3.0, 4.0)))
    assert_equal(c.contains((3.001, 4.0)), False)


def test_circle_zero_radius_overlaps() raises -> None:
    var c = Circle((3.0, 4.0), 0.0)
    var covering = Circle((3.0, 4.0), 1.0)
    assert_true(c.overlaps(covering))
    var far = Circle((10.0, 10.0), 1.0)
    assert_equal(c.overlaps(far), False)


def test_circle_zero_radius_closest_point_is_center() raises -> None:
    var c = Circle((3.0, 4.0), 0.0)
    var p = c.closest_point((10.0, 4.0))
    assert_equal(p.x, 3.0)
    assert_equal(p.y, 4.0)


def test_triangle_collinear_vertices_contains() raises -> None:
    # Two coincident vertices plus a third: zero area, all three collinear.
    var t = Triangle((0.0, 0.0), (0.0, 0.0), (4.0, 0.0))
    assert_true(t.contains((0.0, 0.0)))
    assert_true(t.contains((2.0, 0.0)))
    # Off the shared line entirely — not contained
    assert_equal(t.contains((2.0, 1.0)), False)


def test_triangle_collinear_vertices_closest_point_reaches_zero_length_edge() raises -> (
    None
):
    # The (0,0)-(0,0) edge has len_sq == 0, exercising _closest_on_segment's
    # explicit zero-length branch (otherwise unreached by any other test).
    var t = Triangle((0.0, 0.0), (0.0, 0.0), (4.0, 0.0))
    var p = t.closest_point((2.0, 5.0))
    assert_equal(p.x, 2.0)
    assert_equal(p.y, 0.0)


def test_triangle_collinear_vertices_overlaps() raises -> None:
    var t = Triangle((0.0, 0.0), (0.0, 0.0), (4.0, 0.0))
    var covering = Rectangle((2.0, 0.0), 2.0, 2.0)
    assert_equal(t.overlaps(covering), covering.overlaps(t))
    assert_true(t.overlaps(covering))


def test_triangle_distinct_collinear_vertices_rejects_off_segment_point() raises -> (
    None
):
    # Three distinct collinear vertices along y = x. (50, 50) sits on that
    # infinite line but far outside the segment -- must not be "contained".
    var t = Triangle((0.0, 0.0), (1.0, 1.0), (2.0, 2.0))
    assert_equal(t.contains((50.0, 50.0)), False)


def test_triangle_distinct_collinear_vertices_contains_hull_point() raises -> (
    None
):
    var t = Triangle((0.0, 0.0), (1.0, 1.0), (2.0, 2.0))
    assert_true(t.contains((1.0, 1.0)))


def test_triangle_fully_degenerate_point() raises -> None:
    var t = Triangle((0.0, 0.0), (0.0, 0.0), (0.0, 0.0))
    assert_true(t.contains((0.0, 0.0)))
    assert_equal(t.contains((1.0, 0.0)), False)


def test_overlaps_circle_distinct_collinear_triangle_far_away() raises -> None:
    var t = Triangle((0.0, 0.0), (1.0, 1.0), (2.0, 2.0))
    var c = Circle((50.0, 50.0), 1.0)
    assert_equal(c.overlaps(t), False)


def test_overlaps_zero_width_rect_and_far_triangle() raises -> None:
    var r = Rectangle((0.0, 0.0), 0.0, 4.0)
    var t = Triangle((10.0, 0.0), (12.0, 2.0), (12.0, -2.0))
    assert_equal(r.overlaps(t), False)


def test_overlaps_disjoint_collinear_degenerate_rects() raises -> None:
    var a = Rectangle((0.0, 0.0), 0.0, 4.0)
    var b = Rectangle((0.0, 10.0), 0.0, 4.0)
    assert_equal(a.overlaps(b), False)


def test_overlaps_collapsed_points_at_different_positions() raises -> None:
    var a = Rectangle((0.0, 0.0), 0.0, 0.0)
    var b = Rectangle((5.0, 5.0), 0.0, 0.0)
    assert_equal(a.overlaps(b), False)


def test_overlaps_collapsed_point_inside_triangle() raises -> None:
    var point = Rectangle((1.0, 1.0), 0.0, 0.0)
    var t = Triangle((0.0, 0.0), (4.0, 0.0), (0.0, 4.0))
    assert_true(point.overlaps(t))


def test_rect_contains_rect_yes() raises -> None:
    var outer = Rectangle((0.0, 0.0), 10.0, 10.0)
    var inner = Rectangle((1.0, 1.0), 4.0, 4.0)
    assert_true(outer.contains(inner))


def test_rect_contains_rect_overlapping_not_contained() raises -> None:
    var a = Rectangle((0.0, 0.0), 10.0, 10.0)
    var b = Rectangle((8.0, 8.0), 6.0, 6.0)
    assert_true(a.overlaps(b))
    assert_equal(a.contains(b), False)


def test_rect_contains_rect_boundary_coincident() raises -> None:
    var outer = Rectangle((0.0, 0.0), 10.0, 10.0)
    var same = Rectangle((0.0, 0.0), 10.0, 10.0)
    assert_true(outer.contains(same))


def test_rect_contains_circle_yes() raises -> None:
    var r = Rectangle((0.0, 0.0), 10.0, 10.0)
    var c = Circle((0.0, 0.0), 2.0)
    assert_true(r.contains(c))


def test_rect_contains_circle_overlapping_not_contained() raises -> None:
    var r = Rectangle((0.0, 0.0), 10.0, 10.0)
    var c = Circle((5.0, 5.0), 2.0)
    assert_true(r.overlaps(c))
    assert_equal(r.contains(c), False)


def test_rect_contains_triangle_yes() raises -> None:
    var r = Rectangle((0.0, 0.0), 10.0, 10.0)
    var t = Triangle((-1.0, -1.0), (1.0, -1.0), (0.0, 1.0))
    assert_true(r.contains(t))


def test_rect_contains_triangle_overlapping_not_contained() raises -> None:
    var r = Rectangle((0.0, 0.0), 10.0, 10.0)
    var t = Triangle((4.0, 4.0), (8.0, 4.0), (4.0, 8.0))
    assert_true(r.overlaps(t))
    assert_equal(r.contains(t), False)


def test_rect_contains_line_yes() raises -> None:
    var r = Rectangle((0.0, 0.0), 10.0, 10.0)
    var l = Line((-2.0, -2.0), (2.0, 2.0))
    assert_true(r.contains(l))


def test_rect_contains_line_no() raises -> None:
    var r = Rectangle((0.0, 0.0), 10.0, 10.0)
    var l = Line((-2.0, -2.0), (20.0, 2.0))
    assert_equal(r.contains(l), False)


def test_circle_contains_circle_yes() raises -> None:
    var outer = Circle((0.0, 0.0), 10.0)
    var inner = Circle((1.0, 1.0), 2.0)
    assert_true(outer.contains(inner))


def test_circle_contains_circle_overlapping_not_contained() raises -> None:
    var a = Circle((0.0, 0.0), 5.0)
    var b = Circle((6.0, 0.0), 3.0)
    assert_true(a.overlaps(b))
    assert_equal(a.contains(b), False)


def test_circle_contains_circle_boundary_coincident() raises -> None:
    var outer = Circle((0.0, 0.0), 10.0)
    var inner = Circle((4.0, 0.0), 6.0)
    assert_true(outer.contains(inner))


def test_circle_contains_rect_yes() raises -> None:
    var c = Circle((0.0, 0.0), 10.0)
    var r = Rectangle((0.0, 0.0), 4.0, 4.0)
    assert_true(c.contains(r))


def test_circle_contains_rect_overlapping_not_contained() raises -> None:
    var c = Circle((0.0, 0.0), 5.0)
    var r = Rectangle((4.0, 4.0), 4.0, 4.0)
    assert_true(c.overlaps(r))
    assert_equal(c.contains(r), False)


def test_circle_contains_triangle_yes() raises -> None:
    var c = Circle((0.0, 0.0), 10.0)
    var t = Triangle((-1.0, -1.0), (1.0, -1.0), (0.0, 1.0))
    assert_true(c.contains(t))


def test_circle_contains_triangle_overlapping_not_contained() raises -> None:
    var c = Circle((0.0, 0.0), 5.0)
    var t = Triangle((0.0, 0.0), (8.0, 0.0), (0.0, 8.0))
    assert_true(c.overlaps(t))
    assert_equal(c.contains(t), False)


def test_circle_contains_line_yes() raises -> None:
    var c = Circle((0.0, 0.0), 10.0)
    var l = Line((-2.0, -2.0), (2.0, 2.0))
    assert_true(c.contains(l))


def test_circle_contains_line_no() raises -> None:
    var c = Circle((0.0, 0.0), 10.0)
    var l = Line((-2.0, -2.0), (20.0, 2.0))
    assert_equal(c.contains(l), False)


def test_triangle_contains_triangle_yes() raises -> None:
    var outer = Triangle((-10.0, -10.0), (10.0, -10.0), (0.0, 10.0))
    var inner = Triangle((-1.0, -1.0), (1.0, -1.0), (0.0, 1.0))
    assert_true(outer.contains(inner))


def test_triangle_contains_triangle_overlapping_not_contained() raises -> None:
    var a = Triangle((-10.0, -10.0), (10.0, -10.0), (0.0, 10.0))
    var b = Triangle((0.0, 0.0), (20.0, 0.0), (20.0, 20.0))
    assert_true(a.overlaps(b))
    assert_equal(a.contains(b), False)


def test_triangle_contains_rect_yes() raises -> None:
    var t = Triangle((-10.0, -10.0), (10.0, -10.0), (0.0, 10.0))
    var r = Rectangle((0.0, -8.0), 2.0, 2.0)
    assert_true(t.contains(r))


def test_triangle_contains_rect_overlapping_not_contained() raises -> None:
    var t = Triangle((-10.0, -10.0), (10.0, -10.0), (0.0, 10.0))
    var r = Rectangle((0.0, 8.0), 6.0, 6.0)
    assert_true(t.overlaps(r))
    assert_equal(t.contains(r), False)


def test_triangle_contains_circle_yes() raises -> None:
    var t = Triangle((-10.0, -10.0), (10.0, -10.0), (0.0, 10.0))
    var c = Circle((0.0, -8.0), 1.0)
    assert_true(t.contains(c))


def test_triangle_contains_circle_bulges_past_edge_rejected() raises -> None:
    var t = Triangle((-10.0, -10.0), (10.0, -10.0), (0.0, 10.0))
    var c = Circle((0.0, -9.5), 1.0)
    assert_true(t.contains(c.center()))
    assert_equal(t.contains(c), False)


def test_triangle_contains_line_yes() raises -> None:
    var t = Triangle((-10.0, -10.0), (10.0, -10.0), (0.0, 10.0))
    var l = Line((-1.0, -8.0), (1.0, -8.0))
    assert_true(t.contains(l))


def test_triangle_contains_line_no() raises -> None:
    var t = Triangle((-10.0, -10.0), (10.0, -10.0), (0.0, 10.0))
    var l = Line((-1.0, -8.0), (100.0, -8.0))
    assert_equal(t.contains(l), False)


def test_rect_area() raises -> None:
    var r = Rectangle((0.0, 0.0), 4.0, 5.0)
    assert_equal(r.area(), 20.0)


def test_circle_area() raises -> None:
    var c = Circle((0.0, 0.0), 2.0)
    assert_almost_equal(c.area(), PI * 4.0)


def test_circle_diameter() raises -> None:
    var c = Circle((0.0, 0.0), 2.5)
    assert_equal(c.diameter(), 5.0)


def test_triangle_area() raises -> None:
    var t = Triangle((0.0, 0.0), (4.0, 0.0), (0.0, 3.0))
    assert_equal(t.area(), 6.0)


def test_triangle_area_degenerate_is_zero() raises -> None:
    var t = Triangle((0.0, 0.0), (2.0, 0.0), (4.0, 0.0))
    assert_equal(t.area(), 0.0)


def test_rect_bounds_is_itself() raises -> None:
    var r = Rectangle((4.0, 2.0), 10.0, 6.0)
    assert_equal(r.bounds(), r)


def test_circle_bounds() raises -> None:
    var b = Circle((1.0, -2.0), 3.0).bounds()
    assert_equal(b, Rectangle((1.0, -2.0), 6.0, 6.0))


def test_triangle_bounds() raises -> None:
    var b = Triangle((0.0, 0.0), (4.0, 1.0), (1.0, 3.0)).bounds()
    assert_equal(b, Rectangle((2.0, 1.5), 4.0, 3.0))


# The Point/Vector boundary — positions are locations, displacements
# are vectors, and these are the signatures naming both.
def test_center_difference_is_a_displacement() raises -> None:
    var r = Rectangle(Point(10.0, 0.0), 4.0, 4.0)
    var c = Circle(Point(4.0, 0.0), 1.0)
    var d: Vector = r.center() - c.center()
    assert_equal(d, Vector(6.0, 0.0))


def test_move_to_a_displaced_center() raises -> None:
    """`move_to(center() + delta)` is the round trip the split has to allow:
    a position plus a displacement is a position."""
    var r = Rectangle(Point(1.0, 2.0), 4.0, 4.0)
    r = r.move_to(r.center() + Vector(3.0, 4.0))
    assert_equal(r.center(), Point(4.0, 6.0))


def test_translate_by_a_displacement() raises -> None:
    var r = Rectangle(Point(1.0, 2.0), 4.0, 4.0)
    r = r.translate(Vector(2.0, 3.0))
    assert_equal(r.center(), Point(3.0, 5.0))
    var c = Circle(Point(1.0, 2.0), 1.0)
    c = c.translate(Vector(2.0, 3.0))
    assert_equal(c.center(), Point(3.0, 5.0))
    var l = Line(Point(0.0, 0.0), Point(2.0, 0.0))
    l = l.translate(Vector(1.0, 1.0))
    assert_equal(l.midpoint(), Point(2.0, 1.0))
    var t = Triangle(Point(0.0, 0.0), Point(4.0, 0.0), Point(0.0, 3.0))
    t = t.translate(Vector(1.0, 1.0))
    assert_equal(t.center(), Point(1.0 + 4.0 / 3.0, 2.0))


def test_shapes_still_take_bare_tuples() raises -> None:
    """The implicit constructors are why the split costs a call site
    nothing."""
    var r = Rectangle((1, 2), 10, 6)
    assert_equal(r.center(), Point(1.0, 2.0))
    assert_true(r.contains((1.0, 2.0)))


# --- write_to -----------------------------------------------------------------


def test_shapes_write_keyword_form() raises -> None:
    assert_equal(
        String(Rectangle(Point(1.0, 2.0), 3.0, 4.0)),
        "Rectangle(position=Point(1.0, 2.0), width=3.0, height=4.0)",
    )
    assert_equal(
        String(Circle(Point(1.0, 2.0), 3.0)),
        "Circle(position=Point(1.0, 2.0), radius=3.0)",
    )
    assert_equal(
        String(Line(Point(0.0, 0.0), Point(1.0, 1.0))),
        "Line(start=Point(0.0, 0.0), end=Point(1.0, 1.0))",
    )
    assert_equal(
        String(Triangle(Point(0.0, 0.0), Point(1.0, 0.0), Point(0.0, 1.0))),
        "Triangle(a=Point(0.0, 0.0), b=Point(1.0, 0.0), c=Point(0.0, 1.0))",
    )


# --- value semantics ----------------------------------------------------------


def test_shapes_compare_by_fields() raises -> None:
    var r = Rectangle(Point(1.0, 2.0), 3.0, 4.0)
    assert_true(r == Rectangle(Point(1.0, 2.0), 3.0, 4.0))
    assert_true(r != Rectangle(Point(1.0, 2.0), 3.0, 5.0))
    var c = Circle(Point(1.0, 2.0), 3.0)
    assert_true(c == Circle(Point(1.0, 2.0), 3.0))
    assert_true(c != Circle(Point(0.0, 2.0), 3.0))
    var l = Line(Point(0.0, 0.0), Point(1.0, 1.0))
    assert_true(l == Line(Point(0.0, 0.0), Point(1.0, 1.0)))
    assert_true(l != Line(Point(1.0, 1.0), Point(0.0, 0.0)))
    var t = Triangle(Point(0.0, 0.0), Point(1.0, 0.0), Point(0.0, 1.0))
    assert_true(
        t == Triangle(Point(0.0, 0.0), Point(1.0, 0.0), Point(0.0, 1.0))
    )
    assert_true(
        t != Triangle(Point(0.0, 1.0), Point(1.0, 0.0), Point(0.0, 0.0))
    )


@fieldwise_init
struct _Entity(Copyable):
    var hitbox: Rectangle


def test_shapes_copy_implicitly() raises -> None:
    """A shape held as a field leaves its owner copyable, and a copy is
    independent of the original."""
    var original = _Entity(Rectangle(Point(0.0, 0.0), 2.0, 2.0))
    var copy = original.copy()
    copy.hitbox = copy.hitbox.translate(Vector(1.0, 0.0))
    var r = original.hitbox
    assert_false(copy.hitbox == r)
    assert_equal(r.position.x, 0.0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
