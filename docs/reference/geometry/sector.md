# Sector

```mojo
struct Sector
```

A sector -- a slice of pie: the region between two radii of the circle around `position` with radius `radius`, from `start_angle` round by `sweep_angle`. `end_angle`, `center`, `area`, `arc`, `bounds`, `closest_point`, `contains`, `move_to`, `translate`.

The angles are an `Arc`'s: radians, counter-clockwise from the +x axis,
and a signed sweep, so a negative one runs clockwise and a full turn or
more is the whole circle. The fields keep what was given.

`center()` is `position`, the tip of the slice, as for `Circle`: not the
centroid. `contains` treats the boundary as inside, within the slack
`Arc.intersects` allows, so points found on the sector's own arc count;
`closest_point` returns the query point itself when it is inside. A sweep wider than a
half turn is not convex. A zero `radius` collapses the sector to its tip,
and a zero sweep to the one radius at `start_angle`. `radius` is assumed
non-negative.

`corner_radius` rounds the tip and both ends of the arc, as
`canvas.sector` draws them, and every test here sees the rounded shape.
An end rounds against the arc, tangent to it from inside. Each corner is
clamped to half of what lies beside it, as a polygon's is; past a half
turn the tip is concave and its rounding fills the notch. A whole disc
has no corners. The tests use the rounded outline with each curve
flattened, so a point within about 0.1% of the radii of the boundary
may fall either way.

Implements `Copyable`, `Deinitable`, `Drawable`, `Equatable`, `Geometry`, `ImplicitlyCopyable`, `Movable`, `Shape`, `Writable`.

## Fields

- `position: Point`
- `radius: Float64`
- `start_angle: Float64`
- `sweep_angle: Float64`
- `corner_radius: Float64`: How far each corner is rounded; 0 is sharp.

## Constructors

```mojo
@staticmethod
def __init__(
    out self,
    position: Point,
    radius: Float64,
    start_angle: Float64,
    sweep_angle: Float64,
    *,
    corner_radius: _OptionalFloat64 = SIMD(0),
)
@staticmethod
def __init__(
    out self,
    position: Point,
    radius: Int,
    start_angle: Float64,
    sweep_angle: Float64,
    *,
    corner_radius: _OptionalFloat64 = SIMD(0),
)
```

## Methods

### `end_angle`

```mojo
def end_angle(self) -> Float64
```

`start_angle + sweep_angle`: where the sector ends, as an angle.

### `center`

```mojo
def center(self) -> Point
```

### `area`

```mojo
def area(self) -> Float64
```

### `arc`

```mojo
def arc(self) -> Arc
```

The curved edge of the sector, running the same way round.

### `bounds`

```mojo
def bounds(self) -> Rectangle
```

The tightest axis-aligned rectangle around the sector: its arc's, widened to take in the tip.

### `closest_point`

```mojo
def closest_point(self, p: Point) -> Point
```

### `contains`

```mojo
def contains(self, p: Point) -> Bool
def contains(self, radius: Rectangle) -> Bool
def contains(self, t: Triangle) -> Bool
def contains(self, c: Circle) -> Bool
def contains(self, other: Self) -> Bool
def contains(self, l: Line) -> Bool
```

```mojo
def contains[C: Curve](self, curve: C) -> Bool
```

Whether the whole of `curve` (an `Arc`, `Bezier` or `Spline`) is inside: every segment of it flattened to within 1e-4 of its size, as `intersects` follows it, so a curve grazing the edge from inside is decided only that closely.

```mojo
def contains(self, p: Polygon) -> Bool
def contains(self, e: Ellipse) -> Bool
def contains(self, c: Capsule) -> Bool
```

### `overlaps`

```mojo
def overlaps(self, other: Rectangle) -> Bool
def overlaps(self, other: Circle) -> Bool
def overlaps(self, other: Ellipse) -> Bool
def overlaps(self, other: Capsule) -> Bool
def overlaps(self, other: Triangle) -> Bool
def overlaps(self, other: Self) -> Bool
def overlaps(self, other: Polygon) -> Bool
```

Whether this and `other` share any point, their boundaries included: shapes that only touch, along an edge or at a corner, overlap. Symmetric: `other.overlaps(self)` gives the same answer.

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
