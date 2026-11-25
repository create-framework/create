# Circle

```mojo
struct Circle
```

A circle: `center`, `area`, `diameter`, `closest_point`, `contains`, `move_to`, `translate`.

`position` is the centre -- there is no orientation, so unlike
`Rectangle`/`Triangle` there is nothing y-up affects beyond the centre's
own coordinates.

`contains` treats the boundary as inside (`distance <= r`), and
`closest_point` returns the query point itself when it is already
inside or exactly at the centre, rather than an arbitrary point on the
circumference. A zero `radius` collapses the circle to a point; `contains`
then holds only for that exact point, and `overlaps`/`intersects`
remain exact rather than always-false. `radius` is assumed non-negative.

Implements `Copyable`, `Deinitable`, `Equatable`, `Geometry`, `ImplicitlyCopyable`, `Movable`, `Shape`, `Writable`, `_Collider`.

## Fields

- `position: Point`
- `radius: Float64`

## Constructors

```mojo
@staticmethod
def __init__(out self, position: Point, radius: Float64)
@staticmethod
def __init__(out self, position: Point, radius: Int)
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

### `diameter`

```mojo
def diameter(self) -> Float64
```

### `bounds`

```mojo
def bounds(self) -> Rectangle
```

The tightest axis-aligned rectangle around the circle.

### `closest_point`

```mojo
def closest_point(self, p: Point) -> Point
```

### `contains`

```mojo
def contains(self, p: Point) -> Bool
def contains(self, other: Self) -> Bool
def contains(self, radius: Rectangle) -> Bool
def contains(self, t: Triangle) -> Bool
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
def overlaps(self, other: Self) -> Bool
def overlaps(self, other: Ellipse) -> Bool
def overlaps(self, other: Capsule) -> Bool
def overlaps(self, other: Triangle) -> Bool
def overlaps(self, other: Sector) -> Bool
def overlaps(self, other: Polygon) -> Bool
```

Whether this and `other` share any point, their boundaries included: shapes that only touch, along an edge or at a corner, overlap. Symmetric: `other.overlaps(self)` gives the same answer.

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
