# Tweens

A tween moves a number from one value to another over a set time: a menu sliding in from the edge of
the screen, a coin fading out once collected, a button growing slightly when the pointer is over it.
The name comes from animation, where the frames *in between* two key poses are called in-betweens.
This page explains how to build a tween, play it and use it to move things that aren't plain
numbers.

## Building and playing a tween

`Tween(start, end, duration, curve)` moves from `start` to `end` over `duration` seconds, shaped by
an easing curve. A tween does nothing until it is played, and `tween.value()` is where it is now:

```mojo
# In `create`, building the `slide` field:
var slide = Tween(-300, 0, 0.5, Easing.OUT_BACK)  # from -300 to 0 over half a second

# In `update`:
if context.keyboard.pressed(Key.SPACE):
    self.slide.play()
canvas.rectangle((self.slide.value(), 0), 100, 100)
```

The **easing curve** decides how the value travels between its two ends: at an even speed
(`Easing.LINEAR`, the default), starting slowly and speeding up, slowing down at the end, or
overshooting and settling back, as `OUT_BACK` does above. The curves, and what each one looks like,
are explained in [Easing](../math/easing.md).

## Controlling a tween

| Call | What it does |
|---|---|
| `play()` | Runs once from the start, and holds the end value when it gets there |
| `loop()` | Runs from the start over and over, jumping back to the start each time |
| `ping_pong()` | Runs to the end, back to the start, and so on forever |
| `pause()` | Freezes where it is |
| `resume()` | Continues from where it was paused |
| `stop()` | Stops and rewinds, so `value()` is the start value again |

`play`, `loop` and `ping_pong` always start from the beginning, so call them once, when the tween
should start, such as on a key press. Called every frame, they would keep it stuck at its start.

`loop` jumps back to the start each time round. The jump shows, unless the value wraps round
naturally, as an angle making full turns does. To go back and forth smoothly, such as a gently
pulsing glow, use `ping_pong`.

Reading a tween back:

- `value()` is the current value, eased, between `start` and `end`.
- `progress()` is how far through its duration it is, from 0 to 1, before easing. It is what a
  progress bar should show.
- `is_playing()` is whether it is moving right now, and `is_finished()` whether a `play` has reached
  its end. A looping tween never finishes.

## Tweening other things

`Tween(duration, curve)`, given only a duration, runs from 0 to 1. That is the fraction the `lerp`
methods take, so one tween can move a position, a colour or anything else that can be mixed:

```mojo
# In `create`:
var slide = Tween(0.3, Easing.OUT_CUBIC)

# In `update`: move from one point to another, and fade between two colours.
var position = self.from_position.lerp(self.to_position, self.slide.value())
canvas.fill(Color.RED.lerp(Color.BLUE, self.slide.value()))
```

What `lerp` does, and why it is so useful, is explained in
[Interpolation](../math/interpolation.md).

## Tweens and time

Nothing needs to update a tween each frame. It remembers when it was started and works out its value
from the run's clock whenever it is asked. So it follows the run's time: it slows down with
`context.time_scale` and stops while `context.time_paused` is set. A tween that must keep moving
while the game is paused, such as one in the pause menu itself, is built on real time instead, with
`clock=Clock.REAL` (see [Slowing and pausing time](time.md#slowing-and-pausing-time)).

Each thing being animated owns its own `Tween`, kept as a field. Tweens are cheap: a whole tween is
a few numbers. Animating a sprite through the frames of a sprite sheet is a different job, done by
an `Animator` (see [Animations](animations.md)).
