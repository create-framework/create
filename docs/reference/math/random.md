# Random

```mojo
struct Random
```

A seeded pseudo-random generator: `.float()`, `.int()`, `.bool()`.

`Random()` seeds itself from the clock and `Random(seed)` takes one, which
is the difference that matters: a seeded generator replays the same
sequence every run, so a procedurally generated level or a particle burst
can be reproduced exactly while it is being tuned.

xoroshiro128++ — fast and well-distributed, not cryptographic. Don't render
keys or tokens from it.

Implements `Deinitable`, `Movable`.

## Constructors

```mojo
@staticmethod
def __init__(out self)
@staticmethod
def __init__(out self, seed: UInt64)
```

## Methods

### `float`

```mojo
def float(mut self) -> Float64
```

A number in `[0.0, 1.0)` — 1.0 itself is never returned.

```mojo
def float(mut self, low: Float64, high: Float64) -> Float64
```

A number in `[low, high)`.

### `int`

```mojo
def int(mut self, low: Int, high: Int) -> Int
```

A whole number in `[low, high)` — `high` is excluded, so `r.int(0, len(items))` indexes a list without going off the end.

### `bool`

```mojo
def bool(mut self) -> Bool
```

A coin flip — `True` half the time.
