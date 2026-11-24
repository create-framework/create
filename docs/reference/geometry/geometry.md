# Geometry

```mojo
trait Geometry
```

A piece of geometry: a `Shape` or a `Curve`. What every one of them answers, whichever it is, and a plain value generic code can keep, copy and drop. Tests between two of them (`contains`, `intersects`, `overlaps`) are methods overloaded per type they take, not part of this.

Implements `Copyable`, `Deinitable`, `Drawable`, `Movable`.

## Methods

### `bounds`

```mojo
def bounds(self) -> Rectangle
```

The tightest axis-aligned rectangle around it.

### `closest_point`

```mojo
def closest_point(self, p: Point) -> Point
```

Its point nearest `p`: `p` itself inside a `Shape`.

### `translate`

```mojo
def translate(self, delta: Vector) -> Self
```

It moved by `delta`; this one is unchanged.
