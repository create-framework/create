from std.testing import (
    TestSuite,
    assert_almost_equal,
    assert_equal,
    assert_raises,
    assert_true,
)
from create.math import PI
from create.math.point import Point
from create.math.vector import Vector
from create.math.transform import Transform
from create.math.matrix import Matrix


def assert_matrix_close(
    got: Matrix[3, 3], expected: Matrix[3, 3], atol: Float64 = 1e-9
) raises:
    for r in range(3):
        for c in range(3):
            assert_almost_equal(got[r, c], expected[r, c], atol=atol)


def assert_point_close(got: Point, expected: Point) raises:
    assert_almost_equal(got.x, expected.x, atol=1e-9)
    assert_almost_equal(got.y, expected.y, atol=1e-9)


def test_default_is_identity() raises:
    var t = Transform()
    assert_equal(Matrix[3, 3](t), Matrix[3, 3](1, 0, 0, 0, 1, 0, 0, 0, 1))
    assert_point_close(t.apply(Point(3, -4)), Point(3, -4))


def test_constructor_scales_then_rotates_then_translates() raises:
    var t = Transform(translation=Vector(3, 4), rotation=PI / 2, scale=2)
    # a quarter turn of a doubled grid: (x, y) to (-2y, 2x), then moved
    assert_matrix_close(
        Matrix[3, 3](t), Matrix[3, 3](0, -2, 3, 2, 0, 4, 0, 0, 1)
    )
    # (1, 0) scaled to (2, 0), turned to (0, 2), moved to (3, 6)
    assert_point_close(t.apply(Point(1, 0)), Point(3, 6))


def test_constructor_with_two_scales() raises:
    var t = Transform(
        translation=Vector(-1, 5), rotation=0.3, scale_x=2, scale_y=-0.5
    )
    var parts = (
        Transform(translation=Vector(-1, 5))
        @ Transform(rotation=0.3)
        @ Transform(scale_x=2, scale_y=-0.5)
    )
    assert_matrix_close(Matrix[3, 3](t), Matrix[3, 3](parts))
    # (1, 0) stretched to (2, 0); (0, 1) squashed and mirrored to (0, -0.5)
    var stretched = Transform(scale_x=2, scale_y=-0.5)
    assert_point_close(stretched.apply(Point(1, 0)), Point(2, 0))
    assert_point_close(stretched.apply(Point(0, 1)), Point(0.0, -0.5))


def test_rotation_turns_counter_clockwise() raises:
    assert_point_close(
        Transform(rotation=PI / 2).apply(Point(1, 0)), Point(0, 1)
    )
    assert_point_close(Transform(rotation=PI).apply(Point(1, 0)), Point(-1, 0))


def test_compose_applies_right_first() raises:
    var move = Transform(translation=Vector(10, 0))
    var turn = Transform(rotation=PI / 2)
    # turn (1, 0) to (0, 1), then move it to (10, 1)
    assert_point_close((move @ turn).apply(Point(1, 0)), Point(10, 1))
    # move (1, 0) to (11, 0), then turn it to (0, 11)
    assert_point_close((turn @ move).apply(Point(1, 0)), Point(0, 11))


def test_compose_matches_matrix_product() raises:
    var a = Transform(translation=Vector(2, -3), rotation=1.1, scale=1.5)
    var b = Transform(
        translation=Vector(-7, 4), rotation=-0.4, scale_x=0.5, scale_y=3
    )
    assert_matrix_close(Matrix[3, 3](a @ b), Matrix[3, 3](a) @ Matrix[3, 3](b))


def test_apply_matches_the_matrix() raises:
    var t = Transform(translation=Vector(2, -3), rotation=1.1, scale=1.5)
    var m = Matrix[3, 3](t)
    var p = t.apply(Point(4, 5))
    assert_almost_equal(p.x, m[0, 0] * 4 + m[0, 1] * 5 + m[0, 2], atol=1e-9)
    assert_almost_equal(p.y, m[1, 0] * 4 + m[1, 1] * 5 + m[1, 2], atol=1e-9)
    var v = t.apply(Vector(4, 5))
    assert_almost_equal(v.x, m[0, 0] * 4 + m[0, 1] * 5, atol=1e-9)
    assert_almost_equal(v.y, m[1, 0] * 4 + m[1, 1] * 5, atol=1e-9)


def test_apply_agrees_on_the_difference_of_two_points() raises:
    # mapping two points and subtracting is mapping their difference
    var t = Transform(
        translation=Vector(-7, 2), rotation=0.6, scale_x=1.5, scale_y=0.5
    )
    var a = Point(1, 2)
    var b = Point(-3.0, 0.5)
    var mapped = t.apply(a) - t.apply(b)
    var direct = t.apply(a - b)
    assert_almost_equal(mapped.x, direct.x, atol=1e-9)
    assert_almost_equal(mapped.y, direct.y, atol=1e-9)


def test_apply_vector_ignores_translation() raises:
    var t = Transform(translation=Vector(100, 100))
    var v = t.apply(Vector(1, 2))
    assert_equal(v, Vector(1, 2))


def test_inverse_undoes() raises:
    var t = Transform(
        translation=Vector(5, -2), rotation=0.7, scale_x=3, scale_y=-0.25
    )
    assert_matrix_close(
        Matrix[3, 3](t.inverse() @ t), Matrix[3, 3](Transform())
    )
    assert_matrix_close(
        Matrix[3, 3](t @ t.inverse()), Matrix[3, 3](Transform())
    )
    var p = Point(12, -8)
    assert_point_close(t.inverse().apply(t.apply(p)), p)


def test_from_matrix_round_trips() raises:
    var m = Matrix[3, 3](1, 2, 3, 4, 5, 6, 0, 0, 1)
    assert_equal(Matrix[3, 3](Transform(m)), m)


def test_from_matrix_raises_for_a_perspective_matrix() raises:
    with assert_raises(contains="bottom row"):
        _ = Transform(Matrix[3, 3](1, 0, 0, 0, 1, 0, 0, 1, 1))
    with assert_raises(contains="bottom row"):
        _ = Transform(Matrix[3, 3](1, 0, 0, 0, 1, 0, 0, 0, 2))


def test_equality() raises:
    assert_true(Transform(scale=2) == Transform(scale_x=2, scale_y=2))
    assert_true(Transform(scale=2) != Transform(scale=3))


def test_prints_as_source() raises:
    assert_equal(
        String(Transform(translation=Vector(3, 4))),
        "Transform(" + String(Matrix[3, 3](1, 0, 3, 0, 1, 4, 0, 0, 1)) + ")",
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
