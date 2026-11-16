# Time

The run's clock and how to move things by it, frames and the frame rate, slowing and pausing
time, and the computer's wall clock. Easing and tweens are in
[Animation](animation.md#easing-and-tweens).

## Moving by time

**Time is in seconds.** `context.time.delta` is the seconds since the last frame; move things by
it, rather than by a fixed step a frame, and they move at the same speed at any frame rate:

```mojo
# In `update`:
self.position = self.position + self.velocity * context.time.delta  # velocity in units a second
```

`context.time.elapsed` is the seconds since the run started, for what is a function of time
rather than a step, such as `rotate(context.time.elapsed)`.

## The run's clock

`context.time` is ticked by the loop before each `update`. It is zero in `create`, and headless
runs advance it a fixed 16 ms a frame, so a test sees the same times every run. It has two clocks
side by side:

| Field | What it is |
|---|---|
| `delta`, `elapsed` | **Scaled time**: the program's, which the time scale slows and a pause stops (below) |
| `real_delta`, `real_elapsed` | **Real time**: the seconds that actually passed, whatever the scale or pause |

Every `Animator` and `Tween` keeps time by `elapsed`. Nothing ticks one: each works out where it
is from the run's clock whenever it is asked.

## Frames

- `context.frame_count()` is the frames drawn so far: 1 in `create`, 2 in the first `update`.
- `context.frame_rate()` is the current frames per second, from the last frame's `real_delta`.
  It is 0 on the first frame, which has no frame before it to measure.
- `context.max_frame_rate(30)` caps the loop at 30 frames a second, and `0`, the default, lifts
  the cap. A cap tighter than the display's own pacing slows the loop; a looser one does
  nothing. It applies when `update` returns, and headless runs ignore it.

## Slowing and pausing time

`delta` and `elapsed` are **scaled time**: `context.time_scale(0.5)` runs them at half speed,
and `context.time_paused(True)` stops them, `delta` reading zero until it is unpaused. What
moves by `delta`, and every animator and tween, slows and stops together, so slow motion and a
pause screen are one call each:

```mojo
# In `update`:
if context.keyboard.pressed(Key.P):
    context.time_paused(not context.time_paused())
self.position = self.position + self.velocity * context.time.delta  # holds while paused
```

The pause is separate from the scale, so unpausing returns to the scale that was set, slow
motion included. Both apply from the next frame. **Real time**, `context.time.real_delta` and
`real_elapsed`, ignores both, for what must keep moving while the program's time stands still.
`context.frame_rate()`, recordings and audio run on real time.

An animator or tween keeps time by scaled time unless it is built on real time, as a pause
menu's own animations must be to keep moving while the game behind them is paused:

```mojo
# In `create`:
var blink = Tween(0.6, Easing.IN_OUT_SINE, clock=Clock.REAL)
var cursor = Animator(cursor_animation, clock=Clock.REAL)
```

A `Tween` given only a duration, as `blink` is, runs from 0 to 1.

## The wall clock

`DateTime.now()` reads the computer's local date and time into consistent fields: `year`,
`month`, `day`, `hour`, `minute`, `second` and `millisecond`. Take one reading a frame rather
than calling it for each field, or the fields can straddle a second:

```mojo
# In `update`:
var now = DateTime.now()
canvas.text(String(now.hour) + " o'clock", (0, 0))
```

It has nothing to do with the run's clock: pausing or scaling time doesn't change it. See
[examples/clock](../../examples/clock/main.mojo).
