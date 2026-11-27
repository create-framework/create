# Noise

```mojo
struct Noise
```

Smooth pseudo-random values: `.at(x)`, `.at(position)` and `.at(position, time)`, each in `[0.0, 1.0]`.

Where `Random` gives independent samples that jump from one call to the
next, `Noise` is a field: nearby inputs give nearby values, so a terrain
height, a wandering position or a flow-field angle drifts instead of
jittering. The range is `Random.float()`'s, so it swaps in wherever the
jitter should be smooth; `lerp(-a, a, n)` makes it signed.

`Noise()` seeds itself from the clock and `Noise(seed)` takes one; the same
seed always gives the same field. Nothing changes after construction, so
`.at` reads rather than advances, and a copy is the same field.

`feature_size` is the distance, in the units passed to `.at`, over which
the field goes from one value to an unrelated one: hills about 120 units
across are `Noise(feature_size=120)`. It divides `x` and `position` but
not `time`, so an animation's rate is set at the call,
`noise.at(position, time=t * 0.3)`, independently of the spatial scale.

`octaves` layers the field over itself at doubling frequencies, each
layer's weight `falloff` times the last: one octave is plain, blobby
Perlin; the default four at 0.5 add the finer detail of a coastline or a
cloud edge. The layers are averaged by weight, so the range stays
`[0, 1]`.

Improved Perlin noise (2002). Its value at a whole-number lattice point,
after dividing by `feature_size`, is exactly 0.5.

Implements `Copyable`, `Deinitable`, `Movable`, `Writable`.

## Constructors

```mojo
@staticmethod
def __init__(
    out self,
    *,
    octaves: Int = Int(4),
    falloff: Number = SIMD(0.5),
    feature_size: Number = SIMD(1),
)
@staticmethod
def __init__(
    out self,
    seed: UInt64,
    *,
    octaves: Int = Int(4),
    falloff: Number = SIMD(0.5),
    feature_size: Number = SIMD(1),
)
```

## Methods

### `at`

```mojo
def at(self, x: Number) -> Float64
```

The field along a line: a value that wanders smoothly as `x` (a time, say) moves.

```mojo
def at(self, position: Point) -> Float64
```

The field over the plane: terrain, texture, a flow-field angle.

```mojo
def at(self, position: Point, time: Number) -> Float64
```

The plane field, animated: it evolves smoothly as `time` moves. `time` is not divided by `feature_size`; scale it at the call.
