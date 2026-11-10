"""`Ellipse`: its own measures, the closest point, and every `contains`,
`overlaps` and `intersects` pair it takes part in, exact where the stretch
onto the unit circle keeps the other shape's kind."""
from std.testing import (
    TestSuite,
    assert_almost_equal,
    assert_equal,
    assert_false,
    assert_true,
)

from create.geometry import (
    Arc,
    Bezier,
    Circle,
    Ellipse,
    Line,
    Polygon,
    Rectangle,
    Sector,
    Spline,
    Triangle,
    overlaps,
)
from create.math import PI, TAU, Point2D, Vector2D, cos, sin, sqrt

comptime _E = Ellipse(Point2D(10.0, 5.0), 40.0, 20.0)
"""20 across either side of (10, 5), 10 up and down."""


def test_measures() raises -> None:
    assert_equal(_E.center(), Point2D(10.0, 5.0))
    assert_almost_equal(_E.area(), PI * 20.0 * 10.0, atol=1e-9)
    assert_equal(_E.bounds(), Rectangle((10.0, 5.0), 40.0, 20.0))
    assert_equal(
        String(_E), "Ellipse(position=Point2D(10.0, 5.0), w=40.0, h=20.0)"
    )
    assert_equal(Ellipse((0.0, 0.0), 4, 2), Ellipse((0.0, 0.0), 4.0, 2.0))
    assert_true(_E != Ellipse((10.0, 5.0), 40.0, 21.0))


def test_contains_points_boundary_included() raises -> None:
    assert_true(_E.contains((10.0, 5.0)))
    assert_true(_E.contains((30.0, 5.0)))
    assert_true(_E.contains((10.0, 15.0)))
    assert_false(_E.contains((30.01, 5.0)))
    assert_false(_E.contains((10.0, 15.01)))
    # Inside the bounds' corner, outside the curve.
    assert_false(_E.contains((28.0, 13.0)))


def test_moves() raises -> None:
    var moved = _E.translate(Vector2D(1.0, -2.0))
    assert_equal(moved.position, Point2D(11.0, 3.0))
    assert_equal(_E.position, Point2D(10.0, 5.0))
    assert_equal(_E.move_to((0.0, 0.0)).position, Point2D(0.0, 0.0))


def _brute_closest(e: Ellipse, p: Point2D) -> Point2D:
    var best = Point2D(0.0, 0.0)
    var best_distance = Float64.MAX
    for i in range(20000):
        var t = TAU * Float64(i) / 20000.0
        var q = e.position + Vector2D(e.w / 2.0 * cos(t), e.h / 2.0 * sin(t))
        var d = q.distance(p)
        if d < best_distance:
            best = q
            best_distance = d
    return best


def test_closest_point_is_nearest_on_the_curve() raises -> None:
    assert_equal(_E.closest_point((12.0, 6.0)), Point2D(12.0, 6.0))
    var queries: List[Point2D] = [
        (50.0, 30.0),
        (-40.0, 5.0),
        (10.0, -40.0),
        (31.0, 14.0),
        (-15.0, -20.0),
    ]
    for p in queries:
        var q = _E.closest_point(p)
        var expected = _brute_closest(_E, p)
        assert_almost_equal(q.distance(p), expected.distance(p), atol=1e-4)
        var u = Vector2D((q.x - 10.0) / 20.0, (q.y - 5.0) / 10.0)
        assert_almost_equal(u.magnitude(), 1.0, atol=1e-12)


def test_tall_ellipse_closest_point() raises -> None:
    # Taller than wide: the axes swap inside the solve.
    var e = Ellipse((0.0, 0.0), 10.0, 40.0)
    var q = e.closest_point((20.0, 30.0))
    var expected = _brute_closest(e, Point2D(20.0, 30.0))
    assert_almost_equal(
        q.distance((20.0, 30.0)), expected.distance((20.0, 30.0)), atol=1e-4
    )


def test_round_ellipse_agrees_with_its_circle() raises -> None:
    var e = Ellipse((0.0, 0.0), 20.0, 20.0)
    var c = Circle((0.0, 0.0), 10.0)
    var others: List[Circle] = [
        Circle((15.0, 0.0), 5.0),
        Circle((15.0, 0.0), 4.9),
        Circle((3.0, 0.0), 7.0),
        Circle((3.0, 0.0), 7.1),
    ]
    for o in others:
        assert_equal(overlaps(e, o), overlaps(c, o))
        assert_equal(e.contains(o), c.contains(o))
        assert_equal(
            Circle(o.position, o.r + 20.0).contains(e),
            Circle(o.position, o.r + 20.0).contains(c),
        )


def test_against_circles() raises -> None:
    # Off the end of the width, 20 away from the curve's nearest point.
    assert_true(overlaps(_E, Circle((50.0, 5.0), 20.0)))
    assert_false(overlaps(_E, Circle((50.0, 5.0), 19.99)))
    assert_true(overlaps(Circle((10.0, 30.0), 15.0), _E))
    assert_false(overlaps(Circle((10.0, 30.0), 14.99), _E))
    # Inside: no nearer the curve than its radius. Above the centre, the
    # curve is 10 away.
    assert_true(_E.contains(Circle((10.0, 5.0), 10.0)))
    assert_false(_E.contains(Circle((10.0, 5.0), 10.01)))
    assert_true(Circle((10.0, 5.0), 20.0).contains(_E))
    assert_false(Circle((10.0, 5.0), 19.99).contains(_E))


def test_against_ellipses() raises -> None:
    var wide = Ellipse((0.0, 0.0), 40.0, 20.0)
    assert_true(overlaps(wide, Ellipse((40.0, 0.0), 40.0, 20.0)))
    assert_false(overlaps(wide, Ellipse((40.01, 0.0), 40.0, 20.0)))
    assert_true(overlaps(wide, Ellipse((0.0, 20.0), 4.0, 20.0)))
    assert_false(overlaps(wide, Ellipse((0.0, 20.01), 4.0, 20.0)))
    assert_true(wide.contains(Ellipse((0.0, 0.0), 40.0, 20.0)))
    assert_true(wide.contains(Ellipse((0.0, 0.0), 30.0, 10.0)))
    # A thin ellipse along the width reaches past the curve's end.
    assert_false(wide.contains(Ellipse((0.0, 0.0), 40.1, 1.0)))
    # Tall and narrow, it pokes out above.
    assert_false(wide.contains(Ellipse((0.0, 0.0), 2.0, 20.5)))
    assert_false(Ellipse((0.0, 0.0), 30.0, 10.0).contains(wide))


def test_against_straight_edged_shapes() raises -> None:
    # A square touching the right end of the width.
    assert_true(overlaps(_E, Rectangle((35.0, 5.0), 10.0, 10.0)))
    assert_false(overlaps(_E, Rectangle((35.01, 5.0), 10.0, 10.0)))
    # In the bounds' corner, clear of the curve.
    assert_false(overlaps(Rectangle((29.0, 14.0), 2.0, 2.0), _E))
    assert_true(_E.contains(Rectangle((10.0, 5.0), 20.0, 10.0)))
    assert_false(_E.contains(Rectangle((10.0, 5.0), 30.0, 15.0)))
    assert_true(Rectangle((10.0, 5.0), 40.0, 20.0).contains(_E))
    assert_false(Rectangle((10.0, 5.0), 39.9, 20.0).contains(_E))
    var t = Triangle((-20.0, -20.0), (40.0, -20.0), (10.0, 40.0))
    assert_true(overlaps(_E, t))
    assert_true(overlaps(t, Ellipse((10.0, -25.0), 4.0, 10.0)))
    assert_false(overlaps(t, Ellipse((10.0, -25.01), 4.0, 10.0)))
    assert_true(
        Triangle((-100.0, -50.0), (100.0, -50.0), (10.0, 200.0)).contains(_E)
    )
    assert_false(t.contains(_E))
    var square = Polygon(
        Point2D(-10.0, -5.0),
        Point2D(30.0, -5.0),
        Point2D(30.0, 15.0),
        Point2D(-10.0, 15.0),
    )
    assert_true(square.contains(_E))
    assert_true(overlaps(square, _E))
    assert_false(_E.contains(square))
    assert_false(
        overlaps(
            Polygon(
                Point2D(29.0, 14.0), Point2D(31.0, 14.0), Point2D(31.0, 16.0)
            ),
            _E,
        )
    )


def test_against_rounded_shapes() raises -> None:
    # A stadium: its ends are tighter than the ellipse's, which still fits
    # inside short of touching them (the outline is flattened).
    var rounded = Rectangle((10.0, 5.0), 40.0, 20.0, corner_radius=10.0)
    assert_true(rounded.contains(Ellipse((10.0, 5.0), 39.5, 19.5)))
    assert_false(
        Rectangle((10.0, 5.0), 40.0, 20.0, corner_radius=10.0).contains(
            Ellipse((10.0, 5.0), 40.0, 20.5)
        )
    )
    assert_true(
        _E.contains(Rectangle((10.0, 5.0), 20.0, 10.0, corner_radius=2.0))
    )


def test_against_sectors() raises -> None:
    var s = Sector((10.0, 5.0), 50.0, 0.0, PI / 2.0)
    assert_true(overlaps(_E, s))
    assert_true(s.contains(Ellipse((25.0, 20.0), 10.0, 10.0)))
    assert_false(s.contains(_E))
    assert_true(_E.contains(Sector((10.0, 5.0), 9.0, 0.3, 4.0)))
    assert_false(_E.contains(Sector((10.0, 5.0), 11.0, 0.3, 4.0)))
    assert_false(overlaps(Sector((60.0, 5.0), 10.0, 0.0, PI), _E))


def test_curves_meet_it() raises -> None:
    # A line tangent to the top of the curve, and one just above it.
    assert_true(Line((-50.0, 15.0), (50.0, 15.0)).intersects(_E))
    assert_false(Line((-50.0, 15.01), (50.0, 15.01)).intersects(_E))
    # Wholly inside.
    assert_true(Line((5.0, 5.0), (15.0, 5.0)).intersects(_E))
    assert_true(_E.contains(Line((5.0, 5.0), (15.0, 5.0))))
    assert_false(_E.contains(Line((5.0, 5.0), (35.0, 5.0))))
    assert_true(Arc((10.0, 5.0), 15.0, 0.0, PI).intersects(_E))
    assert_false(Arc((10.0, 5.0), 25.0, 0.0, PI).intersects(_E))
    assert_true(_E.contains(Arc((10.0, 5.0), 9.0, 0.0, TAU)))
    var b = Bezier((-30.0, 30.0), (0.0, 0.0), (20.0, 0.0), (50.0, 30.0))
    assert_true(b.intersects(_E))
    assert_false(
        Bezier(
            (-30.0, 40.0), (0.0, 30.0), (20.0, 30.0), (50.0, 40.0)
        ).intersects(_E)
    )
    var spline = Spline(
        [Point2D(-30.0, 30.0), Point2D(10.0, 5.0), Point2D(50.0, 30.0)]
    )
    assert_true(spline.intersects(_E))


def test_flat_ellipse_is_its_bounds() raises -> None:
    var flat = Ellipse((0.0, 0.0), 20.0, 0.0)
    var segment = Rectangle((0.0, 0.0), 20.0, 0.0)
    assert_equal(flat.area(), 0.0)
    assert_true(flat.contains((10.0, 0.0)))
    assert_false(flat.contains((0.0, 0.01)))
    assert_equal(flat.closest_point((5.0, 3.0)), Point2D(5.0, 0.0))
    var c = Circle((0.0, 5.0), 5.0)
    assert_equal(overlaps(flat, c), overlaps(segment, c))
    assert_true(overlaps(flat, Ellipse((0.0, 2.0), 4.0, 4.0)))
    assert_false(overlaps(flat, Ellipse((0.0, 2.01), 4.0, 4.0)))
    assert_true(Ellipse((0.0, 0.0), 30.0, 10.0).contains(flat))
    assert_false(flat.contains(Ellipse((0.0, 0.0), 4.0, 4.0)))
    assert_true(Line((0.0, -1.0), (0.0, 1.0)).intersects(flat))
    var point = Ellipse((3.0, 3.0), 0.0, 0.0)
    assert_true(point.contains((3.0, 3.0)))
    assert_true(Circle((3.0, 3.0), 1.0).contains(point))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
