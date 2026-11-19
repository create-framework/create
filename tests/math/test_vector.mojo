from std.testing import (
    TestSuite,
    assert_equal,
    assert_almost_equal,
    assert_true,
)
from create.math.point import Point
from create.math.vector import Vector
from std.math import isnan, isinf
from create.math import PI


def test_init_float() raises -> None:
    var v = Vector(3.0, 4.0)
    assert_equal(v.x, 3.0)
    assert_equal(v.y, 4.0)


def test_init_int() raises -> None:
    var v = Vector(3, 4)
    assert_equal(v.x, 3.0)
    assert_equal(v.y, 4.0)


def test_init_tuple() raises -> None:
    var v = Vector((1.5, 2.5))
    assert_equal(v.x, 1.5)
    assert_equal(v.y, 2.5)


def test_zero() raises -> None:
    var v = Vector.ZERO
    assert_equal(v.x, 0.0)
    assert_equal(v.y, 0.0)


def test_one() raises -> None:
    var v = Vector.ONE
    assert_equal(v.x, 1.0)
    assert_equal(v.y, 1.0)


def test_directions() raises -> None:
    assert_equal(Vector.UP, Vector(0.0, 1.0))
    assert_equal(Vector.DOWN, Vector(0.0, -1.0))
    assert_equal(Vector.LEFT, Vector(-1.0, 0.0))
    assert_equal(Vector.RIGHT, Vector(1.0, 0.0))
    assert_equal(Vector.UP, -Vector.DOWN)
    assert_equal(Vector.LEFT, -Vector.RIGHT)


def test_add() raises -> None:
    var c = Vector(1.0, 2.0) + Vector(3.0, 4.0)
    assert_equal(c.x, 4.0)
    assert_equal(c.y, 6.0)


def test_sub() raises -> None:
    var c = Vector(5.0, 3.0) - Vector(2.0, 1.0)
    assert_equal(c.x, 3.0)
    assert_equal(c.y, 2.0)


def test_mul_scalar() raises -> None:
    var v = Vector(2.0, 3.0) * 4.0
    assert_equal(v.x, 8.0)
    assert_equal(v.y, 12.0)


def test_div_scalar() raises -> None:
    var v = Vector(6.0, 4.0) / 2.0
    assert_equal(v.x, 3.0)
    assert_equal(v.y, 2.0)


def test_neg() raises -> None:
    var v = -Vector(1.0, -2.0)
    assert_equal(v.x, -1.0)
    assert_equal(v.y, 2.0)


def test_iadd() raises -> None:
    var v = Vector(1.0, 2.0)
    v += Vector(3.0, 4.0)
    assert_equal(v.x, 4.0)
    assert_equal(v.y, 6.0)


def test_isub() raises -> None:
    var v = Vector(5.0, 3.0)
    v -= Vector(2.0, 1.0)
    assert_equal(v.x, 3.0)
    assert_equal(v.y, 2.0)


def test_scalar_times_vector() raises -> None:
    """`s * v` compiles and agrees with `v * s`."""
    var v = Vector(3.0, -4.0)
    var dt = 2.0
    assert_equal(dt * v, Vector(6.0, -8.0))
    assert_equal(dt * v, v * dt)


def test_imul() raises -> None:
    var v = Vector(2.0, 3.0)
    v *= 4.0
    assert_equal(v.x, 8.0)
    assert_equal(v.y, 12.0)


def test_idiv() raises -> None:
    var v = Vector(6.0, 4.0)
    v /= 2.0
    assert_equal(v.x, 3.0)
    assert_equal(v.y, 2.0)


def test_eq() raises -> None:
    assert_equal(Vector(1.0, 2.0) == Vector(1.0, 2.0), True)
    assert_equal(Vector(1.0, 2.0) == Vector(1.0, 3.0), False)


def test_ne() raises -> None:
    assert_equal(Vector(1.0, 2.0) != Vector(1.0, 3.0), True)
    assert_equal(Vector(1.0, 2.0) != Vector(1.0, 2.0), False)


def test_magnitude() raises -> None:
    assert_equal(Vector(3.0, 4.0).magnitude(), 5.0)
    assert_equal(Vector(0.0, 0.0).magnitude(), 0.0)


def test_magnitude_squared() raises -> None:
    assert_equal(Vector(3.0, 4.0).magnitude_squared(), 25.0)


def test_normalize() raises -> None:
    var n = Vector(3.0, 4.0).normalize()
    assert_almost_equal(n.x, 0.6, atol=1e-9)
    assert_almost_equal(n.y, 0.8, atol=1e-9)


def test_dot_perpendicular() raises -> None:
    assert_equal(Vector(1.0, 0.0).dot(Vector(0.0, 1.0)), 0.0)


def test_dot_parallel() raises -> None:
    assert_equal(Vector(2.0, 3.0).dot(Vector(4.0, 5.0)), 23.0)


def test_distance() raises -> None:
    assert_equal(Vector(0.0, 0.0).distance(Vector(3.0, 4.0)), 5.0)
    assert_equal(Vector(1.0, 1.0).distance(Vector(1.0, 1.0)), 0.0)


def test_distance_squared() raises -> None:
    assert_equal(Vector(0.0, 0.0).distance_squared(Vector(3.0, 4.0)), 25.0)


def test_lerp_endpoints() raises -> None:
    var a = Vector(0.0, 0.0)
    var b = Vector(10.0, 20.0)
    var r0 = a.lerp(b, 0.0)
    assert_equal(r0.x, 0.0)
    assert_equal(r0.y, 0.0)
    var r1 = a.lerp(b, 1.0)
    assert_equal(r1.x, 10.0)
    assert_equal(r1.y, 20.0)


def test_lerp_midpoint() raises -> None:
    var r = Vector(0.0, 0.0).lerp(Vector(10.0, 20.0), 0.5)
    assert_equal(r.x, 5.0)
    assert_equal(r.y, 10.0)


def test_write_to_contains_type_name() raises -> None:
    var v = Vector(3.0, 4.0)
    var s = String(v)
    assert_true(s.startswith("Vector("))
    assert_true(s.endswith(")"))


def test_normalize_zero_vector_is_nan() raises -> None:
    var n = Vector.ZERO.normalize()
    assert_true(isnan(n.x))
    assert_true(isnan(n.y))


def test_div_by_zero() raises -> None:
    var v = Vector(3.0, 0.0) / 0.0
    assert_true(isinf(v.x))
    assert_true(isnan(v.y))


def test_idiv_by_zero() raises -> None:
    var v = Vector(3.0, 0.0)
    v /= 0.0
    assert_true(isinf(v.x))
    assert_true(isnan(v.y))


def test_xy_returns_the_components() raises -> None:
    var t = Vector(1.5, 2.5).xy()
    assert_equal(t[0], 1.5)
    assert_equal(t[1], 2.5)


def test_xy_converts_back_to_a_vector() raises -> None:
    var v = Vector(1.5, 2.5)
    var back = Vector(v.xy())
    assert_equal(back, v)


def test_xy_destructures() raises -> None:
    var (x, y) = Vector(1.5, 2.5).xy()
    assert_equal(x, 1.5)
    assert_equal(y, 2.5)


def test_constructs_from_a_point() raises -> None:
    """The displacement from the origin to the position."""
    var p = Point(1.5, -2.5)
    assert_equal(Vector(p), p - Point(0.0, 0.0))


def test_float_tuple_still_takes_the_tuple_constructor() raises -> None:
    """A `Point` constructor beside the tuple one must not make a float
    tuple ambiguous."""
    assert_equal(Vector((1.5, 2.5)), Vector(1.5, 2.5))


def _assert_close(a: Vector, b: Vector) raises:
    assert_almost_equal(a.x, b.x, atol=1e-12)
    assert_almost_equal(a.y, b.y, atol=1e-12)


def test_from_angle_follows_the_y_up_convention() raises -> None:
    _assert_close(Vector.from_angle(0.0), Vector.RIGHT)
    _assert_close(Vector.from_angle(PI / 2.0), Vector.UP)
    _assert_close(Vector.from_angle(-PI / 2.0), Vector.DOWN)


def test_from_angle_takes_a_length() raises -> None:
    _assert_close(Vector.from_angle(PI, 3.0), Vector(-3.0, 0.0))


def test_angle_reads_the_heading_back() raises -> None:
    assert_almost_equal(Vector.UP.angle(), PI / 2.0)
    assert_almost_equal(Vector.from_angle(2.5, 4.0).angle(), 2.5)
    assert_equal(Vector.ZERO.angle(), 0.0)


def test_rotate_turns_counter_clockwise() raises -> None:
    _assert_close(Vector(2.0, 0.0).rotate(PI / 2.0), Vector(0.0, 2.0))
    _assert_close(Vector.UP.rotate(-PI / 2.0), Vector.RIGHT)


def test_rotate_keeps_the_length() raises -> None:
    var v = Vector(3.0, 4.0).rotate(1.234)
    assert_almost_equal(v.magnitude(), 5.0)


def test_rotate_leaves_self_alone() raises -> None:
    var v = Vector(3.0, 4.0)
    _ = v.rotate(1.0)
    assert_equal(v, Vector(3.0, 4.0))


def test_with_length_keeps_the_direction() raises -> None:
    _assert_close(Vector(3.0, 4.0).with_length(10.0), Vector(6.0, 8.0))


def test_with_length_of_zero_is_nan() raises -> None:
    var v = Vector.ZERO.with_length(2.0)
    assert_true(isnan(v.x))
    assert_true(isnan(v.y))


def test_limit_shortens_only_a_longer_vector() raises -> None:
    _assert_close(Vector(3.0, 4.0).limit(2.5), Vector(1.5, 2.0))
    assert_equal(Vector(3.0, 4.0).limit(5.0), Vector(3.0, 4.0))
    assert_equal(Vector(3.0, 4.0).limit(10.0), Vector(3.0, 4.0))
    assert_equal(Vector.ZERO.limit(1.0), Vector.ZERO)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
