from std.testing import TestSuite, assert_equal
from create.time.clock import Clock
from create.time._run_clock import _set_run_clock


def test_each_clock_reads_its_own_time() raises -> None:
    _set_run_clock(1.5, 4.0)
    assert_equal(Clock.SCALED._now(), 1.5)
    assert_equal(Clock.REAL._now(), 4.0)
    _set_run_clock(0.0, 0.0)


def test_clock_writes_its_constant_name() raises -> None:
    assert_equal(String(Clock.SCALED), "Clock.SCALED")
    assert_equal(String(Clock.REAL), "Clock.REAL")
    assert_equal(String(Clock(7)), "Clock(7)")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
