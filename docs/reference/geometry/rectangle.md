# Rectangle

```mojo
struct Rectangle
```

A rectangle, upright unless turned by `rotation`: `center`, `area`, `bounds`, `left`/`right`/`bottom`/`top`, `closest_point`, `contains`, `move_to`, `translate`.

Locations are `Point` and displacements `Vector`, throughout this
module; extents are plain scalars, like `Circle`'s radius. Width and
height are two independent lengths rather than a coordinate pair, so
they are not grouped: read them as `width`/`height` and pair them however
the caller needs.

`position` is the centre, not a corner -- consistent with every shape in
this module and with `canvas.rectangle`. `width`/`height` are the full
width and height, so `left()`/`right()`/`bottom()`/`top()` are
`+-width/2`/`+-height/2` from the centre. Coordinates follow world space: y
grows upward, so `top()` is `position.y + height/2` and `bottom()` is
`position.y - height/2`.

`contains` and `closest_point` treat the boundary as inside -- a point
exactly on an edge is contained, and `closest_point` returns it
unchanged. A zero `width`/`height` collapses the rectangle to a segment or a
point; `contains`/`overlaps` remain exact for it rather than reporting
a false containment or overlap. `width`/`height` are assumed non-negative.

`corner_radius` rounds all four corners, as `canvas.rectangle` draws
them, and every test here sees the rounded shape: a point in a sharp
corner's cut-away is outside. It is clamped to half the shorter side.
`left()`/`right()`/`bottom()`/`top()` stay the bounding box's.

`rotation` turns the rectangle about `position`, in radians
counter-clockwise (y is up), as `canvas.rotate(...)` turns
what it draws; `width` and `height` stay its own width and height. Every
test sees the turned shape, exactly, and `left()`/`right()`/`bottom()`/
`top()` and `bounds()` are its upright bounding box's. Drawn, it is the
upright rectangle turned, so a gradient fill, the rounding and the
stroke turn with it, while a shadow's offset stays screen-fixed unless
`shadow_follows_transform` is set, as for any turned shape.

Implements `Copyable`, `Deinitable`, `Equatable`, `Geometry`, `ImplicitlyCopyable`, `Movable`, `Shape`, `Writable`, `_Collider`.

## Fields

- `position: Point`
- `width: Float64`
- `height: Float64`
- `corner_radius: Float64`: How far each corner is rounded, in the units of `width`/`height`; 0 is sharp.
- `rotation: Float64`: How far the rectangle is turned about `position`, in radians counter-clockwise; 0 is upright.

## Constructors

```mojo
@staticmethod
def __init__(
    out self,
    position: Point,
    width: Float64,
    height: Float64,
    *,
    corner_radius: OptionalNumber = SIMD(0),
    rotation: OptionalNumber = SIMD(0),
)
@staticmethod
def __init__(
    out self,
    position: Point,
    width: Int,
    height: Int,
    *,
    corner_radius: OptionalNumber = SIMD(0),
    rotation: OptionalNumber = SIMD(0),
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
def bounds(self) -> Self
```

The tightest axis-aligned rectangle around this one: upright, itself, sharp, since rounding never pulls in an edge's middle; turned, as far as its rounded corners reach along each axis.

### `closest_point`

```mojo
def closest_point(self, p: Point) -> Point
```

### `left`

```mojo
def left(self) -> Float64
```

### `right`

```mojo
def right(self) -> Float64
```

### `bottom`

```mojo
def bottom(self) -> Float64
```

### `top`

```mojo
def top(self) -> Float64
```

### `contains`

```mojo
def contains(self, p: Point) -> Bool
def contains(self, other: Self) -> Bool
def contains(self, c: Circle) -> Bool
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
def overlaps(self, other: Self) -> Bool
def overlaps(self, other: Circle) -> Bool
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

### `inset`

```mojo
def inset(self, amount: Float64) -> Self
```

The rectangle with each side moved in by `amount`, about the same centre: 10 narrower and 10 lower for an `amount` of 5. A negative `amount` moves the sides out instead. The width and height stop at 0, and the corner radius and rotation are kept.

```mojo
# In `update`: a frame drawn 8 units inside the screen's edges.
canvas.draw(canvas.bounds().inset(8))
```

### `rows`

```mojo
def rows(self, count: Int, *, gap: Float64 = 0) -> List[Self]
```

The rectangle cut into `count` rows of equal height, the top one first, with `gap` between each row and the next.

```mojo
# In `update`: three bars stacked down the middle of the screen.
for bar in Rectangle((0, 0), 300, 200).rows(3, gap=10):
    canvas.draw(bar)
```

```mojo
def rows(self, *, weights: List[Float64], gap: Float64 = 0) -> List[Self]
```

The rectangle cut into one row for each weight, the top one first, with `gap` between each row and the next. The rows share the height left after the gaps in proportion to their weights, so `weights=[1, 3]` gives the top row a quarter of it and the bottom one three quarters.

### `columns`

```mojo
def columns(self, count: Int, *, gap: Float64 = 0) -> List[Self]
```

The rectangle cut into `count` columns of equal width, the left one first, with `gap` between each column and the next.

```mojo
# In `update`: four boxes side by side, 8 units apart.
for cell in Rectangle((0, 0), 400, 60).columns(4, gap=8):
    canvas.draw(cell)
```

```mojo
def columns(self, *, weights: List[Float64], gap: Float64 = 0) -> List[Self]
```

The rectangle cut into one column for each weight, the left one first, with `gap` between each column and the next. The columns share the width left after the gaps in proportion to their weights, so `weights=[1, 3]` gives the left column a quarter of it and the right one three quarters.

## Special methods

### `__eq__`

```mojo
def __eq__(self, other: Self) -> Bool
```

### `__ne__`

```mojo
def __ne__(self, other: Self) -> Bool
```
