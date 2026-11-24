# Triangle

```mojo
struct Triangle
```

A triangle defined by its three vertices `a`, `b`, `c`: `center`, `area`, `closest_point`, `contains`, `move_to`, `translate`.

Unlike `Rectangle`/`Circle`, a `Triangle` is not centre-positioned in
its fields -- `center()` (the centroid) is derived, and `move_to`
translates all three vertices so the centroid lands on the given
point. Vertex winding (clockwise or counter-clockwise) does not matter
to any method here; `contains` and `area` both work from unsigned or
sign-normalized quantities.

`contains` treats every edge as inside (boundary-inclusive), matching
`Rectangle`/`Circle`. When the three vertices are collinear (including
all three coincident), the hull has zero area and collapses to the
longest edge as a segment; `contains`/`overlaps`/`area` all remain
exact for this degenerate case rather than reporting a false
containment, overlap, or a divide-by-zero.

`corner_radius` rounds all three corners by one radius, as
`canvas.triangle` draws them, and every test here sees the rounded
shape. It is clamped so no corner's rounding overruns half of either
edge beside it; one thin corner limits all three.

Implements `Copyable`, `Deinitable`, `Drawable`, `Equatable`, `Geometry`, `ImplicitlyCopyable`, `Movable`, `Shape`, `Writable`, `_Collider`.

## Fields

- `a: Point`
- `b: Point`
- `c: Point`
- `corner_radius: Float64`: How far each corner is rounded; 0 is sharp.

## Constructors

```mojo
@staticmethod
def __init__(
    out self,
    a: Point,
    b: Point,
    c: Point,
    *,
    corner_radius: _OptionalFloat64 = SIMD(0),
)
```

## Methods

### `center`

```mojo
def center(self) -> Point
```

### `area`

```mojo
def area(self) -> Float64
```

### `bounds`

```mojo
def bounds(self) -> Rectangle
```

The tightest axis-aligned rectangle around the triangle. Rounded, it is the inner triangle's grown by the radius, so a sharp tip's rounding pulls it in.

### `closest_point`

```mojo
def closest_point(self, p: Point) -> Point
```

### `contains`

```mojo
def contains(self, p: Point) -> Bool
def contains(self, other: Self) -> Bool
def contains(self, r: Rectangle) -> Bool
def contains(self, c: Circle) -> Bool
def contains(self, l: Line) -> Bool
def contains(self, c: Capsule) -> Bool
```

```mojo
def contains[C: Curve](self, curve: C) -> Bool
```

Whether the whole of `curve` (an `Arc`, `Bezier` or `Spline`) is inside: every segment of it flattened to within 1e-4 of its size, as `intersects` follows it, so a curve grazing the edge from inside is decided only that closely.

```mojo
def contains(self, s: Sector) -> Bool
def contains(self, p: Polygon) -> Bool
def contains(self, e: Ellipse) -> Bool
```

### `overlaps`

```mojo
def overlaps(self, other: Rectangle) -> Bool
def overlaps(self, other: Circle) -> Bool
def overlaps(self, other: Ellipse) -> Bool
def overlaps(self, other: Capsule) -> Bool
def overlaps(self, other: Self) -> Bool
def overlaps(self, other: Sector) -> Bool
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
