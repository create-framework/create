from std.testing import (
    TestSuite,
    assert_equal,
    assert_true,
    assert_almost_equal,
)
from std.math import cos, sin
from create.math import PI, TAU
from create.geometry import (
    Arc,
    Circle,
    Line,
    Polygon,
    Rectangle,
    Sector,
    Triangle,
)
from create.math.point import Point
from create.math.vector import Vector


def _assert_point_near(p: Point, q: Point, tol: Float64 = 1e-9) raises:
    assert_almost_equal(p.x, q.x, atol=tol)
    assert_almost_equal(p.y, q.y, atol=tol)


def _square() -> Polygon:
    return Polygon((0, 0), (10, 0), (10, 10), (0, 10))


def _l_shape() -> Polygon:
    """A 10 by 10 square missing its top-right quarter: concave, with the
    notch at (7.5, 7.5)."""
    return Polygon((0, 0), (10, 0), (10, 5), (5, 5), (5, 10), (0, 10))


def _pentagram() -> Polygon:
    """Five points on a circle joined every second one: the edges cross,
    and the inner pentagon is wound twice."""
    var vertices = List[Point]()
    for i in range(5):
        var angle = TAU / 4.0 + 2.0 * TAU * Float64(i) / 5.0
        vertices.append(Point(10.0 * cos(angle), 10.0 * sin(angle)))
    return Polygon(vertices^)


def test_variadic_and_list_constructors_agree() raises -> None:
    var from_list = Polygon([Point(0, 0), Point(10, 0), Point(5, 8)])
    assert_true(Polygon((0, 0), (10, 0), (5, 8)) == from_list)
    assert_true(Polygon((0, 0), (10, 0), (5, 9)) != from_list)


def test_prints_in_keyword_form() raises -> None:
    assert_equal(
        String(Polygon((1, 2), (3.5, 4))),
        "Polygon(vertices=[Point(1.0, 2.0), Point(3.5, 4.0)])",
    )


def test_regular_starts_straight_up() raises -> None:
    var p = Polygon.regular((0, 0), 10, 6)
    assert_equal(len(p.vertices), 6)
    _assert_point_near(p.vertices[0], Point(0.0, 10.0))
    for v in p.vertices:
        assert_almost_equal((v - Point(0, 0)).magnitude(), 10.0)
    # Counter-clockwise: the second vertex is up and to the left.
    assert_true(p.vertices[1].x < 0.0 and p.vertices[1].y > 0.0)


def test_regular_start_angle_and_position() raises -> None:
    var p = Polygon.regular((5, -3), 2, 4, start_angle=0.0)
    _assert_point_near(p.vertices[0], Point(7.0, -3.0))
    _assert_point_near(p.vertices[1], Point(5.0, -1.0))
    _assert_point_near(p.center(), Point(5.0, -3.0))


def test_star_alternates_radii() raises -> None:
    var s = Polygon.star((0, 0), 10, 4, 5)
    assert_equal(len(s.vertices), 10)
    _assert_point_near(s.vertices[0], Point(0.0, 10.0))
    for i in range(10):
        var expected = 10.0 if i % 2 == 0 else 4.0
        assert_almost_equal((s.vertices[i] - Point(0, 0)).magnitude(), expected)
    # The first inner vertex sits halfway to the second tip.
    var angle = TAU / 4.0 + PI / 5.0
    _assert_point_near(s.vertices[1], Point(4.0 * cos(angle), 4.0 * sin(angle)))


def test_area_and_center_of_a_square() raises -> None:
    assert_almost_equal(_square().area(), 100.0)
    _assert_point_near(_square().center(), Point(5.0, 5.0))


def test_area_and_center_of_a_concave_polygon() raises -> None:
    var l = _l_shape()
    assert_almost_equal(l.area(), 75.0)
    # Three 5 by 5 squares at (2.5, 2.5), (7.5, 2.5), (2.5, 7.5).
    _assert_point_near(l.center(), Point(12.5 / 3.0, 12.5 / 3.0))


def test_winding_does_not_change_area() raises -> None:
    var clockwise = Polygon((0, 0), (0, 10), (10, 10), (10, 0))
    assert_almost_equal(clockwise.area(), 100.0)
    _assert_point_near(clockwise.center(), Point(5.0, 5.0))


def test_star_center_is_its_position() raises -> None:
    _assert_point_near(
        Polygon.star((3, 4), 10, 4, 5).center(), Point(3.0, 4.0), 1e-9
    )


def test_degenerate_center_is_the_vertex_mean() raises -> None:
    _assert_point_near(Polygon((0, 0), (4, 0), (8, 0)).center(), (4.0, 0.0))
    _assert_point_near(Polygon().center(), Point(0.0, 0.0))
    assert_almost_equal(Polygon((0, 0), (4, 0)).area(), 0.0)


def test_bounds() raises -> None:
    var b = Polygon((-1, 2), (4, -3), (0, 6)).bounds()
    assert_equal(b, Rectangle((1.5, 1.5), 5.0, 9.0))
    assert_equal(Polygon().bounds(), Rectangle((0, 0), 0.0, 0.0))


def test_contains_convex() raises -> None:
    var sq = _square()
    assert_true(sq.contains(Point(5, 5)))
    assert_true(not sq.contains(Point(11, 5)))
    assert_true(not sq.contains(Point(-1, 5)))


def test_contains_the_boundary() raises -> None:
    var sq = _square()
    assert_true(sq.contains(Point(10, 5)))
    assert_true(sq.contains(Point(5, 0)))
    assert_true(sq.contains(Point(10, 10)))
    assert_true(sq.contains(Point(0, 0)))


def test_contains_concave() raises -> None:
    var l = _l_shape()
    assert_true(l.contains(Point(2.5, 7.5)))
    assert_true(l.contains(Point(7.5, 2.5)))
    assert_true(not l.contains(Point(7.5, 7.5)))
    # The reflex corner itself is on the boundary.
    assert_true(l.contains(Point(5, 5)))


def test_contains_is_nonzero_through_a_pentagram() raises -> None:
    var star = _pentagram()
    # The inner pentagon is wound twice: still inside under nonzero.
    assert_true(star.contains(Point(0, 0)))
    # A tip is wound once.
    assert_true(star.contains(Point(0, 8)))
    # Between two tips, outside.
    assert_true(not star.contains(Point(0, -9)))


def test_contains_ignores_winding() raises -> None:
    var clockwise = Polygon((0, 0), (0, 10), (10, 10), (10, 0))
    assert_true(clockwise.contains(Point(5, 5)))
    assert_true(not clockwise.contains(Point(15, 5)))


def test_contains_horizontal_ray_through_a_vertex() raises -> None:
    # The ray to the right of (0, 5) passes exactly through the vertex
    # (5, 5) -- counted once, not twice.
    var diamond = Polygon((5, 0), (10, 5), (5, 10), (0, 5))
    assert_true(diamond.contains(Point(1, 5)))
    assert_true(not diamond.contains(Point(-1, 5)))


def test_degenerate_polygon_is_its_edges() raises -> None:
    var segment = Polygon((0, 0), (10, 0))
    assert_true(segment.contains(Point(5, 0)))
    assert_true(not segment.contains(Point(5, 1)))
    var point = Polygon((2, 3))
    assert_true(point.contains(Point(2, 3)))
    assert_true(not point.contains(Point(2, 4)))
    assert_true(not Polygon().contains(Point(0, 0)))


def test_closest_point() raises -> None:
    var l = _l_shape()
    _assert_point_near(l.closest_point(Point(2, 2)), Point(2.0, 2.0))
    _assert_point_near(l.closest_point(Point(8, 7)), Point(8.0, 5.0))
    _assert_point_near(l.closest_point(Point(-3, 4)), Point(0.0, 4.0))


def test_move_to_moves_the_centroid() raises -> None:
    var l = _l_shape()
    l = l.move_to(Point(0, 0))
    _assert_point_near(l.center(), Point(0.0, 0.0))
    _assert_point_near(l.vertices[0], Point(-12.5 / 3.0, -12.5 / 3.0))


def test_translate() raises -> None:
    var sq = _square()
    sq = sq.translate(Vector(1, -2))
    assert_equal(sq.vertices[0], Point(1.0, -2.0))
    assert_equal(sq.vertices[2], Point(11.0, 8.0))


def test_pieces_split_the_rim_from_the_seams() raises -> None:
    var simple = _l_shape()._pieces()
    assert_equal(len(simple[0]), 6)
    assert_equal(len(simple[1]), 0)
    # Each edge is cut in three: its ends run along the outside, its middle
    # through the doubly wound centre.
    var star = _pentagram()._pieces()
    assert_equal(len(star[0]), 10)
    assert_equal(len(star[1]), 5)
    for seam in star[1]:
        assert_true(seam.midpoint().distance(Point(0, 0)) < 5.0)


def test_overlaps_circle() raises -> None:
    var l = _l_shape()
    # Sitting in the notch, clear of both arms.
    var in_notch = Circle((8, 8), 1.5)
    assert_true(not l.overlaps(in_notch))
    assert_true(not in_notch.overlaps(l))
    # Tangent to both edges of the notch.
    var touching = Circle((8, 8), 3)
    assert_true(l.overlaps(touching) and touching.overlaps(l))
    # Polygon wholly inside a circle, and a circle wholly inside the arm.
    var around = Circle((5, 5), 20)
    assert_true(l.overlaps(around) and around.overlaps(l))
    var inside = Circle((2.5, 2.5), 1)
    assert_true(l.overlaps(inside) and inside.overlaps(l))


def test_overlaps_rectangle() raises -> None:
    var l = _l_shape()
    var in_notch = Rectangle((8, 8), 3, 3)
    assert_true(not l.overlaps(in_notch) and not in_notch.overlaps(l))
    # Sharing the notch's edge counts.
    var on_edge = Rectangle((7.5, 6), 5, 2)
    assert_true(l.overlaps(on_edge) and on_edge.overlaps(l))
    var around = Rectangle((5, 5), 30, 30)
    assert_true(l.overlaps(around) and around.overlaps(l))
    var inside = Rectangle((2, 2), 1, 1)
    assert_true(l.overlaps(inside) and inside.overlaps(l))
    var far = Rectangle((30, 0), 2, 2)
    assert_true(not l.overlaps(far) and not far.overlaps(l))


def test_overlaps_triangle() raises -> None:
    var l = _l_shape()
    var in_notch = Triangle((6, 6), (9, 6), (6, 9))
    assert_true(not l.overlaps(in_notch) and not in_notch.overlaps(l))
    # Bridging the notch from arm to arm, all vertices outside the L.
    var bridging = Triangle((7, 12), (12, 7), (12, 12))
    assert_true(not l.overlaps(bridging))
    var crossing = Triangle((2, 12), (12, 2), (12, 12))
    assert_true(l.overlaps(crossing) and crossing.overlaps(l))
    var around = Triangle((-20, -20), (40, -20), (5, 40))
    assert_true(l.overlaps(around) and around.overlaps(l))


def test_overlaps_sector() raises -> None:
    var l = _l_shape()
    # The notch holds a quarter disc pointing into its corner.
    var in_notch = Sector((9, 9), 3, PI, PI / 2.0)
    assert_true(not l.overlaps(in_notch) and not in_notch.overlaps(l))
    # The tip inside the polygon.
    var tip_inside = Sector((2, 2), 50, 0.0, 0.1)
    assert_true(l.overlaps(tip_inside) and tip_inside.overlaps(l))
    # Reaching in from outside, the tip clear of the polygon.
    var arc_reaches = Sector((20, 2), 11, PI - 0.2, 0.4)
    assert_true(l.overlaps(arc_reaches) and arc_reaches.overlaps(l))
    # The polygon wholly inside the sector.
    var around = Sector((-5, -5), 40, 0.0, PI / 2.0)
    assert_true(l.overlaps(around) and around.overlaps(l))


def test_overlaps_polygon() raises -> None:
    var l = _l_shape()
    var in_notch = Polygon.regular((8, 8), 1.5, 5)
    assert_true(not l.overlaps(in_notch) and not in_notch.overlaps(l))
    var small = Polygon.regular((2, 2), 1, 6)
    assert_true(l.overlaps(small) and small.overlaps(l))
    var big = Polygon.regular((5, 5), 30, 3)
    assert_true(l.overlaps(big) and big.overlaps(l))
    assert_true(l.overlaps(l))
    assert_true(not l.overlaps(Polygon()) and not Polygon().overlaps(l))


def test_overlaps_follow_the_nonzero_rule() raises -> None:
    # A square wound twice around a hole: the outer ring counts once, the
    # hole zero times -- a shape in the hole overlaps nothing.
    var ring = Polygon(
        (0, 0),
        (10, 0),
        (10, 10),
        (0, 10),
        (0, 0),
        (3, 3),
        (3, 7),
        (7, 7),
        (7, 3),
        (3, 3),
    )
    assert_true(not ring.contains(Point(5, 5)))
    var in_hole = Circle((5, 5), 1)
    assert_true(not ring.overlaps(in_hole) and not in_hole.overlaps(ring))
    var in_hole_polygon = Polygon.regular((5, 5), 1, 4)
    assert_true(not ring.overlaps(in_hole_polygon))
    assert_true(not in_hole_polygon.overlaps(ring))
    # The pentagram's doubly wound centre is filled.
    var star = _pentagram()
    var at_center = Rectangle((0, 0), 1, 1)
    assert_true(star.overlaps(at_center) and at_center.overlaps(star))


def test_line_intersects() raises -> None:
    var l = _l_shape()
    # Across the notch, touching neither arm.
    assert_true(not Line((6, 9), (9, 6)).intersects(l))
    assert_true(Line((2, 2), (3, 3)).intersects(l))
    assert_true(Line((-5, 2), (20, 2)).intersects(l))
    assert_true(Line((5, 12), (5, 5)).intersects(l))
    assert_true(not Line((20, 20), (30, 20)).intersects(l))


def test_arc_intersects() raises -> None:
    var l = _l_shape()
    assert_true(not Arc((10, 10), 3, PI, PI / 2.0).intersects(l))
    assert_true(Arc((10, 10), 6, PI, PI / 2.0).intersects(l))
    assert_true(Arc((2, 2), 1, 0.0, TAU).intersects(l))
    assert_true(not Arc((30, 30), 2, 0.0, TAU).intersects(l))


def _ring() -> Polygon:
    """A 10 by 10 square wound round a 4 by 4 hole in its middle: the
    hole is wound once each way, so it is outside."""
    return Polygon(
        (0, 0),
        (10, 0),
        (10, 10),
        (0, 10),
        (0, 0),
        (3, 3),
        (3, 7),
        (7, 7),
        (7, 3),
        (3, 3),
    )


def test_contains_line() raises -> None:
    var l = _l_shape()
    assert_true(l.contains(Line((1, 1), (9, 1))))
    # Along an edge, and ending on the reflex corner.
    assert_true(l.contains(Line((0, 0), (0, 10))))
    assert_true(l.contains(Line((1, 9), (5, 5))))
    # Both ends inside, across the notch.
    assert_true(not l.contains(Line((1, 9), (9, 1.5))))
    assert_true(not l.contains(Line((1, 1), (11, 1))))


def test_contains_rectangle() raises -> None:
    var l = _l_shape()
    assert_true(l.contains(Rectangle((2.5, 5), 5, 10)))
    assert_true(l.contains(Rectangle((5, 2.5), 10, 5)))
    # Its corners in both arms, its middle in the notch.
    assert_true(not l.contains(Rectangle((5, 5), 9, 9)))
    assert_true(not l.contains(Rectangle((5, 2.5), 11, 5)))


def test_contains_triangle() raises -> None:
    var l = _l_shape()
    # Every vertex inside; the long edge touches the reflex corner.
    assert_true(l.contains(Triangle((1, 1), (9, 1), (1, 9))))
    # Every vertex inside; the long edge crosses the notch.
    assert_true(not l.contains(Triangle((1, 1), (9.5, 1), (1, 9.5))))


def test_contains_circle() raises -> None:
    var l = _l_shape()
    assert_true(l.contains(Circle((2.5, 2.5), 2.5)))
    assert_true(not l.contains(Circle((2.5, 2.5), 2.6)))
    # Round the reflex corner: its middle is inside, its rim is not.
    assert_true(not l.contains(Circle((4, 4), 1.5)))


def test_contains_sector() raises -> None:
    var l = _l_shape()
    assert_true(l.contains(Sector((0, 0), 5, 0.0, PI / 2.0)))
    # Reaching round the reflex corner.
    assert_true(not l.contains(Sector((0, 0), 9, 0.0, PI / 2.0)))
    # Only the arc strays out.
    assert_true(not l.contains(Sector((4, 4), 2, 0.0, PI / 2.0)))


def test_contains_polygon() raises -> None:
    var l = _l_shape()
    assert_true(l.contains(l))
    assert_true(l.contains(Polygon.regular((2.5, 2.5), 2, 6)))
    # Vertices in both arms, bridging the notch.
    assert_true(not l.contains(Polygon((1, 1), (9, 1), (9, 4), (4, 9), (1, 9))))
    # A concave polygon fitting the L's own corner.
    assert_true(l.contains(Polygon((0, 0), (10, 0), (10, 5), (5, 5), (0, 5))))
    assert_true(Polygon.regular((5, 5), 20, 5).contains(l))
    # (10, 0) lies past the pentagon's edge.
    assert_true(not Polygon.regular((0, 0), 10, 5).contains(l))


def test_contains_nonzero_through_a_pentagram() raises -> None:
    var star = _pentagram()
    # Across the doubly wound middle, beyond the inner pentagon's edges.
    assert_true(star.contains(Circle((0, 0), 3.5)))
    assert_true(star.contains(Polygon.regular((0, 0), 3.5, 7)))
    # Out past the inner vertices, between the tips.
    assert_true(not star.contains(Circle((0, 0), 4.5)))


def test_contains_no_shape_round_a_hole() raises -> None:
    var ring = _ring()
    # Its outline in the ring, the hole in its middle.
    assert_true(not ring.contains(Rectangle((5, 5), 9, 9)))
    assert_true(not ring.contains(Circle((5, 5), 4.5)))
    assert_true(not ring.contains(Triangle((1, 1), (9, 1), (5, 9.5))))
    assert_true(not ring.contains(Sector((1, 1), 8, 0.0, PI / 2.0)))
    assert_true(not ring.contains(Polygon.regular((5, 5), 4.5, 8)))
    # A strip down one side, across the edges that reach in to the hole.
    assert_true(ring.contains(Rectangle((1.5, 5), 2, 9)))
    assert_true(ring.contains(Circle((1.5, 1.5), 1.2)))
    assert_true(ring.contains(Polygon.regular((1.5, 1.5), 1.2, 6)))


def test_contains_across_a_horizontal_edge_wound_both_sides() raises -> None:
    # The ring again, reaching in to its hole along y = 5: that edge is
    # inside on both sides, read across in y.
    var ring = Polygon(
        (0, 5),
        (0, 0),
        (10, 0),
        (10, 10),
        (0, 10),
        (0, 5),
        (3, 5),
        (3, 7),
        (7, 7),
        (7, 3),
        (3, 3),
        (3, 5),
    )
    assert_true(ring.contains(Rectangle((1.5, 5), 2, 9)))
    assert_true(ring.contains(Circle((1.5, 5), 1.2)))
    assert_true(not ring.contains(Rectangle((5, 5), 9, 9)))


def test_contains_itself_and_shapes_on_its_corners() raises -> None:
    # Corners from cos and sin: a piece along an edge has its computed
    # middle a rounding error off it, which must still count as held.
    for sides in range(3, 12):
        var p = Polygon.regular(Point(0.0, 0.0), 2.0, sides=sides)
        assert_true(p.contains(p))
        for edge in p._edges():
            assert_true(p.contains(edge))
    var r = Rectangle((0.3, 0.1), 2.0, 1.0, rotation=0.3)
    var corners = r._points()
    assert_true(
        Polygon(corners[0], corners[1], corners[2], corners[3]).contains(r)
    )
    var t = Triangle((0.1, 0.0), (4.3, 0.2), (1.1, 3.7))
    assert_true(Polygon(t.a, t.b, t.c).contains(t))


def test_regions_contain_a_polygon() raises -> None:
    var l = _l_shape()
    assert_true(Rectangle((5, 5), 10, 10).contains(l))
    assert_true(not Rectangle((5, 5), 10, 9).contains(l))
    assert_true(Circle((5, 5), 7.1).contains(l))
    assert_true(not Circle((5, 5), 7).contains(l))
    assert_true(Triangle((0, 0), (20, 0), (0, 20)).contains(l))
    assert_true(not Triangle((0, 0), (14, 0), (0, 14)).contains(l))
    assert_true(Sector((0, 0), 12, 0.0, PI / 2.0).contains(l))
    assert_true(not Sector((0, 0), 11, 0.0, PI / 2.0).contains(l))
    assert_true(Sector((10, 10), 20, PI, PI / 2.0).contains(l))


def test_regular_and_star_take_int_radii() raises -> None:
    var r = 10
    var inner = 4
    assert_equal(
        Polygon.regular(Point(0.0, 0.0), r, 6),
        Polygon.regular(Point(0.0, 0.0), 10.0, 6),
    )
    assert_equal(
        Polygon.star(Point(0.0, 0.0), r, inner, 5),
        Polygon.star(Point(0.0, 0.0), 10.0, 4.0, 5),
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
