# Shape

```mojo
trait Shape
```

Geometry with an inside: `Rectangle`, `Circle`, `Ellipse`, `Capsule`, `Triangle`, `Sector` and `Polygon`, the types of `overlaps` and `contains`, and what `canvas.clip` takes. A curve has no inside, so it is not one.

Implements `Copyable`, `Deinitable`, `Geometry`, `Movable`.

## Methods

### `center`

```mojo
def center(self) -> Point
```

Its centre: where `move_to` puts `position` for a shape without a `position` of its own.

### `area`

```mojo
def area(self) -> Float64
```

How much room it covers, in square units, its rounded corners taken into account.

### `contains`

```mojo
def contains(self, p: Point) -> Bool
```

Whether `p` is inside, its boundary included.

### `move_to`

```mojo
def move_to(self, position: Point) -> Self
```

The shape moved so its `position` (or, without one, its `center()`) is at `position`; this one is unchanged.
