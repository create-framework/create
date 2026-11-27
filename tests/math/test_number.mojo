from std.testing import TestSuite, assert_equal
from create.math import Number, OptionalNumber, Point, Vector, lerp
from create.geometry import Circle, Rectangle


def given(number: Number) -> Float64:
    return Float64(number)


def test_takes_every_kind_of_number() raises -> None:
    var count: Int = 3
    var size: Float64 = 1.5
    assert_equal(given(12), 12.0)
    assert_equal(given(1.5), 1.5)
    assert_equal(given(count), 3.0)
    assert_equal(given(count * 2), 6.0)
    assert_equal(given(size), 1.5)


def test_becomes_an_optional_number() raises -> None:
    var number: Number = 4
    var optional: OptionalNumber = number
    assert_equal(optional.value(), 4.0)
    assert_equal(OptionalNumber(None).or_else(number), 4.0)


def test_library_parameters_take_int_variables() raises -> None:
    var i = 4
    assert_equal(lerp(0, 10, i), 40.0)
    assert_equal(Point(i, 1.5), Point(4.0, 1.5))
    assert_equal(Vector(i, i) * i, Vector(16.0, 16.0))
    assert_equal(Circle((0, 0), i * 5).radius, 20.0)
    assert_equal(Rectangle((0, 0), i, 2.5).width, 4.0)


def test_prints_as_written() raises -> None:
    assert_equal(String(Number(12)), "Number(12.0)")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
