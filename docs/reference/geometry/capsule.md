# Capsule

```mojo
struct Capsule
```

A capsule: every point within `radius` of the segment from `start` to `end` -- a rectangle along the segment, capped by a half disc at each end. `center`, `area`, `bounds`, `closest_point`, `contains`, `move_to`, `translate`.

Like a `Line`, it lies along any direction and is placed by its ends,
so `center()` is the segment's midpoint and `move_to` moves that. A
stadium is also a `Rectangle` with `corner_radius=height / 2`, turned by
`rotation=angle`; a capsule is the one placed by its ends, the usual round
collider for a moving body. With `start == end` it is the `Circle` of
`radius` there, and a zero `radius` collapses it to the segment.

`contains` treats the boundary as inside, and `closest_point` returns
the query point itself when it is inside. Every test is a distance from
the segment, so they are exact: against a point, a line, a circle,
another capsule, an arc, an ellipse and every straight-edged shape,
rounded rectangles and triangles included. A shape inside it only needs
its corners (or its ends' discs) inside, since a capsule is convex.
Holding a `Sector`'s arc or an `Ellipse`, it follows them as a curve is
followed, within 1e-4 of their size, and a rounded polygon or sector is
tested as its outline, as everywhere. `radius` is assumed non-negative.

Implements `Copyable`, `Deinitable`, `Drawable`, `Equatable`, `Geometry`, `ImplicitlyCopyable`, `Movable`, `Shape`, `Writable`, `_Collider`.

## Fields

- `start: Point`
- `end: Point`
- `radius: Float64`

## Constructors

```mojo
@staticmethod
def __init__(out self, start: Point, end: Point, radius: Float64)
@staticmethod
def __init__(out self, start: Point, end: Point, radius: Int)
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

The tightest axis-aligned rectangle around the capsule: the segment's, grown by `radius` all round.

### `closest_point`

```mojo
def closest_point(self, p: Point) -> Point
```

### `contains`

```mojo
def contains(self, p: Point) -> Bool
def contains(self, l: Line) -> Bool
def contains(self, radius: Rectangle) -> Bool
def contains(self, c: Circle) -> Bool
def contains(self, t: Triangle) -> Bool
def contains(self, other: Self) -> Bool
```

```mojo
def contains[C: Curve](self, curve: C) -> Bool
```

Whether the whole of `curve` (an `Arc`, `Bezier` or `Spline`) is inside: every segment of it flattened to within 1e-4 of its size, as `intersects` follows it, so a curve grazing the edge from inside is decided only that closely.

```mojo
def contains(self, s: Sector) -> Bool
```

Whether `s` is inside: its tip and its arc are, since every point of a sector lies between the two and the capsule is convex.

```mojo
def contains(self, p: Polygon) -> Bool
```

```mojo
def contains(self, e: Ellipse) -> Bool
```

Whether `e` is inside, its curve followed by its outline polygon.

### `overlaps`

```mojo
def overlaps(self, other: Rectangle) -> Bool
def overlaps(self, other: Circle) -> Bool
def overlaps(self, other: Ellipse) -> Bool
def overlaps(self, other: Self) -> Bool
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
