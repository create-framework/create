# Region

```mojo
trait Region
```

A shape with an inside: `Rectangle`, `Circle`, `Ellipse`, `Capsule`, `Triangle`, `Sector` and `Polygon`, the region types of `overlaps` and `contains`, and what `canvas.clip` takes. A curve has no inside, so it is not one.

Implements `Copyable`, `Deinitable`, `Drawable`, `Movable`, `Shape`.

## Methods

### `center`

```mojo
def center(self) -> Point2D
```

### `area`

```mojo
def area(self) -> Float64
```

### `contains`

```mojo
def contains(self, p: Point2D) -> Bool
```

Whether `p` is inside, its boundary included.

### `move_to`

```mojo
def move_to(self, position: Point2D) -> Self
```

The region moved so its `position` (or, without one, its `center()`) is at `position`; this one is unchanged.
