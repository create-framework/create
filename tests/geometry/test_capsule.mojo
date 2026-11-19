"""`Capsule`: its own measures, the closest point, and every `contains`,
`overlaps` and `intersects` pair it takes part in, each a distance from its
segment, so the edge cases here touch exactly and miss by 0.01."""
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
    Capsule,
    Circle,
    Ellipse,
    Line,
    Polygon,
    Rectangle,
    Sector,
    Spline,
    Triangle,
)
from create.math import PI, TAU, Point, Vector

comptime _C = Capsule(Point(0.0, 0.0), Point(20.0, 0.0), 5.0)
"""Along the x axis from 0 to 20, 5 round."""


def test_measures() raises -> None:
    assert_equal(_C.center(), Point(10.0, 0.0))
    assert_almost_equal(_C.area(), 200.0 + 25.0 * PI, atol=1e-9)
    assert_equal(_C.bounds(), Rectangle((10.0, 0.0), 30.0, 10.0))
    assert_equal(
        String(_C),
        "Capsule(start=Point(0.0, 0.0), end=Point(20.0, 0.0), radius=5.0)",
    )
    assert_equal(
        Capsule((0.0, 0.0), (1.0, 1.0), 2), Capsule((0.0, 0.0), (1.0, 1.0), 2.0)
    )
    assert_true(_C != Capsule((0.0, 0.0), (20.0, 0.0), 5.5))
    var turned = Capsule((0.0, 0.0), (6.0, 8.0), 1.0)
    assert_equal(turned.bounds(), Rectangle((3.0, 4.0), 8.0, 10.0))


def test_contains_points_boundary_included() raises -> None:
    assert_true(_C.contains((25.0, 0.0)))
    assert_false(_C.contains((25.01, 0.0)))
    assert_true(_C.contains((10.0, 5.0)))
    assert_false(_C.contains((10.0, 5.01)))
    assert_true(_C.contains((-3.0, 4.0)))
    assert_false(_C.contains((-3.0, 4.01)))


def test_closest_point_and_moves() raises -> None:
    assert_equal(_C.closest_point((12.0, 1.0)), Point(12.0, 1.0))
    assert_equal(_C.closest_point((10.0, 10.0)), Point(10.0, 5.0))
    assert_equal(_C.closest_point((30.0, 0.0)), Point(25.0, 0.0))
    var moved = _C.move_to((0.0, 0.0))
    assert_equal(moved.start, Point(-10.0, 0.0))
    assert_equal(moved.end, Point(10.0, 0.0))
    assert_equal(_C.translate(Vector(1.0, 2.0)).start, Point(1.0, 2.0))
    assert_equal(_C.start, Point(0.0, 0.0))


def test_against_circles() raises -> None:
    assert_true(_C.overlaps(Circle((10.0, 8.0), 3.0)))
    assert_false(_C.overlaps(Circle((10.0, 8.01), 3.0)))
    assert_true(Circle((28.0, 0.0), 3.0).overlaps(_C))
    assert_false(Circle((28.01, 0.0), 3.0).overlaps(_C))
    assert_true(_C.contains(Circle((10.0, 0.0), 5.0)))
    assert_false(_C.contains(Circle((10.0, 0.0), 5.01)))
    assert_true(Circle((10.0, 0.0), 15.0).contains(_C))
    assert_false(Circle((10.0, 0.0), 14.99).contains(_C))


def test_a_point_capsule_is_its_circle() raises -> None:
    var dot = Capsule((3.0, 4.0), (3.0, 4.0), 2.0)
    var circle = Circle((3.0, 4.0), 2.0)
    assert_almost_equal(dot.area(), circle.area(), atol=1e-12)
    var others: List[Circle] = [
        Circle((7.0, 4.0), 2.0),
        Circle((7.01, 4.0), 2.0),
        Circle((3.0, 5.0), 1.0),
        Circle((3.0, 5.0), 1.01),
    ]
    for o in others:
        assert_equal(dot.overlaps(o), circle.overlaps(o))
        assert_equal(dot.contains(o), circle.contains(o))


def test_against_capsules() raises -> None:
    assert_true(_C.overlaps(Capsule((0.0, 10.0), (20.0, 10.0), 5.0)))
    assert_false(_C.overlaps(Capsule((0.0, 10.01), (20.0, 10.01), 5.0)))
    assert_true(_C.overlaps(Capsule((30.0, 0.0), (40.0, 0.0), 5.0)))
    assert_false(_C.overlaps(Capsule((30.01, 0.0), (40.0, 0.0), 5.0)))
    # Crossing spines.
    assert_true(_C.overlaps(Capsule((10.0, -20.0), (10.0, 20.0), 0.5)))
    assert_true(_C.contains(_C))
    assert_true(_C.contains(Capsule((2.0, 0.0), (18.0, 0.0), 3.0)))
    assert_false(_C.contains(Capsule((0.0, 0.0), (20.0, 0.0), 5.01)))
    assert_false(_C.contains(Capsule((0.0, 0.0), (20.01, 0.0), 5.0)))


def test_against_rectangles() raises -> None:
    assert_true(_C.overlaps(Rectangle((10.0, 7.0), 4.0, 4.0)))
    assert_false(_C.overlaps(Rectangle((10.0, 7.01), 4.0, 4.0)))
    # Off the round end: the corner is what comes near.
    assert_true(Rectangle((-5.0, 5.0), 4.0, 4.0).overlaps(_C))
    assert_false(Rectangle((-6.0, 6.0), 4.0, 4.0).overlaps(_C))
    # Rounded, the corner the sharp one would bring near is cut away.
    assert_true(
        _C.overlaps(Rectangle((-5.0, 5.0), 6.0, 6.0, corner_radius=3.0))
    )
    assert_true(_C.overlaps(Rectangle((-6.0, 6.0), 6.0, 6.0)))
    assert_false(
        _C.overlaps(Rectangle((-6.0, 6.0), 6.0, 6.0, corner_radius=3.0))
    )
    assert_true(_C.contains(Rectangle((10.0, 0.0), 20.0, 8.0)))
    assert_false(_C.contains(Rectangle((10.0, 0.0), 20.0, 10.1)))
    # The stadium of the capsule's own bounds is the capsule.
    assert_true(
        _C.contains(Rectangle((10.0, 0.0), 30.0, 10.0, corner_radius=5.0))
    )
    assert_false(
        _C.contains(Rectangle((10.0, 0.0), 30.1, 10.0, corner_radius=5.0))
    )
    assert_true(Rectangle((10.0, 0.0), 30.0, 10.0).contains(_C))
    assert_false(Rectangle((10.0, 0.0), 29.9, 10.0).contains(_C))


def test_against_triangles() raises -> None:
    var big = Triangle((-40.0, -20.0), (60.0, -20.0), (10.0, 60.0))
    assert_true(big.contains(_C))
    assert_true(big.overlaps(_C))
    assert_false(_C.contains(big))
    var below = Triangle((0.0, -7.0), (20.0, -7.0), (10.0, -20.0))
    assert_false(_C.overlaps(below))
    assert_true(_C.overlaps(Triangle((0.0, -5.0), (20.0, -5.0), (10.0, -20.0))))
    assert_true(_C.contains(Triangle((2.0, -3.0), (18.0, -3.0), (10.0, 3.0))))
    assert_true(
        _C.contains(
            Triangle((4.0, -2.0), (16.0, -2.0), (10.0, 1.0), corner_radius=1.0)
        )
    )


def test_against_polygons() raises -> None:
    # A square with a notch cut down from its top to y = 2 over x 8..12.
    var notched = Polygon(
        Point(-10.0, -10.0),
        Point(30.0, -10.0),
        Point(30.0, 10.0),
        Point(12.0, 10.0),
        Point(12.0, 2.0),
        Point(8.0, 2.0),
        Point(8.0, 10.0),
        Point(-10.0, 10.0),
    )
    assert_true(notched.overlaps(_C))
    # Both ends and both sides' ends are inside, but the top bulges into
    # the notch.
    assert_false(notched.contains(_C))
    assert_true(notched.contains(Capsule((0.0, 0.0), (20.0, 0.0), 2.0)))
    assert_false(notched.contains(Capsule((0.0, 0.0), (20.0, 0.0), 2.01)))
    assert_true(notched.contains(Capsule((0.0, 0.0), (20.0, 0.0), 0.0)))
    assert_true(_C.contains(Polygon.regular((10.0, 0.0), 5.0, sides=6)))
    assert_false(_C.contains(Polygon.regular((10.0, 0.0), 5.5, sides=6)))
    assert_false(
        _C.overlaps(
            Polygon(Point(0.0, 6.0), Point(20.0, 6.0), Point(10.0, 9.0))
        )
    )


def test_against_sectors() raises -> None:
    # A wedge pointing down at the top of the capsule: the arc's lowest
    # point, straight across from the segment, is what comes nearest.
    assert_true(_C.overlaps(Sector((10.0, 20.0), 15.0, -0.75 * PI, PI / 2.0)))
    assert_false(_C.overlaps(Sector((10.0, 20.01), 15.0, -0.75 * PI, PI / 2.0)))
    assert_true(Sector((34.0, 0.0), 10.0, PI / 2.0, PI).overlaps(_C))
    assert_false(Sector((35.01, 0.0), 10.0, PI / 2.0, PI).overlaps(_C))
    assert_true(Sector((10.0, 0.0), 15.0, 0.0, TAU).contains(_C))
    assert_false(Sector((10.0, 0.0), 14.99, 0.0, TAU).contains(_C))
    assert_true(Sector((10.0, -5.0), 30.0, 0.0, PI).contains(_C))
    assert_false(Sector((10.0, -4.99), 30.0, 0.0, PI).contains(_C))
    assert_true(_C.contains(Sector((10.0, 0.0), 4.0, 0.3, 4.0)))
    assert_false(_C.contains(Sector((10.0, 0.0), 5.5, 0.3, 4.0)))


def test_against_ellipses() raises -> None:
    # Above the middle, the ellipse's lowest point is straight across.
    assert_true(_C.overlaps(Ellipse((10.0, 9.0), 10.0, 8.0)))
    assert_false(_C.overlaps(Ellipse((10.0, 9.01), 10.0, 8.0)))
    assert_true(Ellipse((28.0, 0.0), 6.0, 20.0).overlaps(_C))
    assert_false(Ellipse((28.01, 0.0), 6.0, 20.0).overlaps(_C))
    assert_true(_C.contains(Ellipse((10.0, 0.0), 30.0, 10.0)))
    assert_false(_C.contains(Ellipse((10.0, 0.0), 30.1, 10.0)))
    assert_true(Ellipse((10.0, 0.0), 40.0, 20.0).contains(_C))
    assert_false(Ellipse((10.0, 0.0), 30.0, 12.0).contains(_C))
    assert_true(_C.contains(Ellipse((10.0, 0.0), 20.0, 0.0)))


def test_curves_meet_it() raises -> None:
    assert_true(Line((-10.0, 5.0), (30.0, 5.0)).intersects(_C))
    assert_false(Line((-10.0, 5.01), (30.0, 5.01)).intersects(_C))
    assert_true(Line((-20.0, 0.0), (-5.0, 0.0)).intersects(_C))
    assert_false(Line((-20.0, 0.0), (-5.01, 0.0)).intersects(_C))
    assert_true(Line((5.0, 1.0), (15.0, -1.0)).intersects(_C))
    assert_true(_C.contains(Line((5.0, 1.0), (15.0, -1.0))))
    assert_false(_C.contains(Line((5.0, 1.0), (15.0, 6.0))))
    assert_true(Arc((10.0, 15.0), 10.0, PI, PI).intersects(_C))
    assert_false(Arc((10.0, 15.01), 10.0, PI, PI).intersects(_C))
    assert_true(_C.contains(Arc((10.0, 0.0), 4.0, 0.0, TAU)))
    assert_true(
        Bezier(
            (-10.0, 20.0), (5.0, -10.0), (15.0, -10.0), (30.0, 20.0)
        ).intersects(_C)
    )
    assert_false(
        Bezier(
            (-10.0, 30.0), (5.0, 20.0), (15.0, 20.0), (30.0, 30.0)
        ).intersects(_C)
    )
    assert_true(
        Spline(
            [Point(-10.0, 20.0), Point(10.0, 0.0), Point(30.0, 20.0)]
        ).intersects(_C)
    )


def test_zero_radius_is_its_segment() raises -> None:
    var segment = Capsule((0.0, 0.0), (10.0, 0.0), 0.0)
    assert_equal(segment.area(), 0.0)
    assert_true(segment.contains((5.0, 0.0)))
    assert_false(segment.contains((5.0, 0.01)))
    assert_true(segment.overlaps(Circle((5.0, 1.0), 1.0)))
    assert_false(segment.overlaps(Circle((5.0, 1.01), 1.0)))
    assert_true(Rectangle((5.0, 0.0), 10.0, 4.0).contains(segment))
    assert_true(Sector((0.0, 0.0), 10.0, -0.1, 0.2).contains(segment))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
