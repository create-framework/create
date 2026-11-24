# Line

```mojo
struct Line
```

A line segment from `start` to `end`: `length`, `at`, `tangent`, `at_distance`, `split`, `midpoint`, `bounds`, `flatten`, `beziers`, `closest_point`, `intersects`, `move_to`, `translate`.

A `Curve`, like `Arc`, `Bezier` and `Spline`: a straight one, as in
mathematics, with `t` proportional to distance. It has no interior, so
unlike the `Shape`s it has no `center()`, `area()` or `overlaps`, and
is the *subject* of `l.intersects(x)` -- see the comment above
`intersects` for why that method exists only on curves.

`intersects` and `_point_on_segment`-based checks treat the endpoints
and any touching/collinear-overlapping point as inclusive. A
zero-length line (`start == end`) is a degenerate point segment:
`intersects` and `closest_point` remain exact for it (a point can
still "intersect" the collapsed line if it coincides with it).

Implements `Copyable`, `Curve`, `Deinitable`, `Drawable`, `Equatable`, `Geometry`, `ImplicitlyCopyable`, `Movable`, `Writable`, `_Collider`.

## Fields

- `start: Point`
- `end: Point`

## Constructors

```mojo
@staticmethod
def __init__(out self, start: Point, end: Point)
```

## Methods

### `length`

```mojo
def length(self) -> Float64
```

### `at`

```mojo
def at(self, t: Float64) -> Point
```

The point at parameter `t`: `start` at 0, `end` at 1, and proportional to distance in between. Not clamped: outside 0..1 it carries on along the line, as `lerp` extrapolates.

### `tangent`

```mojo
def tangent(self, t: Float64) -> Vector
```

The derivative at `t`: `end - start`, the same everywhere — the direction of travel, with the line's length as its magnitude. Zero for a zero-length line.

### `at_distance`

```mojo
def at_distance(self, distance: Float64) -> Point
```

The point `distance` along the line from `start`, clamped to the line's ends. Exact, and as cheap as `at`.

### `split`

```mojo
def split(self, t: Float64) -> Tuple[Self, Self]
```

The line cut at `t` into two, together tracing exactly the original: the first runs `start` to `at(t)`, the second `at(t)` to `end`.

### `bounds`

```mojo
def bounds(self) -> Rectangle
```

The tightest axis-aligned rectangle around the line: the box its two ends span, zero-width or zero-height when it is axis-aligned.

### `flatten`

```mojo
def flatten(self, tolerance: Float64) -> List[Point]
```

`start` and `end`: a line is already straight, whatever the tolerance.

### `beziers`

```mojo
def beziers(self) -> List[Bezier]
```

The line as one cubic Bézier, its controls at the thirds, so it traces the line exactly and at the same speed.

### `intersects`

```mojo
def intersects(self, other: Self) -> Bool
def intersects(self, p: Point) -> Bool
def intersects(self, a: Arc) -> Bool
def intersects(self, b: Bezier) -> Bool
def intersects(self, s: Spline) -> Bool
def intersects(self, s: Sector) -> Bool
def intersects(self, p: Polygon) -> Bool
def intersects(self, c: Circle) -> Bool
def intersects(self, c: Capsule) -> Bool
def intersects(self, e: Ellipse) -> Bool
def intersects(self, r: Rectangle) -> Bool
def intersects(self, t: Triangle) -> Bool
```

### `closest_point`

```mojo
def closest_point(self, p: Point) -> Point
```

### `midpoint`

```mojo
def midpoint(self) -> Point
```

### `draw_to`

```mojo
def draw_to[T: DrawTarget](self, mut target: T)
```

### `move_to`

```mojo
def move_to(self, position: Point) -> Self
```

### `translate`

```mojo
def translate(self, delta: Vector) -> Self
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
