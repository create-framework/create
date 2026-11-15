# Randomness and noise

Random numbers and noise. Common `std.math` functions
(`sqrt`, `sin`, `cos`, `atan2`, `clamp`, `floor`, …) come with `from create import *`, as in
Processing. Points and vectors are in [Coordinates](coordinates.md#points-and-vectors), and easing curves in
[Animation](animation.md#easing-and-tweens).

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
