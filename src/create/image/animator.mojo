from create.image.animation import Animation
from create.math._run_clock import _scaled_now

comptime _FRAME_SLACK = 1e-6
"""A hair of a frame, so a clock landing exactly on a frame's start, give or
take floating-point rounding, counts as being on it."""


struct Animator(Copyable, Movable, Writable):
    """The playhead over one `Animation`.

    An animation is the artwork and never moves; an animator is the frame a
    particular entity is on right now, so an entity owns one and several can
    share the same animation.

    Nothing ticks it: an animator remembers when it was started and works out
    its frame from the run's clock whenever it is asked, so it keeps time
    with no call each frame. The clock is the run's scaled time,
    `context.time.elapsed`, so slowing or pausing the run's time slows or
    stops every animator with it.

    Constructed stopped on frame 0 -- nothing advances until `play`, `loop`
    or `use`. Two kinds of call drive it:

    - **Commands**, for something that just happened (a key, a hit): `play`
      runs the animation once and holds the last frame, `loop` wraps forever,
      and both always start from frame 0, with or without a new animation, as
      `Tween.play` and `Audio.play` always start. `pause` freezes where it is
      and `resume` continues from there; `stop` rewinds.
    - **`use`**, for what should be showing now, called every frame from the
      branch that decides it. Naming the animation already held changes
      nothing, so it never rewinds a running loop or undoes a `pause`.

    ```mojo
    if context.keyboard.pressed(Key.SPACE):
        self.animator.play(self.spin)    # a command: starts every time
    elif not self.spinning:
        self.animator.use(self.run if moving else self.idle)   # a state
    ```

    A copy keeps the original's timing: both show the same frame until a
    command is given to one of them.
    """

    var _animation: Animation
    var _started: Bool
    """Whether `play`, `loop`, `use` or `resume` has set the playhead going
    since construction, the last `stop` or the last switch -- what tells a
    paused or finished animation, which `use` leaves be, from a stopped one,
    which it starts."""
    var _paused: Bool
    var _looping: Bool
    var _start: Float64
    """The clock's time at frame 0 of the current run, while it runs."""
    var _held: Float64
    """Seconds into the animation where `pause` froze it."""

    def __init__(out self, var animation: Animation):
        """Hold `animation`, stopped on frame 0.

        An animator always has an animation, so there is no empty state to
        guard against when rendering.
        """
        self._animation = animation^
        self._started = False
        self._paused = False
        self._looping = False
        self._start = 0.0
        self._held = 0.0

    def animation(self) -> Animation:
        """The animation being played, sharing its frames. Switch with `use`,
        `play` or `loop`."""
        return self._animation

    def frame_index(self) -> Int:
        """The frame showing, counted from 0."""
        var count = self._animation.frame_count()
        var passed = self._frames_passed()
        if self._looping:
            return passed % count
        return min(passed, count - 1)

    def write_to[W: Writer](self, mut writer: W):
        # The animation is a shared asset, not printable, so only the
        # playhead shows.
        writer.write("Animator(frame_index=", self.frame_index(), ")")

    def use(mut self, var animation: Animation):
        """Show `animation`, looping: the call to make every frame from the
        branch that decides which animation applies.

        ```mojo
        if self.velocity.x != 0.0:
            self.animator.use(self.run)
        else:
            self.animator.use(self.idle)
        ```

        Naming the animation already held, once it has been started, does
        nothing at all: a loop keeps its place, a `pause` holds and a
        finished `play` stays on its last frame. Otherwise -- another
        animation, or this one stopped -- it starts `animation` looping from
        frame 0. A one-shot is a command, not a state: `play` it when the
        thing that triggers it happens.
        """
        if self._animation._is(animation) and self._started:
            return
        self.loop(animation^)

    def play(mut self):
        """Play once from frame 0, holding the last frame at the end."""
        self._start = _scaled_now()
        self._started = True
        self._paused = False
        self._looping = False

    def play(mut self, var animation: Animation):
        """Switch to `animation` and play it once from frame 0 -- restarting
        it if it is the one already held."""
        self._animation = animation^
        self.play()

    def loop(mut self):
        """Play from frame 0, wrapping to the start forever."""
        self.play()
        self._looping = True

    def loop(mut self, var animation: Animation):
        """Switch to `animation` and loop it from frame 0 -- restarting it if
        it is the one already held. To keep a running loop's place, `use`
        it."""
        self._animation = animation^
        self.loop()

    def pause(mut self):
        """Freeze on the current frame. `resume` continues from here."""
        if self.is_playing():
            self._held = self._seconds()
            self._paused = True

    def resume(mut self):
        """Continue a paused animation without rewinding. A stopped one
        starts from frame 0; a finished `play` stays finished."""
        if self._paused:
            self._start = _scaled_now() - self._held
            self._paused = False
        elif not self._started:
            self._start = _scaled_now()
            self._started = True

    def stop(mut self):
        """Halt and rewind to frame 0."""
        self._started = False
        self._paused = False

    def is_playing(self) -> Bool:
        """True while the playhead is advancing -- false when stopped, paused
        or finished."""
        return self._started and not self._paused and not self.is_finished()

    def is_finished(self) -> Bool:
        """True once a `play` has shown its last frame for a frame's length.
        Never true for `loop`."""
        return (
            self._started
            and not self._looping
            and self._frames_passed() >= self._animation.frame_count()
        )

    def _seconds(self) -> Float64:
        """Seconds into the animation: frozen while paused, zero while
        stopped."""
        if not self._started:
            return 0.0
        if self._paused:
            return self._held
        return _scaled_now() - self._start

    def _frames_passed(self) -> Int:
        """Whole frame durations since frame 0, without wrapping."""
        # Never below 0: a clock restarted by a new run is behind an
        # animator started in the last one.
        return max(Int(self._seconds() * self._animation.fps + _FRAME_SLACK), 0)
