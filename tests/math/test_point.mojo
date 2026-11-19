from std.testing import (
    TestSuite,
    assert_equal,
    assert_almost_equal,
    assert_true,
)
from create.math.point import Point
from create.math.vector import Vector


def test_init_float() raises -> None:
    var p = Point(3.0, 4.0)
    assert_equal(p.x, 3.0)
    assert_equal(p.y, 4.0)


def test_init_int() raises -> None:
    var p = Point(3, 4)
    assert_equal(p.x, 3.0)
    assert_equal(p.y, 4.0)


def test_init_tuple_float() raises -> None:
    var p: Point = (1.5, 2.5)
    assert_equal(p.x, 1.5)
    assert_equal(p.y, 2.5)


def test_init_tuple_int() raises -> None:
    var p: Point = (3, 7)
    assert_equal(p.x, 3.0)
    assert_equal(p.y, 7.0)


def test_init_tuple_int_float() raises -> None:
    var p: Point = (3, 4.5)
    assert_equal(p.x, 3.0)
    assert_equal(p.y, 4.5)


def test_init_tuple_float_int() raises -> None:
    var p: Point = (3.5, 4)
    assert_equal(p.x, 3.5)
    assert_equal(p.y, 4.0)


def test_point_minus_point_is_a_displacement() raises -> None:
    """Position minus position is the vector between them, which is the one
    operation that motivates the type split."""
    var d: Vector = Point(4.0, 6.0) - Point(1.0, 2.0)
    assert_equal(d, Vector(3.0, 4.0))


def test_point_plus_vector_moves_the_point() raises -> None:
    var p = Point(1.0, 2.0) + Vector(3.0, 4.0)
    assert_equal(p, Point(4.0, 6.0))


def test_point_minus_vector_moves_the_point() raises -> None:
    var p = Point(4.0, 6.0) - Vector(3.0, 4.0)
    assert_equal(p, Point(1.0, 2.0))


def test_displacement_round_trip() raises -> None:
    """`a + (b - a) == b` — the two operators are inverses, which is what
    makes the algebra affine rather than arbitrary."""
    var a = Point(-3.0, 7.5)
    var b = Point(11.0, -2.25)
    assert_equal(a + (b - a), b)


def test_iadd_vector() raises -> None:
    var p = Point(1.0, 2.0)
    p += Vector(3.0, 4.0)
    assert_equal(p, Point(4.0, 6.0))


def test_isub_vector() raises -> None:
    var p = Point(4.0, 6.0)
    p -= Vector(3.0, 4.0)
    assert_equal(p, Point(1.0, 2.0))


def test_eq() raises -> None:
    assert_equal(Point(1.0, 2.0) == Point(1.0, 2.0), True)
    assert_equal(Point(1.0, 2.0) == Point(1.0, 3.0), False)


def test_ne() raises -> None:
    assert_equal(Point(1.0, 2.0) != Point(1.0, 3.0), True)
    assert_equal(Point(1.0, 2.0) != Point(1.0, 2.0), False)


def test_distance() raises -> None:
    assert_equal(Point(0.0, 0.0).distance(Point(3.0, 4.0)), 5.0)
    assert_equal(Point(1.0, 1.0).distance(Point(1.0, 1.0)), 0.0)


def test_distance_is_symmetric() raises -> None:
    var a = Point(-2.0, 5.0)
    var b = Point(4.0, -3.0)
    assert_almost_equal(a.distance(b), b.distance(a), atol=1e-9)


def test_distance_squared() raises -> None:
    assert_equal(Point(0.0, 0.0).distance_squared(Point(3.0, 4.0)), 25.0)


def test_lerp_endpoints() raises -> None:
    var a = Point(0.0, 0.0)
    var b = Point(10.0, 20.0)
    assert_equal(a.lerp(b, 0.0), a)
    assert_equal(a.lerp(b, 1.0), b)


def test_lerp_midpoint() raises -> None:
    var r = Point(0.0, 0.0).lerp(Point(10.0, 20.0), 0.5)
    assert_equal(r, Point(5.0, 10.0))


def test_write_to_contains_type_name() raises -> None:
    var s = String(Point(3.0, 4.0))
    assert_true(s.startswith("Point("))
    assert_true(s.endswith(")"))


def test_xy_returns_the_components() raises -> None:
    var t = Point(1.5, 2.5).xy()
    assert_equal(t[0], 1.5)
    assert_equal(t[1], 2.5)


def test_xy_binds_back_to_a_point() raises -> None:
    var p = Point(1.5, 2.5)
    var back: Point = p.xy()
    assert_equal(back, p)


def test_vector_constructor_is_the_escape_hatch() raises -> None:
    """`Vector(p)` is how a program reaches the operations Point
    deliberately refuses: the displacement from the origin to `p`."""
    var v = Vector(Point(3.0, 4.0))
    assert_equal(v, Vector(3.0, 4.0))
    assert_equal(v.magnitude(), 5.0)


def test_constructs_from_a_vector() raises -> None:
    """`Point(v)` is the origin moved by `v`."""
    var v = Vector(1.5, -2.5)
    assert_equal(Point(v), Point(0.0, 0.0) + v)


def test_vector_round_trip() raises -> None:
    var p = Point(1.5, 2.5)
    assert_equal(Point(Vector(p)), p)


def test_subtracting_a_bare_tuple_is_a_displacement() raises -> None:
    """A bare tuple only converts to a `Point`, so `p - (1, 2)` is the
    displacement between two positions, not a move -- see the docstring."""
    var d: Vector = Point(4.0, 6.0) - (1.0, 2.0)
    assert_equal(d, Vector(3.0, 4.0))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
