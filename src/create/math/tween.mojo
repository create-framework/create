from std.math import clamp

from .easing import Easing, ease
from .util import lerp, wrap
from ._run_clock import _scaled_now


struct Tween(Copyable, ImplicitlyCopyable, Movable, Writable):
    """A value moving from one number to another over a fixed duration.

    A tween is a playhead, in the same sense as `Animator`: the program
    owns one per thing being animated. Nothing ticks it: a tween remembers
    when it was started and works out its value from the run's clock
    whenever it is asked. The clock is the run's scaled time,
    `context.time.elapsed`, so slowing or pausing the run's time slows or
    stops every tween with it.

    ```mojo
    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> Self:
        return Self(Tween(0.0, 1.0, 0.4, Easing.OUT_CUBIC))

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        if context.keyboard.pressed(Key.SPACE):
            self.fade.play()
        canvas.fill(Color(255, 255, 255, Int(255 * self.fade.value())))
    ```

    Unlike an animation, a tween carries no shared artwork -- its whole
    definition is four numbers -- so there is no asset to hold by `ArcPointer`
    and every entity simply owns its own.

    **Tweening something that is not a number.** `Tween(duration)` runs 0 to 1,
    which is exactly what `Vector2D.lerp` and `Color.lerp` take, so one scalar
    tween drives a position or a colour without a second type:

    ```mojo
    self.slide = Tween(0.3, Easing.OUT_CUBIC)      # in create
    ...
    self.position = self.from_position.lerp(self.to_position, self.slide.value())
    ```

    Constructed stopped at `start` -- nothing moves until `play`, `loop` or
    `ping_pong`. The verbs mean what they mean on `Animator`: `play`
    always restarts from the beginning, `pause` freezes where it is and
    `resume` continues from there.
    """

    var start: Float64
    """The value at `progress` 0."""

    var end: Float64
    """The value at `progress` 1."""

    var duration: Float64
    """Seconds for a full run, start to end."""

    var curve: Easing
    """The easing curve applied to `progress` to get `value`."""

    var _started: Bool
    var _paused: Bool
    var _looping: Bool
    var _ping_pong: Bool
    var _began: Float64
    """The clock's time at the start of the current run, while it runs."""
    var _held: Float64
    """Seconds into the run where `pause` froze it."""

    def __init__(
        out self,
        start: Float64,
        end: Float64,
        duration: Float64,
        curve: Easing = Easing.LINEAR,
    ):
        """A tween from `start` to `end` over `duration` seconds."""
        debug_assert(
            duration > 0.0, "Tween: duration must be greater than zero"
        )
        self.start = start
        self.end = end
        self.duration = duration
        self.curve = curve
        self._started = False
        self._paused = False
        self._looping = False
        self._ping_pong = False
        self._began = 0.0
        self._held = 0.0

    def __init__(out self, duration: Float64, curve: Easing = Easing.LINEAR):
        """A tween from 0 to 1 -- the fraction `Vector2D.lerp` and `Color.lerp`
        take, and the form to reach for when animating anything that is not a
        plain number."""
        self = Self(0.0, 1.0, duration, curve)

    def value(self) -> Float64:
        """The eased value, between `start` and `end`."""
        return lerp(self.start, self.end, ease(self.curve, self.progress()))

    def progress(self) -> Float64:
        """How far through the duration, 0 to 1, *before* easing.

        The raw time fraction, so it is what a progress bar wants to render --
        and what `value` is derived from. While ping-ponging it runs back down
        to 0.
        """
        var runs = self._seconds() / self.duration
        if self._ping_pong:
            # Out and back is one cycle of two runs.
            var cycle = wrap(runs, 2.0)
            return cycle if cycle <= 1.0 else 2.0 - cycle
        if self._looping:
            return wrap(runs, 1.0)
        return clamp(runs, 0.0, 1.0)

    def play(mut self):
        """Run once from the start, holding `end` at the finish."""
        self._began = _scaled_now()
        self._started = True
        self._paused = False
        self._looping = False
        self._ping_pong = False

    def loop(mut self):
        """Run from the start, snapping back and repeating forever.

        The snap is visible whenever `start` and `end` differ, which is what
        `ping_pong` exists to avoid -- reach for this only when the value wraps
        naturally, like a rotation through a full turn.
        """
        self.play()
        self._looping = True

    def ping_pong(mut self):
        """Run to `end`, back to `start`, forever -- the usual way to loop a
        tween, since it never snaps.

        `progress` runs back down on the return leg, so the easing curve is
        travelled backwards too and a `Easing.OUT_CUBIC` pulse decelerates into
        both ends rather than into one.
        """
        self.play()
        self._looping = True
        self._ping_pong = True

    def pause(mut self):
        """Freeze at the current value. `resume` continues from here."""
        if self.is_playing():
            self._held = self._seconds()
            self._paused = True

    def resume(mut self):
        """Continue a paused tween without rewinding. A stopped one starts
        from the beginning; a finished `play` stays finished."""
        if self._paused:
            self._began = _scaled_now() - self._held
            self._paused = False
        elif not self._started:
            self._began = _scaled_now()
            self._started = True

    def stop(mut self):
        """Halt and rewind, putting `value` back to `start`."""
        self._started = False
        self._paused = False

    def is_playing(self) -> Bool:
        """True while the playhead is advancing -- false when stopped, paused
        or finished."""
        return self._started and not self._paused and not self.is_finished()

    def is_finished(self) -> Bool:
        """True once a `play` reached `end`. Never true for `loop` or
        `ping_pong`, which have no end to reach."""
        return (
            self._started
            and not self._looping
            and self._seconds() >= self.duration
        )

    def write_to[W: Writer](self, mut writer: W):
        # The public state only: the loop and direction flags have no reader.
        writer.write(
            "Tween(value=",
            self.value(),
            ", progress=",
            self.progress(),
            ", start=",
            self.start,
            ", end=",
            self.end,
            ", duration=",
            self.duration,
            ", curve=",
            self.curve,
            ", playing=",
            self.is_playing(),
            ", finished=",
            self.is_finished(),
            ")",
        )

    def _seconds(self) -> Float64:
        """Seconds into the run: frozen while paused, zero while stopped.
        Never below 0, as a clock restarted by a new run is behind a tween
        started in the last one."""
        if not self._started:
            return 0.0
        if self._paused:
            return self._held
        return max(_scaled_now() - self._began, 0.0)
