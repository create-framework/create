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

Implements `Copyable`, `Deinitable`, `Equatable`, `Geometry`, `ImplicitlyCopyable`, `Movable`, `Shape`, `Writable`.

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

Its centre: `position`.

### `area`

```mojo
def area(self) -> Float64
```

How much room it covers: π times its radius squared.

### `diameter`

```mojo
def diameter(self) -> Float64
```

How wide it is across: twice its radius.

### `bounds`

```mojo
def bounds(self) -> Rectangle
```

The tightest axis-aligned rectangle around the circle.

### `closest_point`

```mojo
def closest_point(self, p: Point) -> Point
```

Its point nearest `p`: `p` itself when inside, otherwise the nearest point on its edge.

### `contains`

```mojo
def contains(self, p: Point) -> Bool
```

Whether `p` is inside, its boundary included.

```mojo
def contains(self, other: Self) -> Bool
def contains(self, r: Rectangle) -> Bool
def contains(self, t: Triangle) -> Bool
def contains(self, l: Line) -> Bool
def contains(self, c: Capsule) -> Bool
```

Whether the whole of the other shape, or the line, lies inside, its boundary included. Rounded corners count, on both.

```mojo
def contains[C: Curve](self, curve: C) -> Bool
```

Whether the whole of `curve` (an `Arc`, `Bezier` or `Spline`) is inside: every segment of it flattened to within 1e-4 of its size, as `intersects` follows it, so a curve grazing the edge from inside is decided only that closely.

```mojo
def contains(self, s: Sector) -> Bool
def contains(self, p: Polygon) -> Bool
def contains(self, e: Ellipse) -> Bool
```

Whether the whole of the other shape, or the line, lies inside, its boundary included. Rounded corners count, on both.

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
