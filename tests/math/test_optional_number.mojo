from std.testing import TestSuite, assert_equal, assert_false, assert_true
from create.math import OptionalNumber


def given(number: OptionalNumber = None) -> OptionalNumber:
    return number


def test_takes_every_kind_of_number() raises -> None:
    var count: Int = 3
    var size: Float64 = 1.5
    assert_equal(given(12).value(), 12.0)
    assert_equal(given(1.5).value(), 1.5)
    assert_equal(given(count).value(), 3.0)
    assert_equal(given(size).value(), 1.5)
    assert_equal(given(Optional[Float64](2.0)).value(), 2.0)


def test_left_out_is_none() raises -> None:
    assert_false(Bool(given()))
    assert_false(Bool(given(None)))
    assert_true(Bool(given(0)))


def test_or_else() raises -> None:
    assert_equal(given().or_else(4), 4.0)
    assert_equal(given(7).or_else(4), 7.0)


def test_prints_as_written() raises -> None:
    assert_equal(String(given(12)), "OptionalNumber(12.0)")
    assert_equal(String(given()), "OptionalNumber(None)")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
