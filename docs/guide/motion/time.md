# Time

Anything that moves on the screen moves over time, and a program needs to know how much time has
passed to move it at the right speed. This page explains the run's clock and how to move things by
it, frames and the frame rate, slowing and pausing time, and the computer's own clock, for showing
the date and time. Moving a value smoothly from one number to another is in [Tweens](tweens.md).

## Moving by time

How many frames a program draws each second, its **frame rate**, depends on the computer and the
display: often 60, but 30 on a slow machine and 144 on a fast display. Something moved 5 units every
frame would therefore move more than twice as fast on one computer as on another.

So **move things by time, in seconds**, rather than by a fixed step each frame. `context.time.delta`
is the seconds since the last frame. Multiplying a speed, in units a second, by it gives how far to
move this frame, so things move at the same speed at any frame rate:

```mojo
# In `update`:
self.position = self.position + self.velocity * context.time.delta  # velocity in units a second
```

`context.time.elapsed` is the seconds since the run started. Use it for what is worked out afresh
from the time every frame rather than moved a step at a time, such as an angle that keeps turning:
`canvas.rotate(context.time.elapsed)`.

## The run's clock

The loop advances `context.time` before each `update`. It is zero in `create`, and headless runs
advance it a fixed 16 ms a frame, so a test sees the same times every run. It has two clocks side by
side:

| Field | What it is |
|---|---|
| `delta`, `elapsed` | **Scaled time**: the program's, which the time scale slows and a pause stops (below) |
| `real_delta`, `real_elapsed` | **Real time**: the seconds that actually passed, whatever the scale or pause |

Every `Animator` and `Tween` keeps time by `elapsed`, unless it is built on real time (below).
Nothing needs to update one each frame: each works out where it is from the run's clock whenever it
is asked.

## Frames

- `context.frame_count()` is the frames drawn so far: 1 in `create`, 2 in the first `update`.
- `context.frame_rate()` is the current frames per second, from the last frame's `real_delta`. It is
  0 on the first frame, which has no frame before it to measure.
- `context.max_frame_rate(30)` limits the program to at most 30 frames a second, and `0`, the
  default, removes the limit. Most displays already hold a program to their own refresh rate, often
  60 frames a second, so a limit below that slows the program down to the limit, and one above it
  changes nothing. It applies when `update` returns, and headless runs ignore it.

## Slowing and pausing time

`delta` and `elapsed` are **scaled time**: `context.time_scale(0.5)` runs them at half speed, and
`context.time_paused(True)` stops them: `delta` reads zero until time is unpaused. What moves by
`delta`, and every animator and tween, slows and stops together, so slow motion and a pause screen
are one call each:

```mojo
# In `update`:
if context.keyboard.pressed(Key.P):
    context.time_paused(not context.time_paused())
self.position = self.position + self.velocity * context.time.delta  # holds while paused
```

The pause is separate from the scale, so unpausing returns to the scale that was set, slow motion
included. Both apply from the next frame. **Real time**, `context.time.real_delta` and
`real_elapsed`, ignores both, for what must keep moving while the program's time stands still.
`context.frame_rate()`, recordings and audio run on real time.

An animator or tween keeps time by scaled time unless it is built on real time, as a pause menu's
own animations must be to keep moving while the game behind them is paused:

```mojo
# In `create`:
var blink = Tween(0.6, Easing.IN_OUT_SINE, clock=Clock.REAL)
var cursor = Animator(cursor_animation, clock=Clock.REAL)
```

A `Tween` given only a duration, as `blink` is, runs from 0 to 1.

## The date and time

`DateTime.now()` reads the computer's local date and time, as of the moment it is called, into the
fields `year`, `month`, `day`, `hour`, `minute`, `second` and `millisecond`. Call it once a frame
and read every field from that one reading. Calling it again for each field could give fields from
either side of a change, such as a minute from just before the hour turns and an hour from just
after it:

```mojo
# In `update`:
var now = DateTime.now()
canvas.text(String(now.hour) + " o'clock", (0, 0))
```

It has nothing to do with the run's clock: pausing or scaling time doesn't change it. See
[examples/clock](../../../examples/clock/main.mojo).
