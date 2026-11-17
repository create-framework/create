# Interpolation

To interpolate is to find a value between two others: the colour halfway between red and blue, the
position a third of the way along a path, the volume a quarter of the way from silent to loud. It
is one of the most useful ideas in creative coding, because almost every smooth change, from a
fade to a slide to a health bar, comes down to it. This page explains `lerp` and its relatives,
which convert between ranges of numbers, and the small helpers that keep numbers within bounds.

## `lerp`

`lerp(a, b, t)` is the value a fraction `t` of the way from `a` to `b`. The name is short for
*linear interpolation*:

- `t = 0` gives `a`;
- `t = 1` gives `b`;
- `t = 0.5` gives the value halfway between them;
- `t = 0.25` gives the value a quarter of the way from `a` to `b`.

```mojo
lerp(0, 100, 0.25)  # 25
lerp(10, 20, 0.5)  # 15
lerp(100, 0, 0.25)  # 75: going down works the same way
```

Points, vectors and colours have `lerp` too, as a method, so the same idea moves a position or
mixes a colour:

```mojo
var midpoint = a.lerp(b, 0.5)  # the point halfway between a and b
var orange = Color.RED.lerp(Color.YELLOW, 0.5)  # halfway between red and yellow
```

**Smooth movement.** Feeding `lerp` a `t` that grows from 0 to 1 over time moves a value smoothly
from one end to the other. A [Tween](../motion/tweens.md) does exactly that, and its value is the
`t` to pass:

```mojo
# In `update`, with a `slide: Tween` running from 0 to 1:
var position = self.start.lerp(self.end, self.slide.value())
```

**Following.** Moving a value a small fraction of the way towards a target every frame makes it
follow the target, quickly when far behind and gently as it closes in. It is a simple way to make
a camera trail behind the player:

```mojo
# In `update`: close 10% of the gap to the player every frame.
self.camera.position = self.camera.position.lerp(self.player, 0.1)
```

That version follows faster at a higher frame rate, since it takes more steps a second. To make
it the same at every frame rate, base the fraction on the time that passed:
`1 - exp(-5 * context.time.delta)` closes the gap at the same rate however often it runs.

`lerp` for numbers doesn't stop at 0 and 1: a `t` of 2 goes as far past `b` again, and -1 as far
before `a`. That is sometimes what you want, but if not, keep `t` in range with `clamp` (below).
A colour's `lerp` always keeps `t` between 0 and 1.

## `inverse_lerp`

`inverse_lerp(value, low, high)` asks the opposite question: how far between `low` and `high` is
`value`, as a fraction? It is 0 at `low`, 1 at `high` and 0.5 halfway:

```mojo
inverse_lerp(25, 0, 100)  # 0.25
inverse_lerp(15, 10, 20)  # 0.5
```

It turns a value into a fraction, ready for `lerp`, for a colour, or for a progress bar:

```mojo
# In `update`: a health bar, its width a fraction of the full 200.
var fraction = inverse_lerp(self.health, 0, self.max_health)
canvas.rectangle((0, 300), 200 * fraction, 20)
```

## `map`

`map(value, in_low, in_high, out_low, out_high)` converts a value from one range to another: a
value at `in_low` becomes `out_low`, a value at `in_high` becomes `out_high`, and everything in
between is spread proportionally. It is `inverse_lerp` and `lerp` in one step:

```mojo
# In `update`: the mouse's x position, from the left edge to the right one, sets
# the volume from 0 to 1.
var volume = map(context.mouse.position.x, canvas.left(), canvas.right(), 0, 1)
```

Like `lerp`, `map` doesn't stop at the ends of the range: a value beyond `in_high` maps beyond
`out_high`.

## `clamp`

`clamp(value, low, high)` keeps a value within bounds: it gives `low` if the value is below it,
`high` if above it, and the value itself otherwise.

```mojo
self.health = clamp(self.health, 0, self.max_health)  # never below 0 or above the maximum
var volume = clamp(map(x, canvas.left(), canvas.right(), 0, 1), 0, 1)  # map, kept in range
```

## `smoothstep`

`smoothstep(edge0, edge1, x)` is like `inverse_lerp`, giving 0 at `edge0` and 1 at `edge1`, with two
differences: it stays at 0 below `edge0` and at 1 above `edge1`, and it eases in and out at the
ends rather than changing at a constant rate. So a change driven by it starts gently, speeds up in
the middle and settles gently, with no sudden start or stop:

```mojo
# In `update`: a hint that fades in as the player walks from 300 to 100 units
# from a door.
var distance = self.player.distance(self.door)
var opacity = smoothstep(300, 100, distance)
```

It is also useful for adding contrast to values that bunch together in the middle, such as
[noise](noise.md): `smoothstep(0.3, 0.7, value)` spreads the values from 0.3 to 0.7 across the
whole range from 0 to 1. For more ways to shape a change from 0 to 1, see [Easing](easing.md).

## Other helpers

A few more small functions come up often enough to have names:

| Function | What it does |
|---|---|
| `wrap(value, period)` | Wraps a value round into the range from 0 up to `period`, as a clock's hand wraps round. `wrap(370, 360)` is 10, and `wrap(-10, 360)` is 350. Useful for angles and for scrolling backgrounds that repeat |
| `fractional_part(x)` | The part after the decimal point: `fractional_part(2.75)` is 0.75. For a negative number it counts up from the whole number below, so `fractional_part(-0.25)` is 0.75 |
| `sign(x)` | 1 for a positive number, -1 for a negative one, and 0 for zero |
| `degrees(radians)`, `radians(degrees)` | Convert an angle between radians and degrees (see [Angles](angles.md)) |

Create also includes the common functions from Mojo's standard library, so they need no import of
their own: `sqrt`, `floor`, `ceil`, `exp`, `log`, `log2`, `sin`, `cos`, `tan`, `asin`, `acos`,
`atan2`, and `isnan`, `isinf` and `isfinite` for checking that a calculation gave a sensible
number. `abs`, `min`, `max`, `round` and `pow` are part of Mojo itself, and always available.
