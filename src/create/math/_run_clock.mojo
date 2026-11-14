"""The run's clock, process-wide, for the playheads to read.

`Animator` and `Tween` work out where they are from the time they were
started and the time now, rather than being ticked, so they need a clock that
no argument carries to them. The run loop publishes `Context.time` here once a
frame, as it ticks, so the clock holds still for the whole of a frame and
every read in it agrees. Only the loop writes it; nothing but a test sets it
by hand.

Outside a run nothing ticks it, so it reads zero and a playhead stays on its
first frame.
"""

from std.ffi import _Global
from std.os import abort


struct _RunClock(Movable):
    var scaled: Float64
    """Seconds of the run's scaled time: `Context.time.elapsed`, which the
    time scale slows and pausing stops."""
    var real: Float64
    """Seconds of the run's real time: `Context.time.real_elapsed`."""

    def __init__(out self):
        self.scaled = 0.0
        self.real = 0.0


def _new_run_clock() -> _RunClock:
    return _RunClock()


comptime _RUN_CLOCK = _Global["create_run_clock", _new_run_clock]


@always_inline
def _run_clock() -> Pointer[_RunClock, MutUntrackedOrigin]:
    try:
        return _RUN_CLOCK.get_or_create_ptr()
    except e:
        # Only fails if the runtime cannot allocate the global at all.
        abort(String("create: the run clock is unavailable: ", e))


def _scaled_now() -> Float64:
    """The run's scaled time now, in seconds."""
    return _run_clock()[].scaled


def _real_now() -> Float64:
    """The run's real time now, in seconds."""
    return _run_clock()[].real


def _set_run_clock(scaled: Float64, real: Float64):
    """Publish the run's time: the run loop's call, once a frame."""
    var clock = _run_clock()
    clock[].scaled = scaled
    clock[].real = real
