# Ellipse

```mojo
struct Ellipse
```

An axis-aligned ellipse: `center`, `area`, `bounds`, `closest_point`, `contains`, `move_to`, `translate`.

`position` is the centre and `width`/`height` the full width and height,
as for `Rectangle`, whose `bounds()` it fills; a turned ellipse is drawn
through `canvas.transform`. With `width == height` it is the circle of
diameter `width`, and every test agrees with that `Circle`'s.

`contains` treats the boundary as inside, and `closest_point` returns
the query point itself when it is inside. A zero `width` or `height`
collapses the ellipse to the segment (or point) its `bounds()` is, and
every test treats it as that zero-size `Rectangle`, exactly.
`width`/`height` are assumed non-negative.

An ellipse is a circle stretched along its axes, so a test against a
shape that stretching keeps a shape of its kind -- a point, a `Line`,
a sharp `Rectangle`, `Triangle` or `Polygon` -- runs exactly on the
unit circle with the other shape mapped there. Against a `Circle` or
another `Ellipse` it is exact too, through the closest point on the
ellipse, accurate to rounding. Against a `Sector` and its arc, the
ellipse stands in as its outline polygon, within 1e-4 of its larger
side; a curve is followed as closely, and a rounded shape is tested as
its own outline, as everywhere.

Implements `Copyable`, `Deinitable`, `Drawable`, `Equatable`, `Geometry`, `ImplicitlyCopyable`, `Movable`, `Shape`, `Writable`.

## Fields

- `position: Point`
- `width: Float64`
- `height: Float64`

## Constructors

```mojo
@staticmethod
def __init__(out self, position: Point, width: Float64, height: Float64)
@staticmethod
def __init__(out self, position: Point, width: Int, height: Int)
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

The tightest axis-aligned rectangle around the ellipse.

### `closest_point`

```mojo
def closest_point(self, p: Point) -> Point
```

### `contains`

```mojo
def contains(self, p: Point) -> Bool
def contains(self, radius: Rectangle) -> Bool
```

```mojo
def contains(self, c: Circle) -> Bool
```

Whether `c` is inside: its centre is, and no nearer the curve than its radius.

```mojo
def contains(self, t: Triangle) -> Bool
def contains(self, l: Line) -> Bool
```

```mojo
def contains[C: Curve](self, curve: C) -> Bool
```

Whether the whole of `curve` (an `Arc`, `Bezier` or `Spline`) is inside: every segment of it flattened to within 1e-4 of its size, as `intersects` follows it, so a curve grazing the edge from inside is decided only that closely.

```mojo
def contains(self, s: Sector) -> Bool
```

Whether `s` is inside: its tip and its arc are, since every point of a sector lies between the two and the ellipse is convex.

```mojo
def contains(self, p: Polygon) -> Bool
```

```mojo
def contains(self, other: Self) -> Bool
```

Whether `other` is inside: with `other` mapped onto the unit circle, this one, mapped alike, still an ellipse, holds that circle.

```mojo
def contains(self, c: Capsule) -> Bool
```

### `overlaps`

```mojo
def overlaps(self, other: Rectangle) -> Bool
def overlaps(self, other: Circle) -> Bool
def overlaps(self, other: Self) -> Bool
def overlaps(self, other: Capsule) -> Bool
def overlaps(self, other: Triangle) -> Bool
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
