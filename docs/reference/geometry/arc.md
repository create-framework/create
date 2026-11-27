# Arc

```mojo
struct Arc
```

A circular arc: part of the circle around `position` with `radius`, from `start_angle` round by `sweep_angle`. `end_angle`, `at`, `tangent`, `length`, `at_distance`, `split`, `bounds`, `flatten`, `beziers`, `closest_point`, `intersects`, `move_to`, `translate`.

Angles are radians, counted counter-clockwise from the +x axis: y is up,
so this is the direction `rotate` turns. The sweep is signed (positive
runs counter-clockwise, negative clockwise), so every arc has one
spelling and reversing one is negating its sweep. A sweep of a full turn
(`TAU`) or more is the whole circle. The fields keep what was given; the
methods read the sweep clamped to a turn.

Like `Line` and `Bezier`, an arc is a curve with no interior: there is
no `area`, `contains` or `overlaps` for it. `position` is the circle's
centre, which the arc passes through only when `radius` is zero, and
`move_to` moves that centre. A zero `radius` or sweep collapses the arc to a
point.

Implements `Copyable`, `Curve`, `Deinitable`, `Equatable`, `Geometry`, `ImplicitlyCopyable`, `Movable`, `Writable`.

## Fields

- `position: Point`
- `radius: Float64`
- `start_angle: Float64`
- `sweep_angle: Float64`

## Constructors

```mojo
@staticmethod
def __init__(
    out self,
    position: Point,
    radius: Float64,
    start_angle: Float64,
    sweep_angle: Float64,
)
@staticmethod
def __init__(
    out self,
    position: Point,
    radius: Int,
    start_angle: Float64,
    sweep_angle: Float64,
)
```

## Methods

### `end_angle`

```mojo
def end_angle(self) -> Float64
```

`start_angle + sweep_angle`: where the arc ends, as an angle.

### `at`

```mojo
def at(self, t: Float64) -> Point
```

The point at parameter `t`: 0 at the start, 1 at the end, and proportional to distance along the arc in between. Not clamped: outside 0..1 it carries on round the circle.

### `tangent`

```mojo
def tangent(self, t: Float64) -> Vector
```

The derivative at `t`: the direction of travel, with a magnitude that is the arc's length (the speed per unit of `t`, the same everywhere). Zero for a collapsed arc.

### `length`

```mojo
def length(self) -> Float64
```

The distance along the arc from start to end. Exact.

### `at_distance`

```mojo
def at_distance(self, distance: Float64) -> Point
```

The point `distance` along the arc from its start, clamped to the arc's ends. An arc has constant speed, so this is `at` with `t` scaled: exact, and as cheap as `at`.

### `split`

```mojo
def split(self, t: Float64) -> Tuple[Self, Self]
```

The arc cut at `t` into two on the same circle, together tracing exactly the original: the first runs from the start to `at(t)`, the second from `at(t)` to the end. A sweep past a full turn is clamped to one first, as everywhere else.

### `bounds`

```mojo
def bounds(self) -> Rectangle
```

The tightest axis-aligned rectangle around the arc: its two ends, widened to each of the circle's four extremes the arc passes.

### `flatten`

```mojo
def flatten(self, tolerance: Float64) -> List[Point]
```

Points along the arc, from start to end inclusive, such that the straight segments between them stray from the arc by at most `tolerance`.

The points are evenly spaced, as few as the tolerance allows, and
capped at 1024 segments. A collapsed arc still gives two points.

### `beziers`

```mojo
def beziers(self) -> List[Bezier]
```

The arc as cubic Béziers, each ending where the next starts, in pieces of at most 45°. An approximation (no cubic is exactly a circle), but within about 4e-6 of the radius. A full circle ends exactly where it starts. A collapsed arc gives no curves.

### `closest_point`

```mojo
def closest_point(self, p: Point) -> Point
```

The point on the arc nearest `p`: straight out from the centre when `p` lies within the sweep, otherwise the nearer end. From the centre itself every point is as near, and the start is returned.

### `intersects`

```mojo
def intersects(self, p: Point) -> Bool
```

Whether `p` lies on it.

```mojo
def intersects(self, l: Line) -> Bool
def intersects(self, other: Self) -> Bool
def intersects(self, c: Circle) -> Bool
def intersects(self, c: Capsule) -> Bool
def intersects(self, e: Ellipse) -> Bool
def intersects(self, r: Rectangle) -> Bool
def intersects(self, t: Triangle) -> Bool
def intersects(self, s: Sector) -> Bool
def intersects(self, p: Polygon) -> Bool
def intersects(self, b: Bezier) -> Bool
def intersects(self, s: Spline) -> Bool
```

Whether it crosses or touches the other curve or shape: shares a point with it, a shape's inside included.

### `move_to`

```mojo
def move_to(self, position: Point) -> Self
```

It moved so its `position` is at `position`; this one is unchanged.

### `translate`

```mojo
def translate(self, delta: Vector) -> Self
```

It moved by `delta`; this one is unchanged.

## Special methods

### `__eq__`

```mojo
def __eq__(self, other: Self) -> Bool
```

### `__ne__`

```mojo
def __ne__(self, other: Self) -> Bool
```
