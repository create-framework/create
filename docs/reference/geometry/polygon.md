# Polygon

```mojo
struct Polygon
```

A polygon through `vertices`, in order, closed back to the first: `regular`, `star`, `center`, `area`, `bounds`, `closest_point`, `contains`, `move_to`, `translate`.

Any vertices make a polygon, concave or crossing itself. What is inside
follows the nonzero rule: a point is inside when the edges wind round
it, either way, so a pentagram given as five crossing vertices is solid
through its middle. Vertex winding does not matter, and the boundary
counts as inside. With fewer than three vertices, or all of them in
line, the polygon collapses to its edges.

It is a region: in every `overlaps` pair, `contains` both ways, and
met by `Line.intersects` and `Arc.intersects`.

Like a `Triangle`'s, the fields are the vertices and `center()` (the
centroid) is derived; `move_to` moves the centroid. The centroid and
`area` are those of a simple polygon -- one whose edges do not cross.

`corner_radius` rounds every corner, as `canvas.polygon` draws it, and
every test here sees the rounded shape. Each corner is clamped on its
own so its rounding takes at most half of either edge beside it: a
sharp tip rounds less without holding back the rest. A concave corner
rounds too, filling its notch. The tests use the rounded outline with
each fillet flattened, so a point within about 0.1% of the radius of a
fillet may fall either way.

Implements `Copyable`, `Deinitable`, `Drawable`, `Equatable`, `Movable`, `Region`, `Shape`, `Writable`.

## Fields

- `vertices: List[Point]`
- `corner_radius: Float64`: How far each corner is rounded; 0 is sharp.

## Constructors

```mojo
@staticmethod
def __init__(out self, *vertices: Point, *, corner_radius: _OptionalFloat64 = SIMD(0))
@staticmethod
def __init__(
    out self,
    var vertices: List[Point],
    *,
    corner_radius: _OptionalFloat64 = SIMD(0),
)
```

### `regular`

```mojo
@staticmethod
def regular(
    position: Point,
    radius: Float64,
    sides: Int,
    start_angle: Float64 = 1.5707963267948966,
    *,
    corner_radius: _OptionalFloat64 = SIMD(0),
) -> Self
```

A regular polygon of `sides` vertices on the circle around `position` with radius `radius`, the first at `start_angle` (radians counter-clockwise from +x; straight up by default), the rest following counter-clockwise.

```mojo
@staticmethod
def regular(
    position: Point,
    radius: Int,
    sides: Int,
    start_angle: Float64 = 1.5707963267948966,
    *,
    corner_radius: _OptionalFloat64 = SIMD(0),
) -> Self
```

### `star`

```mojo
@staticmethod
def star(
    position: Point,
    radius: Float64,
    inner_radius: Float64,
    tips: Int,
    start_angle: Float64 = 1.5707963267948966,
    *,
    corner_radius: _OptionalFloat64 = SIMD(0),
) -> Self
```

A star of `tips` points about `position`: its tips on `radius`, the first at `start_angle` (straight up by default), and between each two tips a vertex on `inner_radius`, halfway round. The outline does not cross itself, so it is a simple polygon.

```mojo
@staticmethod
def star(
    position: Point,
    radius: Int,
    inner_radius: Int,
    tips: Int,
    start_angle: Float64 = 1.5707963267948966,
    *,
    corner_radius: _OptionalFloat64 = SIMD(0),
) -> Self
```

## Methods

### `center`

```mojo
def center(self) -> Point
```

The centroid of the enclosed area; with no area, the mean of the vertices (the origin for none).

### `area`

```mojo
def area(self) -> Float64
```

### `bounds`

```mojo
def bounds(self) -> Rectangle
```

The tightest axis-aligned rectangle around the polygon; a zero-size one at the origin for none.

### `closest_point`

```mojo
def closest_point(self, p: Point) -> Point
```

`p` itself when inside, else the nearest point on an edge. A polygon with no vertices has no points, and returns `p`.

### `contains`

```mojo
def contains(self, p: Point) -> Bool
def contains(self, l: Line) -> Bool
```

```mojo
def contains[C: Curve](self, curve: C) -> Bool
```

Whether the whole of `curve` (an `Arc`, `Bezier` or `Spline`) is inside: every segment of it flattened to within 1e-4 of its size, as `intersects` follows it, so a curve grazing the edge from inside is decided only that closely.

```mojo
def contains(self, radius: Rectangle) -> Bool
def contains(self, t: Triangle) -> Bool
def contains(self, c: Circle) -> Bool
def contains(self, s: Sector) -> Bool
def contains(self, other: Self) -> Bool
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
def overlaps(self, other: Sector) -> Bool
def overlaps(self, other: Self) -> Bool
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
