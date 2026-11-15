struct Time(Copyable, ImplicitlyCopyable, Movable, Writable):
    """Per-frame timing, ticked once per frame by the run loop.

    Two clocks run side by side. **Scaled time**, `delta` and `elapsed`, is
    the program's: the time scale slows or speeds it and pausing the run's
    time stops it (`context.time_scale`, `context.time_paused`), and every
    `Animator` and `Tween` keeps time by it. Move things by `delta` and they
    slow and pause along with the animations. **Real time**, `real_delta`
    and `real_elapsed`, is the wall clock's and ignores both, for what must
    keep going while the program's time is paused, like a pause menu.

    Owns the previous tick stamp so the frame delta is derived in one place.
    `_start` must seed that stamp before the first `_tick`: the window clock
    counts from process start, not from zero, so an unseeded first frame would
    report the whole uptime as its delta and spike anything integrating it.
    """

    var delta: Float64
    """Seconds of scaled time since the previous frame -- multiply motion by
    this. Zero while the run's time is paused."""

    var elapsed: Float64
    """Seconds of scaled time accumulated since the first frame."""

    var real_delta: Float64
    """Seconds of real time since the previous frame, whatever the time
    scale."""

    var real_elapsed: Float64
    """Seconds of real time accumulated since the first frame."""

    var _last: Int
    var _real_millis: Int
    """`real_elapsed` in whole milliseconds, summed as integers so it never
    drifts from the window clock."""

    def __init__(out self):
        self.delta = 0.0
        self.elapsed = 0.0
        self.real_delta = 0.0
        self.real_elapsed = 0.0
        self._last = 0
        self._real_millis = 0

    def write_to[W: Writer](self, mut writer: W):
        writer.write(
            "Time(delta=",
            self.delta,
            ", elapsed=",
            self.elapsed,
            ", real_delta=",
            self.real_delta,
            ", real_elapsed=",
            self.real_elapsed,
            ")",
        )

    def _start(mut self, now: Int):
        """Seed the tick stamp so the first frame's delta is a frame, not the
        window clock's whole history."""
        self._last = now

    def _tick(mut self, now: Int, scale: Float64 = 1.0):
        """Advance both clocks to the window clock's `now`, in milliseconds,
        scaled time by `scale` times the real step.

        Scaled time is summed step by step rather than derived from real time,
        so changing the scale never makes it jump.
        """
        var millis = now - self._last
        self._real_millis += millis
        self.real_delta = Float64(millis) / 1000.0
        self.real_elapsed = Float64(self._real_millis) / 1000.0
        self.delta = self.real_delta * scale
        self.elapsed += self.delta
        self._last = now
