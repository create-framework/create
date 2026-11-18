# Noise

Random numbers jump: each one has nothing to do with the last. That is right for scattering stars,
but wrong for the outline of a range of hills, the drift of a cloud or the wobble of a hand-drawn
line, where each value should be close to its neighbours. **Noise** gives values that vary randomly
but smoothly. This page explains how to use it, and how to shape it.

## Random numbers and noise side by side

Stars scattered by a `Random`, and hills drawn from `Noise`, scrolling by:

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

The hills are a row of thin vertical lines, each as tall as the noise at its x position. Because
nearby positions give nearby values, the tops of the lines form a smooth, rolling outline. Had each
height come from a `Random`, the outline would be a jagged mess.

## Reading noise

Think of noise as a landscape that already exists, spread out in every direction: `at(...)` reads
the height of the landscape at a point. It gives a value from 0 to 1, and it comes in three forms:

- **`noise.at(x)`** reads along a line: a value that wanders smoothly as `x` moves. Pass the time as
  `x` for something that drifts over time, such as a flickering light's brightness.
- **`noise.at(position)`** reads over a flat plane, for terrain, a texture or a direction that
  changes from place to place.
- **`noise.at(position, time)`** reads the plane as it slowly changes over time, for clouds that
  shift and churn.

The same input always gives the same value, so reading noise changes nothing, and asking twice gives
the same answer. That also means a `Noise` can be copied freely, and each copy is the same
landscape.

To use the value for something other than 0 to 1, scale it: `noise.at(x) * 300` is a height from 0
to 300, and `lerp(-20, 20, noise.at(x))` an offset from -20 to 20 (see
[Interpolation](interpolation.md)).

## Seeds

Like a `Random`, a `Noise` is built from a **seed**, a number that decides which landscape you get.
`Noise(seed)` gives the same landscape every time for the same seed, and `Noise()` takes its seed
from the clock, so the landscape differs every time the program runs.

## Shaping noise

**`feature_size`** is the size of the landscape's features: roughly how far apart its hills are, in
the units you pass to `at`. `Noise(feature_size=120)` makes hills about 120 units across. A larger
feature size gives broad, gentle shapes; a smaller one, busy, tightly packed ones.

`feature_size` stretches only positions, not time. To make `at(position, time)` change faster or
more slowly, scale the time you pass in: `noise.at(position, context.time.elapsed * 0.3)` changes at
less than a third of the speed.

**Detail.** Noise is built in layers, called **octaves**: a broad first layer for the overall shape,
then layers of finer and finer detail on top, each fainter than the last, as a coastline has bays,
then coves within the bays, then rocks within the coves.

- `octaves` is how many layers there are, 4 by default. One octave gives smooth, blobby shapes, and
  more add finer detail.
- `falloff` is how strong each layer is compared with the one before it, 0.5 by default, so each
  layer is half as strong as the last. A larger falloff makes the detail rougher and more prominent.

```mojo
var smooth = Noise(7, octaves=1, feature_size=200)  # gentle, rounded hills
var rocky = Noise(7, octaves=6, falloff=0.6, feature_size=200)  # craggy, detailed hills
```

Adding the layers together evens them out, so noise values gather around 0.5 and seldom reach 0
or 1. For more contrast, stretch them with `smoothstep`, such as `smoothstep(0.3, 0.7, value)`,
which spreads the values between 0.3 and 0.7 across the whole range from 0 to 1 (see
[Interpolation](interpolation.md#smoothstep)).
