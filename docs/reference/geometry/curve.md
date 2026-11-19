# Curve

```mojo
trait Curve
```

A shape with no inside, traced from one end to the other: `Line`, `Arc`, `Bezier` and `Spline`. A straight line is a curve too, as in mathematics.

`t` runs from 0 at the start to 1 at the end; only on a `Line` and an
`Arc` is it proportional to distance, which `at_distance` always is.

Implements `Copyable`, `Deinitable`, `Drawable`, `Movable`, `Shape`.

## Methods

### `at`

```mojo
def at(self, t: Float64) -> Point
```

The point at parameter `t`.

### `tangent`

```mojo
def tangent(self, t: Float64) -> Vector
```

The derivative at `t`: the direction of travel, with the speed per unit of `t` as its magnitude.

### `length`

```mojo
def length(self) -> Float64
```

The distance along the curve from start to end.

### `at_distance`

```mojo
def at_distance(self, distance: Float64) -> Point
```

The point `distance` along the curve from its start, clamped to its ends.

### `flatten`

```mojo
def flatten(self, tolerance: Float64) -> List[Point]
```

Points along the curve, start to end, whose straight segments stray from it by at most `tolerance`.

### `beziers`

```mojo
def beziers(self) -> List[Bezier]
```

The curve as cubic Béziers, each ending where the next starts.
