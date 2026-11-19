# Spline

```mojo
struct Spline
```

A smooth curve through every one of `points`, in order: `at`, `tangent`, `length`, `at_distance`, `bounds`, `flatten`, `beziers`, `closest_point`, `intersects`, `translate`.

It is a Catmull-Rom spline: each stretch between two neighbouring points
is a cubic whose direction at each point is set by that point's
neighbours, so the curve turns smoothly through every point without the
off-curve controls a `Bezier` needs. The first and last points have one
neighbour each; the curve leaves and arrives there heading along the
missing neighbour's mirror image. With `closed`, the curve runs on from
the last point back to the first and the ends have neighbours like any
other point.

`alpha` sets how the spacing of the points shapes the curve: 0 is
*uniform*, which can loop or cusp where points bunch up; 0.5,
*centripetal*, the default, never does within a stretch; 1 is *chordal*,
which hugs the points more loosely still. Between 0 and 1 is useful.

`t` runs from 0 at the first point to 1 at the last (back at the first
when closed), each stretch taking an equal share whatever its length, so
equal steps in `t` are not equal distances; `at_distance` is.

Fewer than two distinct points make no curve: then `at` and
`at_distance` give the one point (the origin if there is none), `length`
is 0 and `flatten` gives no points.

Like `Bezier`, a spline has no interior and is not a region.

Implements `Copyable`, `Curve`, `Deinitable`, `Drawable`, `Equatable`, `Movable`, `Shape`, `Writable`.

## Fields

- `points: List[Point]`
- `alpha: Float64`
- `closed: Bool`

## Constructors

```mojo
@staticmethod
def __init__(
    out self,
    var points: List[Point],
    alpha: Float64 = 0.5,
    closed: Bool = False,
)
```

## Methods

### `draw_to`

```mojo
def draw_to[T: DrawTarget](self, mut target: T)
```

### `beziers`

```mojo
def beziers(self) -> List[Bezier]
```

The spline as cubic Béziers, one per stretch between neighbouring points, each ending where the next starts. Exact, not an approximation: every stretch is a cubic, and any cubic is a Bézier.

An open spline of n points gives n - 1 curves; a closed one gives n,
the last ending at the first point. A point repeating the one before
it is skipped, as is a closed spline's last point repeating its
first; fewer than two distinct points give no curves.

### `at`

```mojo
def at(self, t: Float64) -> Point
```

The point at parameter `t`, clamped to 0..1: a spline has no natural continuation past its ends.

### `tangent`

```mojo
def tangent(self, t: Float64) -> Vector
```

The derivative with respect to `t` at `t`, clamped to 0..1: the direction of travel, with a magnitude that is the speed `t` moves at. A joint belongs to the stretch that starts there. Zero when there is no curve.

### `length`

```mojo
def length(self) -> Float64
```

The distance along the curve from the first point to the last, as each stretch's `Bezier.length` summed.

### `at_distance`

```mojo
def at_distance(self, distance: Float64) -> Point
```

The point `distance` along the curve from the first point, clamped to the curve's ends. Equal steps in `distance` are equal steps along the curve. Measures every stretch per call; sample once per frame per entity, not in a tight loop.

### `bounds`

```mojo
def bounds(self) -> Rectangle
```

The tightest axis-aligned rectangle around the curve. A spline with no curve gives a rectangle of no size at its one point.

### `flatten`

```mojo
def flatten(self, tolerance: Float64) -> List[Point]
```

Points along the curve, from the first point to the last inclusive, straying from it by at most `tolerance` between them: each stretch's `Bezier.flatten`, joined without repeating the point where one stretch meets the next.

### `closest_point`

```mojo
def closest_point(self, p: Point) -> Point
```

The point on the curve nearest `p`: the nearest of each stretch's `Bezier.closest_point`. A spline with no curve gives its one point.

### `intersects`

```mojo
def intersects(self, p: Point) -> Bool
def intersects(self, l: Line) -> Bool
def intersects(self, a: Arc) -> Bool
def intersects(self, b: Bezier) -> Bool
def intersects(self, c: Circle) -> Bool
def intersects(self, c: Capsule) -> Bool
def intersects(self, e: Ellipse) -> Bool
def intersects(self, r: Rectangle) -> Bool
def intersects(self, t: Triangle) -> Bool
def intersects(self, s: Sector) -> Bool
def intersects(self, p: Polygon) -> Bool
def intersects(self, other: Self) -> Bool
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
