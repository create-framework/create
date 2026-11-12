from std.math import sqrt
from std.testing import (
    TestSuite,
    assert_almost_equal,
    assert_equal,
    assert_false,
    assert_true,
)
from create.math import PI, TAU
from create.geometry import (
    Capsule,
    Circle,
    Ellipse,
    Line,
    Polygon,
    Rectangle,
    Sector,
    Triangle,
    overlaps,
)
from create.math.point2d import Point2D
from create.math.vector2d import Vector2D


def _bar() -> Rectangle:
    # 40 wide and 10 high, turned a quarter: standing 40 tall and 10 wide.
    return Rectangle((0.0, 0.0), 40.0, 10.0, rotation=PI / 2.0)


def _diamond() -> Rectangle:
    # A 10 square turned an eighth: its corners on the axes, 5 * sqrt(2)
    # out, its edges on |x| + |y| = 5 * sqrt(2).
    return Rectangle((0.0, 0.0), 10.0, 10.0, rotation=PI / 4.0)


def test_rotation_defaults_to_upright() raises -> None:
    var r = Rectangle((1.0, 2.0), 3.0, 4.0)
    assert_equal(r.rotation, 0.0)
    assert_equal(r, Rectangle((1.0, 2.0), 3.0, 4.0, rotation=0))


def test_rotation_takes_part_in_equality_and_printing() raises -> None:
    var r = Rectangle((0.0, 0.0), 3.0, 4.0, rotation=0.5)
    assert_true(r != Rectangle((0.0, 0.0), 3.0, 4.0))
    assert_equal(
        String(r),
        "Rectangle(position=Point2D(0.0, 0.0), w=3.0, h=4.0, rotation=0.5)",
    )
    assert_equal(
        String(Rectangle((0.0, 0.0), 3, 4)),
        "Rectangle(position=Point2D(0.0, 0.0), w=3.0, h=4.0)",
    )


def test_int_constructor_takes_rotation() raises -> None:
    assert_equal(
        Rectangle((0.0, 0.0), 40, 10, rotation=1),
        Rectangle((0.0, 0.0), 40.0, 10.0, rotation=1.0),
    )


def test_contains_the_turned_shape() raises -> None:
    var bar = _bar()
    assert_true(bar.contains(Point2D(0.0, 19.0)))
    assert_true(bar.contains(Point2D(4.0, -19.0)))
    assert_false(bar.contains(Point2D(19.0, 0.0)))
    assert_false(bar.contains(Point2D(6.0, 0.0)))


def test_bounds_and_edges_are_the_bounding_box() raises -> None:
    var d = _diamond()
    var half = 5.0 * sqrt(2.0)
    var b = d.bounds()
    assert_equal(b.rotation, 0.0)
    assert_almost_equal(b.w, 2.0 * half)
    assert_almost_equal(b.h, 2.0 * half)
    assert_almost_equal(d.left(), -half)
    assert_almost_equal(d.right(), half)
    assert_almost_equal(d.bottom(), -half)
    assert_almost_equal(d.top(), half)


def test_rounded_bounds_are_pulled_in_at_the_corners() raises -> None:
    # Fully rounded, the diamond is the circle of radius 5, whatever its turn.
    var round = Rectangle((0.0, 0.0), 10.0, 10.0, corner_radius=5, rotation=1.0)
    assert_almost_equal(round.bounds().w, 10.0)
    assert_almost_equal(round.right(), 5.0)


def test_closest_point_from_outside_lands_on_an_edge() raises -> None:
    var bar = _bar()
    var q = bar.closest_point(Point2D(20.0, 3.0))
    assert_almost_equal(q.x, 5.0)
    assert_almost_equal(q.y, 3.0)
    var inside = Point2D(1.0, 15.0)
    assert_equal(bar.closest_point(inside), inside)


def test_area_and_center_ignore_the_turn() raises -> None:
    var bar = _bar()
    assert_equal(bar.area(), 400.0)
    assert_equal(bar.center(), Point2D(0.0, 0.0))


def test_move_and_translate_keep_the_turn() raises -> None:
    var bar = _bar()
    assert_equal(bar.move_to(Point2D(3.0, 4.0)).rotation, PI / 2.0)
    assert_equal(bar.translate(Vector2D(1.0, 1.0)).rotation, PI / 2.0)


def test_overlaps_rectangle_inside_the_bounds_but_off_the_shape() raises -> (
    None
):
    # The upright square's corner (5, 5) is inside the diamond's bounds but
    # past its edge, where |x| + |y| = 10 > 7.07.
    var d = _diamond()
    var corner = Rectangle((7.0, 7.0), 4.0, 4.0)
    assert_true(overlaps(d.bounds(), corner))
    assert_false(overlaps(d, corner))
    assert_false(overlaps(corner, d))
    assert_true(overlaps(d, Rectangle((5.0, 0.0), 4.0, 4.0)))


def test_overlaps_two_turned_rectangles() raises -> None:
    assert_true(overlaps(_bar(), _diamond()))
    var apart = Rectangle((12.0, 12.0), 10.0, 10.0, rotation=PI / 4.0)
    assert_false(overlaps(_diamond(), apart))
    # Edge to edge along x + y = 7.07: touching counts.
    var touching = Rectangle(
        (5.0 * sqrt(2.0), 5.0 * sqrt(2.0)), 10.0, 10.0, rotation=PI / 4.0
    )
    assert_true(overlaps(_diamond(), touching))


def test_overlaps_round_shapes_by_the_turned_edge() raises -> None:
    # (6, 6) is (12 - 7.07) / sqrt(2) = 3.49 from the diamond's edge.
    var d = _diamond()
    assert_false(overlaps(d, Circle((6.0, 6.0), 3.4)))
    assert_true(overlaps(d, Circle((6.0, 6.0), 3.5)))
    assert_false(overlaps(d, Capsule((6.0, 6.0), (9.0, 9.0), 3.4)))
    assert_true(overlaps(Capsule((6.0, 6.0), (9.0, 9.0), 3.5), d))


def test_overlaps_straight_edged_regions() raises -> None:
    var d = _diamond()
    assert_false(overlaps(d, Triangle((5.0, 5.0), (9.0, 5.0), (5.0, 9.0))))
    assert_true(overlaps(d, Triangle((3.0, 3.0), (9.0, 3.0), (3.0, 9.0))))
    var square = Polygon((5.0, 5.0), (9.0, 5.0), (9.0, 9.0), (5.0, 9.0))
    assert_false(overlaps(d, square))
    assert_false(overlaps(square, d))


def test_overlaps_curved_regions() raises -> None:
    var d = _diamond()
    assert_false(overlaps(d, Ellipse((6.0, 6.0), 6.0, 6.0)))
    assert_true(overlaps(Ellipse((6.0, 6.0), 7.2, 7.2), d))
    assert_false(overlaps(d, Sector((6.0, 6.0), 3.0, 0.0, PI / 2.0)))
    assert_true(overlaps(Sector((6.0, 6.0), 3.6, PI, PI / 2.0), d))


def test_contains_shapes_that_fit_only_turned() raises -> None:
    var bar = _bar()
    assert_true(bar.contains(Rectangle((0.0, 0.0), 8.0, 38.0)))
    assert_false(bar.contains(Rectangle((0.0, 0.0), 38.0, 8.0)))
    assert_true(bar.contains(Circle((0.0, 14.0), 4.9)))
    assert_false(bar.contains(Circle((0.0, 15.0), 5.5)))
    assert_true(bar.contains(Ellipse((0.0, 0.0), 9.8, 39.0)))
    assert_false(bar.contains(Ellipse((0.0, 0.0), 40.0, 10.0)))
    assert_true(bar.contains(Line((0.0, -19.9), (0.0, 19.9))))
    assert_true(bar.contains(Capsule((0.0, -15.0), (0.0, 15.0), 4.9)))
    assert_true(
        bar.contains(Triangle((-4.9, -19.9), (4.9, -19.9), (0.0, 19.9)))
    )
    assert_true(bar.contains(Sector((0.0, -19.5), 19.0, PI / 2.0 - 0.2, 0.4)))
    assert_true(bar.contains(Polygon.regular(Point2D(0.0, 0.0), 5.0, sides=6)))


def test_turned_rectangle_is_contained_by_its_corners() raises -> None:
    var d = _diamond()
    var half = 5.0 * sqrt(2.0)
    assert_true(Circle((0.0, 0.0), half).contains(d))
    assert_false(Circle((0.0, 0.0), half - 0.01).contains(d))
    assert_true(Rectangle((0.0, 0.0), 2.0 * half, 2.0 * half).contains(d))
    assert_true(Ellipse((0.0, 0.0), 2.0 * half, 2.1 * half).contains(d))
    assert_true(Polygon.regular(Point2D(0.0, 0.0), 7.1, sides=4).contains(d))


def test_line_meets_the_turned_shape() raises -> None:
    var d = _diamond()
    assert_false(Line((5.0, 5.0), (9.0, 5.0)).intersects(d))
    assert_true(Line((3.0, 3.0), (9.0, 3.0)).intersects(d))


def test_a_full_turn_is_upright_to_rounding() raises -> None:
    var turned = Rectangle((0.0, 0.0), 40.0, 10.0, rotation=TAU)
    assert_almost_equal(turned.right(), 20.0)
    assert_true(turned.contains(Point2D(19.0, 4.0)))
    assert_false(turned.contains(Point2D(4.0, 19.0)))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
