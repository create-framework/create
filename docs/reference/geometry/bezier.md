# Bezier

```mojo
struct Bezier
```

A cubic Bézier curve from `start` to `end`, shaped by `control1` and `control2`: `at`, `tangent`, `split`, `bounds`, `flatten`, `beziers`, `closest_point`, `intersects`, `translate`.

The curve passes through `start` and `end` only; the controls pull it
towards themselves and set the direction it leaves `start`
(`control1 - start`) and arrives at `end` (`end - control2`). It is the
curve SVG paths, fonts and vector editors use. For a smooth curve through
given points instead, see `Spline`.

Like `Line`, a curve has no interior and is not a region: there is no
`area`, `contains` or `overlaps` for it.

`t` runs from 0 at `start` to 1 at `end`, but it is not proportional to
distance along the curve — equal steps in `t` bunch up where the
controls do.

Implements `Copyable`, `Curve`, `Deinitable`, `Drawable`, `Equatable`, `ImplicitlyCopyable`, `Movable`, `Shape`, `Writable`.

## Fields

- `start: Point2D`
- `control1: Point2D`
- `control2: Point2D`
- `end: Point2D`

## Constructors

```mojo
@staticmethod
def __init__(
    out self,
    start: Point2D,
    control1: Point2D,
    control2: Point2D,
    end: Point2D,
)
```

## Methods

### `draw_to`

```mojo
def draw_to[T: DrawTarget](self, mut target: T)
```

### `at`

```mojo
def at(self, t: Float64) -> Point2D
```

The point at parameter `t`. Not clamped: outside 0..1 the cubic continues past its endpoints, as `lerp` extrapolates.

### `tangent`

```mojo
def tangent(self, t: Float64) -> Vector2D
```

The derivative at `t`: the direction of travel, with a magnitude that is the curve's speed per unit of `t`. Not normalised — it is zero where the curve stops, e.g. at a cusp or where a control sits on its endpoint.

### `closest_point`

```mojo
def closest_point(self, p: Point2D) -> Point2D
```

The point on the curve nearest `p`.

Samples the curve at even steps in `t`, then refines every sample
nearer than its neighbours with Newton's method on the distance's
derivative, kept within the curve, and keeps the nearest result. Exact to
rounding for any curve that fits on a screen, though a search, not
a formula.

### `intersects`

```mojo
def intersects(self, p: Point2D) -> Bool
def intersects(self, l: Line) -> Bool
def intersects(self, a: Arc) -> Bool
def intersects(self, other: Self) -> Bool
def intersects(self, s: Spline) -> Bool
def intersects(self, c: Circle) -> Bool
def intersects(self, c: Capsule) -> Bool
def intersects(self, e: Ellipse) -> Bool
def intersects(self, r: Rectangle) -> Bool
def intersects(self, t: Triangle) -> Bool
def intersects(self, s: Sector) -> Bool
def intersects(self, p: Polygon) -> Bool
```

### `split`

```mojo
def split(self, t: Float64) -> Tuple[Self, Self]
```

The curve cut at `t` into two, together tracing exactly the original: the first runs `start` to `at(t)`, the second `at(t)` to `end` (de Casteljau).

### `bounds`

```mojo
def bounds(self) -> Rectangle
```

The tightest axis-aligned rectangle around the curve — around the curve itself, not its control points, which usually reach further.

### `flatten`

```mojo
def flatten(self, tolerance: Float64) -> List[Point2D]
```

Points along the curve, from `start` to `end` inclusive, such that the straight segments between them stray from the curve by at most `tolerance`.

The points are evenly spaced in `t`, with the count from Wang's
formula, and capped at 1024 segments. A curve collapsed to one point
still gives two points.

### `beziers`

```mojo
def beziers(self) -> List[Self]
```

Itself, alone: the form `Arc.beziers`, `Line.beziers` and `Spline.beziers` share, so every curve converts the same way.

### `length`

```mojo
def length(self) -> Float64
```

The distance along the curve from `start` to `end`.

Gauss–Legendre quadrature (8 points on each of 16 equal steps in
`t`) of the curve's speed — accurate to far below a pixel for any
curve that fits on a screen, but an approximation, not exact.

### `at_distance`

```mojo
def at_distance(self, distance: Float64) -> Point2D
```

The point `distance` along the curve from `start`, clamped to the curve's ends.

Unlike `at`, equal steps in `distance` are equal steps along the
curve, so this is what moves something along it at a steady speed.
Each call inverts `length` numerically; sample once per frame per
entity, not in a tight loop.

### `translate`

```mojo
def translate(self, delta: Vector2D) -> Self
```

## Special methods

### `__eq__`

```mojo
def __eq__(self, other: Self) -> Bool
```

### `__ne__`

```mojo
def __ne__(self, other: Self) -> Bool
```
