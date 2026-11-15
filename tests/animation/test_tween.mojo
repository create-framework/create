from std.testing import (
    TestSuite,
    assert_equal,
    assert_almost_equal,
    assert_true,
    assert_false,
)
from create.math.easing import Easing
from create.animation.tween import Tween
from create.time.clock import Clock
from create.time._run_clock import _scaled_now, _real_now, _set_run_clock


def _advance(seconds: Float64):
    """Move the run's clock on, as the run loop does between frames."""
    _set_run_clock(_scaled_now() + seconds, _real_now() + seconds)


# --- Tween: construction -----------------------------------------------------


def test_tween_starts_stopped_at_start() raises -> None:
    var t = Tween(10.0, 20.0, 1.0)
    assert_equal(t.value(), 10.0)
    assert_equal(t.progress(), 0.0)
    assert_false(t.is_playing())
    assert_false(t.is_finished())


def test_tween_does_not_move_until_played() raises -> None:
    var t = Tween(10.0, 20.0, 1.0)
    _advance(0.5)
    assert_equal(t.value(), 10.0)


def test_tween_duration_only_runs_zero_to_one() raises -> None:
    var t = Tween(1.0)
    assert_equal(t.start, 0.0)
    assert_equal(t.end, 1.0)
    t.play()
    _advance(0.25)
    assert_almost_equal(t.value(), 0.25)


def test_tween_defaults_to_linear() raises -> None:
    var t = Tween(1.0)
    assert_true(t.curve == Easing.LINEAR)


# --- Tween: play -------------------------------------------------------------


def test_tween_advances_linearly() raises -> None:
    var t = Tween(0.0, 100.0, 2.0)
    t.play()
    _advance(0.5)
    assert_almost_equal(t.progress(), 0.25)
    assert_almost_equal(t.value(), 25.0)


def test_tween_applies_its_curve() raises -> None:
    var t = Tween(0.0, 100.0, 1.0, Easing.IN_QUAD)
    t.play()
    _advance(0.5)
    assert_almost_equal(t.progress(), 0.5)
    assert_almost_equal(t.value(), 25.0)


def test_tween_lands_exactly_on_end() raises -> None:
    var t = Tween(0.0, 100.0, 1.0)
    t.play()
    _advance(0.7)
    _advance(0.7)
    assert_equal(t.progress(), 1.0)
    assert_equal(t.value(), 100.0)


def test_tween_finishes_and_stops() raises -> None:
    var t = Tween(0.0, 100.0, 1.0)
    t.play()
    _advance(2.0)
    assert_true(t.is_finished())
    assert_false(t.is_playing())


def test_tween_holds_its_end_after_finishing() raises -> None:
    var t = Tween(0.0, 100.0, 1.0)
    t.play()
    _advance(2.0)
    _advance(2.0)
    assert_equal(t.value(), 100.0)


def test_tween_play_restarts_from_the_beginning() raises -> None:
    var t = Tween(0.0, 100.0, 1.0)
    t.play()
    _advance(0.6)
    t.play()
    assert_equal(t.progress(), 0.0)
    assert_equal(t.value(), 0.0)
    assert_true(t.is_playing())


def test_tween_play_clears_finished() raises -> None:
    var t = Tween(0.0, 100.0, 1.0)
    t.play()
    _advance(2.0)
    t.play()
    assert_false(t.is_finished())


def test_tween_runs_backwards_when_end_is_below_start() raises -> None:
    var t = Tween(100.0, 0.0, 1.0)
    t.play()
    _advance(0.25)
    assert_almost_equal(t.value(), 75.0)


# --- Tween: pause, resume, stop ----------------------------------------------


def test_tween_pause_freezes_the_value() raises -> None:
    var t = Tween(0.0, 100.0, 1.0)
    t.play()
    _advance(0.3)
    t.pause()
    _advance(0.5)
    assert_almost_equal(t.value(), 30.0)
    assert_false(t.is_playing())


def test_tween_resume_continues_without_rewinding() raises -> None:
    var t = Tween(0.0, 100.0, 1.0)
    t.play()
    _advance(0.3)
    t.pause()
    t.resume()
    _advance(0.2)
    assert_almost_equal(t.value(), 50.0)


def test_tween_resume_does_not_restart_a_finished_tween() raises -> None:
    var t = Tween(0.0, 100.0, 1.0)
    t.play()
    _advance(2.0)
    t.resume()
    assert_false(t.is_playing())


def test_tween_stop_rewinds_to_start() raises -> None:
    var t = Tween(10.0, 20.0, 1.0)
    t.play()
    _advance(0.5)
    t.stop()
    assert_equal(t.progress(), 0.0)
    assert_equal(t.value(), 10.0)
    assert_false(t.is_playing())


# --- Tween: loop -------------------------------------------------------------


def test_tween_loop_wraps_instead_of_finishing() raises -> None:
    var t = Tween(0.0, 100.0, 1.0)
    t.loop()
    _advance(1.25)
    assert_almost_equal(t.progress(), 0.25)
    assert_almost_equal(t.value(), 25.0)
    assert_true(t.is_playing())
    assert_false(t.is_finished())


def test_tween_loop_keeps_running_over_many_cycles() raises -> None:
    var t = Tween(0.0, 100.0, 1.0)
    t.loop()
    for _ in range(100):
        _advance(0.1)
    assert_true(t.is_playing())
    assert_true(t.progress() >= 0.0 and t.progress() <= 1.0)


# --- Tween: ping_pong --------------------------------------------------------


def test_tween_ping_pong_reverses_at_the_end() raises -> None:
    var t = Tween(0.0, 100.0, 1.0)
    t.ping_pong()
    _advance(0.8)
    assert_almost_equal(t.value(), 80.0)
    _advance(0.4)
    # 0.2 into the return leg, so back down to 0.8.
    assert_almost_equal(t.progress(), 0.8)
    assert_almost_equal(t.value(), 80.0)


def test_tween_ping_pong_reverses_again_at_the_start() raises -> None:
    var t = Tween(0.0, 100.0, 1.0)
    t.ping_pong()
    _advance(1.5)  # to 1.0, reflected back to 0.5
    _advance(0.7)  # down past 0 to -0.2, reflected up to 0.2
    assert_almost_equal(t.progress(), 0.2)
    assert_true(t.is_playing())


def test_tween_ping_pong_never_finishes() raises -> None:
    var t = Tween(0.0, 100.0, 1.0)
    t.ping_pong()
    for _ in range(100):
        _advance(0.13)
        assert_false(t.is_finished())
        assert_true(t.progress() >= 0.0 and t.progress() <= 1.0)


def test_tween_ping_pong_survives_a_frame_longer_than_its_duration() raises -> (
    None
):
    """A frame past the far end must leave progress inside 0..1 -- the value
    would otherwise stop tracking the curve."""
    var t = Tween(0.0, 100.0, 0.1)
    t.ping_pong()
    _advance(5.0)
    assert_true(t.progress() >= 0.0 and t.progress() <= 1.0)
    assert_true(t.value() >= 0.0 and t.value() <= 100.0)


# --- Tween: the clock ----------------------------------------------------------


def test_tween_keeps_time_without_being_ticked() raises -> None:
    var t = Tween(0.0, 100.0, 1.0)
    t.play()
    _advance(0.4)
    assert_almost_equal(t.value(), 40.0)
    # Asking again in the same frame gives the same answer.
    assert_almost_equal(t.value(), 40.0)


def test_tween_follows_a_duration_changed_mid_run() raises -> None:
    var t = Tween(0.0, 100.0, 1.0)
    t.play()
    _advance(0.5)
    t.duration = 2.0
    assert_almost_equal(t.progress(), 0.25)


def test_tween_a_clock_restarted_behind_it_reads_start() raises -> None:
    _set_run_clock(100.0, 100.0)
    var t = Tween(10.0, 20.0, 1.0)
    t.play()
    _set_run_clock(0.0, 0.0)
    assert_equal(t.value(), 10.0)


def _advance_real_only(seconds: Float64):
    """Move real time on with the run's time paused."""
    _set_run_clock(_scaled_now(), _real_now() + seconds)


def test_tween_holds_while_the_run_time_is_paused() raises -> None:
    var t = Tween(0.0, 100.0, 1.0)
    t.play()
    _advance(0.2)
    _advance_real_only(0.5)
    assert_almost_equal(t.value(), 20.0)


def test_tween_on_real_time_runs_through_a_pause() raises -> None:
    var t = Tween(0.0, 100.0, 1.0, clock=Clock.REAL)
    assert_true(t.clock == Clock.REAL)
    t.play()
    _advance(0.2)
    _advance_real_only(0.5)
    assert_almost_equal(t.value(), 70.0)


def test_tween_duration_only_takes_a_clock() raises -> None:
    var t = Tween(1.0, Easing.OUT_CUBIC, Clock.REAL)
    assert_true(t.clock == Clock.REAL)


# --- write_to -----------------------------------------------------------------


def test_tween_writes_its_public_state() raises -> None:
    var t = Tween(0.0, 10.0, 2.0, Easing.OUT_CUBIC)
    t.play()
    assert_equal(
        String(t),
        (
            "Tween(value=0.0, progress=0.0, start=0.0, end=10.0, duration=2.0,"
            " curve=Easing.OUT_CUBIC, clock=Clock.SCALED, playing=True,"
            " finished=False)"
        ),
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
