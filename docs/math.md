# Randomness and easing

Random numbers and noise, and easing and tweens. Common `std.math` functions
(`sqrt`, `sin`, `cos`, `atan2`, `clamp`, `floor`, …) come with `from create import *`, as in
Processing. Points and vectors are in [Coordinates](coordinates.md#points-and-vectors).

## Random numbers and noise

Stars scattered at random once, and hills drawn from noise, scrolling by:

```mojo
from create import *


@fieldwise_init
struct Hills(Program):
    var stars: List[Point2D]
    var noise: Noise

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> Hills:
        var random = Random(7)
        var stars = List[Point2D]()
        for _ in range(60):
            stars.append(Point2D(random.float(-640, 640), random.float(0, 360)))
        return Hills(stars^, Noise(7, feature_size=300))

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        canvas.background(Color(20, 24, 48))
        canvas.stroke_enabled(False)
        canvas.fill(Color.WHITE)
        for star in self.stars:
            canvas.circle(star, 2)
        var scroll = context.time.elapsed * 100
        canvas.stroke(Color(60, 140, 80), 6)
        var x = canvas.left()
        while x < canvas.right():
            var height = self.noise.at(Point2D(x + scroll, 0)) * 300
            canvas.line((x, canvas.bottom()), (x, canvas.bottom() + height))
            x += 6


def main() raises:
    run[Hills]("Hills")
```

`Random` and `Noise` are both seeded, and both give values in `[0, 1]` by default, but they answer
different questions:

```mojo
# In `create`, building the `random` and `noise` fields:
var random = Random(42)  # Random() seeds from the clock
var noise = Noise(42, feature_size=200)

# In `update`:
var x = self.random.float(-100, 100)  # a fresh, independent sample each call
var height = self.noise.at(Point2D(x, 0))  # the same input always gives the same value
```

- **`Random`** is stateful (`mut`, `Movable`): each call is an independent sample. `float()`,
  `float(low, high)`, `int(low, high)` and `bool()`.
- **`Noise`** is immutable (`Copyable`): `at(...)` is a pure function of its input, and nearby
  inputs give nearby values, for terrain, clouds or wobble. `feature_size` is roughly the
  distance between bumps. It applies to position only, so to make `at(position, time)` change
  faster or slower, scale the time you pass in.
- Noise is several layers of detail (`octaves`, 4 by default) added together, so its values
  cluster around 0.5 rather than spreading evenly; stretch them with `smoothstep` for contrast.

## Easing and tweens

An **`Easing`** is a curve that reshapes progress from 0 to 1, so motion can start slowly, end
with a bounce and so on: `ease(Easing.OUT_CUBIC, t)`. A **`Tween`** runs that progress over a
duration in seconds, from a start value to an end value:

```mojo
# In `create`, building the `slide` field:
var slide = Tween(-300, 0, 0.5, Easing.OUT_BACK)  # from -300 to 0 over half a second

# In `update`:
if context.keyboard.pressed(Key.SPACE):
    self.slide.play()
canvas.rectangle((self.slide.value(), 0), 100, 100)
```

Nothing ticks a tween: it remembers when it was started and works its value out from
`context.time` whenever it is asked, so it slows and pauses with the run's time unless built on
real time (see [Slowing and pausing time](time.md#slowing-and-pausing-time)). Each entity owns
its own `Tween`. Frame-by-frame animation, a sprite sheet, is an `Animation` and an `Animator`,
not a tween (see [Sprite animation](images.md#sprite-animation)).

