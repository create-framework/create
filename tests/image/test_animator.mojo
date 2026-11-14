from std.testing import TestSuite, assert_equal, assert_true, assert_false
from create.image import Image, Animation, Animator
from create.color import Color
from create.math._run_clock import _scaled_now, _real_now, _set_run_clock


def _advance(seconds: Float64):
    """Move the run's clock on, as the run loop does between frames."""
    _set_run_clock(_scaled_now() + seconds, _real_now() + seconds)


def _animation(count: Int, fps: Float64 = 10.0) raises -> Animation:
    var frames = List[Image]()
    for i in range(count):
        frames.append(Image.solid(1, 1, Color(UInt8(i), 0, 0)))
    return Animation(frames^, fps)


def test_starts_stopped_on_frame_zero() raises -> None:
    var a = Animator(_animation(4))
    assert_equal(a.frame_index(), 0)
    assert_false(a.is_playing())
    _advance(10.0)
    assert_equal(a.frame_index(), 0)


def test_advances_at_the_animation_rate() raises -> None:
    var a = Animator(_animation(4, fps=10.0))
    a.play()
    _advance(0.09)
    assert_equal(a.frame_index(), 0)
    _advance(0.02)  # 0.11s total -- one frame duration passed
    assert_equal(a.frame_index(), 1)


def test_loop_wraps() raises -> None:
    var a = Animator(_animation(4, fps=10.0))
    a.loop()
    for _ in range(10):
        _advance(0.1)
    # 10 steps over 4 frames: 0 -> 10 % 4 == 2
    assert_equal(a.frame_index(), 2)
    assert_true(a.is_playing())
    assert_false(a.is_finished())


def test_play_holds_the_last_frame() raises -> None:
    var a = Animator(_animation(4, fps=10.0))
    a.play()
    for _ in range(10):
        _advance(0.1)
    assert_equal(a.frame_index(), 3)
    assert_false(a.is_playing())
    assert_true(a.is_finished())


def test_a_long_frame_skips_ahead() raises -> None:
    var a = Animator(_animation(8, fps=10.0))
    a.loop()
    _advance(1.0)
    # Ten frame durations over eight frames.
    assert_equal(a.frame_index(), 2)


def test_pause_freezes_and_resume_continues() raises -> None:
    var a = Animator(_animation(4, fps=10.0))
    a.loop()
    _advance(0.1)
    a.pause()
    assert_false(a.is_playing())
    _advance(10.0)
    assert_equal(a.frame_index(), 1)
    a.resume()
    _advance(0.1)
    assert_equal(a.frame_index(), 2)


def test_stop_rewinds() raises -> None:
    var a = Animator(_animation(4, fps=10.0))
    a.loop()
    _advance(0.2)
    a.stop()
    assert_equal(a.frame_index(), 0)
    assert_false(a.is_playing())
    _advance(10.0)
    assert_equal(a.frame_index(), 0)


def test_resume_after_finish_does_not_restart() raises -> None:
    var a = Animator(_animation(2, fps=10.0))
    a.play()
    _advance(1.0)
    assert_true(a.is_finished())
    a.resume()
    assert_false(a.is_playing())
    assert_equal(a.frame_index(), 1)


def test_use_of_the_current_animation_is_a_no_op() raises -> None:
    var anim = _animation(4, fps=10.0)
    var a = Animator(anim)
    a.loop()
    _advance(0.2)
    assert_equal(a.frame_index(), 2)
    # The call every frame from a movement branch -- must not rewind.
    for _ in range(3):
        a.use(anim)
        assert_equal(a.frame_index(), 2)
        assert_true(a.is_playing())


def test_use_every_frame_keeps_playing() raises -> None:
    var anim = _animation(4, fps=10.0)
    var a = Animator(anim)
    for _ in range(6):
        a.use(anim)
        _advance(0.1)
    # Started by the first use, never rewound since: 6 steps over 4 frames.
    assert_equal(a.frame_index(), 2)
    assert_true(a.is_playing())


def test_use_starts_a_stopped_animator() raises -> None:
    var anim = _animation(4, fps=10.0)
    var a = Animator(anim)
    a.use(anim)
    assert_true(a.is_playing())
    _advance(0.2)
    a.stop()
    a.use(anim)
    assert_true(a.is_playing())
    assert_equal(a.frame_index(), 0)


def test_use_leaves_a_pause_alone() raises -> None:
    var anim = _animation(4, fps=10.0)
    var a = Animator(anim)
    a.use(anim)
    _advance(0.1)
    a.pause()
    for _ in range(3):
        a.use(anim)
        _advance(0.1)
    assert_false(a.is_playing())
    assert_equal(a.frame_index(), 1)
    a.resume()
    _advance(0.1)
    assert_equal(a.frame_index(), 2)


def test_use_leaves_a_finished_one_shot_on_its_last_frame() raises -> None:
    var anim = _animation(2, fps=10.0)
    var a = Animator(anim)
    a.play()
    _advance(1.0)
    a.use(anim)
    assert_true(a.is_finished())
    assert_equal(a.frame_index(), 1)


def test_use_of_another_animation_switches_and_loops() raises -> None:
    var a = Animator(_animation(4, fps=10.0))
    a.loop()
    _advance(0.2)
    a.use(_animation(2, fps=10.0))
    assert_equal(a.frame_index(), 0)
    assert_true(a.is_playing())
    assert_equal(a.animation().frame_count(), 2)
    for _ in range(3):
        _advance(0.1)
    assert_equal(a.frame_index(), 1)
    assert_false(a.is_finished())


def test_play_with_an_animation_switches_and_starts() raises -> None:
    var a = Animator(_animation(4, fps=10.0))
    a.play(_animation(2, fps=10.0))
    assert_true(a.is_playing())
    assert_equal(a.animation().frame_count(), 2)
    _advance(0.1)
    assert_equal(a.frame_index(), 1)


def test_play_restarts_the_current_animation() raises -> None:
    var anim = _animation(4, fps=10.0)
    var a = Animator(anim)
    a.loop()
    _advance(0.2)
    a.play(anim)
    assert_equal(a.frame_index(), 0)
    assert_true(a.is_playing())


def test_play_replays_a_finished_one_shot() raises -> None:
    var anim = _animation(2, fps=10.0)
    var a = Animator(anim)
    a.play(anim)
    _advance(1.0)
    assert_true(a.is_finished())
    a.play(anim)
    assert_equal(a.frame_index(), 0)
    assert_true(a.is_playing())
    assert_false(a.is_finished())


def test_loop_restarts_the_current_animation() raises -> None:
    var anim = _animation(4, fps=10.0)
    var a = Animator(anim)
    a.loop(anim)
    _advance(0.2)
    a.loop(anim)
    assert_equal(a.frame_index(), 0)
    assert_true(a.is_playing())


def test_single_frame_animation_finishes() raises -> None:
    var a = Animator(_animation(1, fps=10.0))
    a.play()
    _advance(0.1)
    assert_equal(a.frame_index(), 0)
    assert_true(a.is_finished())


def test_writes_the_playhead() raises -> None:
    var a = Animator(_animation(4, fps=10.0))
    a.loop()
    _advance(0.2)
    assert_equal(String(a), "Animator(frame_index=2)")


def test_a_copy_keeps_time_until_commanded() raises -> None:
    var a = Animator(_animation(4, fps=10.0))
    a.loop()
    _advance(0.1)
    var b = a.copy()
    _advance(0.1)
    assert_equal(a.frame_index(), 2)
    assert_equal(b.frame_index(), 2)
    b.loop()
    _advance(0.1)
    assert_equal(a.frame_index(), 3)
    assert_equal(b.frame_index(), 1)
    assert_true(a.animation()._is(b.animation()))


def test_keeps_time_without_being_ticked() raises -> None:
    var a = Animator(_animation(4, fps=10.0))
    a.loop()
    _advance(0.25)
    assert_equal(a.frame_index(), 2)
    # Asking again in the same frame gives the same answer.
    assert_equal(a.frame_index(), 2)


def test_lands_on_a_frame_exactly_at_its_start() raises -> None:
    var a = Animator(_animation(8, fps=10.0))
    a.loop()
    for _ in range(3):
        _advance(0.1)
    assert_equal(a.frame_index(), 3)


def test_a_clock_restarted_behind_it_shows_frame_zero() raises -> None:
    _set_run_clock(100.0, 100.0)
    var a = Animator(_animation(4, fps=10.0))
    a.loop()
    _set_run_clock(0.0, 0.0)
    assert_equal(a.frame_index(), 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
