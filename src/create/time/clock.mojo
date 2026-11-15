"""Which of the run's two clocks a playhead keeps time by.

An `Animator` or `Tween` keeps time by the run's scaled time unless built
with `clock=Clock.REAL`, the way to keep a pause menu's own animations going
while the program's time is paused.
"""

from ._run_clock import _real_now, _scaled_now


struct Clock(Copyable, Equatable, ImplicitlyCopyable, Movable, Writable):
    """The run's scaled time or its real time, for a playhead to keep time
    by.

    - `SCALED`, the default: `context.time.elapsed`, which
      `context.time_scale` slows and `context.time_paused` stops. What the
      program's own motion moves by, so animation and motion stay in step.
    - `REAL`: `context.time.real_elapsed`, which ignores both. For what must
      keep moving while the program's time stands still, like a pause menu.
    """

    var value: Int

    comptime SCALED = Clock(0)
    comptime REAL = Clock(1)

    def __init__(out self, value: Int):
        self.value = value

    def __eq__(self, other: Clock) -> Bool:
        return self.value == other.value

    def __ne__(self, other: Clock) -> Bool:
        return self.value != other.value

    def write_to[W: Writer](self, mut writer: W):
        if self == Clock.SCALED:
            writer.write("Clock.SCALED")
        elif self == Clock.REAL:
            writer.write("Clock.REAL")
        else:
            writer.write("Clock(", self.value, ")")

    def _now(self) -> Float64:
        """This clock's time now, in seconds."""
        if self == Clock.REAL:
            return _real_now()
        return _scaled_now()
