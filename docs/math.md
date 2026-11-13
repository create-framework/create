# Math, time and randomness

Points and vectors, random numbers and noise, easing and tweens, and the two clocks. Common
`std.math` functions (`sqrt`, `sin`, `cos`, `atan2`, `clamp`, `floor`, …) come with
`from create import *`, as in Processing.

## Points and vectors

Create has two types for a pair of numbers, chosen by role:

- A **location** is a `Point2D`: `canvas.circle(position, r)`, `context.mouse.position`.
- A **displacement** is a `Vector2D`: `translate(delta)`, a velocity.
- An **extent** is a scalar: `w`, `h`, `r`.

```mojo
# A fragment.
var position = Point2D(0, 0)
var velocity = Vector2D.from_angle(PI / 4, 100)  # 100 units a second, up and to the right
position = position + velocity * context.time.delta  # a point moved by a vector
var to_mouse = context.mouse.position - position  # point minus point is a vector
var speed = to_mouse.limit(300)  # at most 300 long
```

- Crossing between them is an explicit constructor, `Vector2D(p)` or `Point2D(v)`, never an
  implicit one.
- `Point2D` deliberately lacks `magnitude`, `normalize`, `dot`, scalar `*`, unary `-` and
  `Point2D + Point2D`: those mean nothing for a location.
- Only `Point2D` takes a bare tuple implicitly, so `(0, 0)` fills a `Point2D` parameter. A vector
  literal names its type (`p + Vector2D(1, 2)`), and `p - (1, 2)` is the displacement from
  `(1, 2)`, not a move.
- Named vectors are `comptime` constants: `Vector2D.ZERO`, `ONE`, `UP`, `DOWN`, `LEFT`, `RIGHT`
  (y is up, so `DOWN` is `(0, -1)`).
- Angles are radians counter-clockwise from +x: `Vector2D.from_angle(a, length)`, `v.angle()`,
  `v.rotate(a)`, with `v.with_length(l)` and `v.limit(max)` for speeds. Each returns a new
  vector, like `normalize`.

## Random numbers and noise

`Random` and `Noise` are both seeded, and both give values in `[0, 1]`, but they answer different
questions:

```mojo
# A fragment: both are fields, built in `create`.
var random = Random(42)  # Random() seeds from the clock
var noise = Noise(42, feature_size=200)

# In `update`:
var x = self.random.float(-100, 100)  # a fresh, independent sample each call
var height = self.noise.at(Point2D(x, 0))  # the same input always gives the same value
```

- **`Random`** is stateful (`mut`, `Movable`): each call is an independent sample. `float()`,
  `float(low, high)`, `int(low, high)` and `bool()`.
- **`Noise`** is immutable (`Copyable`): `at(...)` is a pure function of its input, and nearby
  inputs give nearby values, for terrain, clouds or wobble. `feature_size` divides space only;
  `at(position, time)` leaves `time` for the caller to scale.
- Averaged octaves cluster around 0.5; stretch with `smoothstep` for contrast.

## Easing and tweens

An **`Easing`** is a stateless curve over a 0-to-1 fraction: `ease(Easing.OUT_CUBIC, t)`. A
**`Tween`** walks that fraction over a duration:

```mojo
# A fragment: `slide` is a field, built in `create`.
var slide = Tween(-300, 0, 0.5, Easing.OUT_BACK)  # from -300 to 0 over half a second

# In `update`:
if context.keyboard.pressed(Key.SPACE):
    self.slide.play()
self.slide.update(context.time.delta)  # every frame, or it never moves
canvas.rectangle((self.slide.value(), 0), 100, 100)
```

Each entity owns its own `Tween`. Frame-by-frame animation, a sprite sheet, is
`Animation`/`Animator` (in `image`), not a tween.

## Time

There are two clocks:

- **`context.time`** is the run's clock: ticked by the loop, zero at the first frame, synthetic in
  headless runs. `delta` is the seconds since the last frame (move things by it), and `elapsed`
  the seconds since the run started; `delta_millis` and `elapsed_millis` are the same in whole
  milliseconds.
- **`DateTime.now()`** is the computer's local wall clock, read once into consistent fields
  (`year` … `millisecond`). Take one reading per frame rather than calling it per field.
