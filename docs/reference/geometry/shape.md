# Shape

```mojo
trait Shape
```

A geometric shape: a `Region` or a `Curve`. What every one of them answers, whichever it is, and a plain value generic code can keep, copy and drop. Tests between two shapes (`contains`, `intersects`, `overlaps`) are methods overloaded per shape they take, not part of this.

Implements `Copyable`, `Deinitable`, `Drawable`, `Movable`.

## Methods

### `bounds`

```mojo
def bounds(self) -> Rectangle
```

The tightest axis-aligned rectangle around the shape.

### `closest_point`

```mojo
def closest_point(self, p: Point2D) -> Point2D
```

The point of the shape nearest `p`: `p` itself inside a region.

### `translate`

```mojo
def translate(self, delta: Vector2D) -> Self
```

The shape moved by `delta`; this one is unchanged.
