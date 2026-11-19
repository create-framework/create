# Tween

```mojo
struct Tween
```

A value moving from one number to another over a fixed duration.

A tween is a playhead, in the same sense as `Animator`: the program
owns one per thing being animated. Nothing ticks it: a tween remembers
when it was started and works out its value from the run's clock
whenever it is asked. The clock is the run's scaled time,
`context.time.elapsed`, so slowing or pausing the run's time slows or
stops every tween with it; a tween built with `clock=Clock.REAL` runs on
real time instead, as a pause menu's own animation must.

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
which is exactly what `Vector.lerp` and `Color.lerp` take, so one scalar
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

Implements `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `Writable`.

## Fields

- `start: Float64`: The value at `progress` 0.
- `end: Float64`: The value at `progress` 1.
- `duration: Float64`: Seconds for a full run, start to end.
- `curve: Easing`: The easing curve applied to `progress` to get `value`.
- `clock: Clock`: The run's clock the tween keeps time by: `Clock.SCALED`, which the time scale and pause apply to, unless built with `Clock.REAL`. Change it while stopped: the run under way was timed by the other clock.

## Constructors

```mojo
@staticmethod
def __init__(
    out self,
    start: Float64,
    end: Float64,
    duration: Float64,
    curve: Easing = Easing.LINEAR,
    clock: Clock = Clock.SCALED,
)
```

A tween from `start` to `end` over `duration` seconds, timed by `clock`.

```mojo
@staticmethod
def __init__(
    out self,
    duration: Float64,
    curve: Easing = Easing.LINEAR,
    clock: Clock = Clock.SCALED,
)
```

A tween from 0 to 1 -- the fraction `Vector.lerp` and `Color.lerp` take, and the form to reach for when animating anything that is not a plain number.

## Methods

### `value`

```mojo
def value(self) -> Float64
```

The eased value, between `start` and `end`.

### `progress`

```mojo
def progress(self) -> Float64
```

How far through the duration, 0 to 1, *before* easing.

The raw time fraction, so it is what a progress bar wants to render --
and what `value` is derived from. While ping-ponging it runs back down
to 0.

### `play`

```mojo
def play(mut self)
```

Run once from the start, holding `end` at the finish.

### `loop`

```mojo
def loop(mut self)
```

Run from the start, snapping back and repeating forever.

The snap is visible whenever `start` and `end` differ, which is what
`ping_pong` exists to avoid -- reach for this only when the value wraps
naturally, like a rotation through a full turn.

### `ping_pong`

```mojo
def ping_pong(mut self)
```

Run to `end`, back to `start`, forever -- the usual way to loop a tween, since it never snaps.

`progress` runs back down on the return leg, so the easing curve is
travelled backwards too and a `Easing.OUT_CUBIC` pulse decelerates into
both ends rather than into one.

### `pause`

```mojo
def pause(mut self)
```

Freeze at the current value. `resume` continues from here.

### `resume`

```mojo
def resume(mut self)
```

Continue a paused tween without rewinding. A stopped one starts from the beginning; a finished `play` stays finished.

### `stop`

```mojo
def stop(mut self)
```

Halt and rewind, putting `value` back to `start`.

### `is_playing`

```mojo
def is_playing(self) -> Bool
```

True while the playhead is advancing -- false when stopped, paused or finished.

### `is_finished`

```mojo
def is_finished(self) -> Bool
```

True once a `play` reached `end`. Never true for `loop` or `ping_pong`, which have no end to reach.
