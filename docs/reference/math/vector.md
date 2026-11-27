# Vector

```mojo
struct Vector
```

A 2D displacement or direction: arithmetic operators, `magnitude`, `normalize`, `dot`, `distance`, `lerp`, the angle helpers `from_angle`, `angle` and `rotate`, the length helpers `with_length` and `limit`, and an explicit constructor from a `Point`.

Unlike `Point`, a bare tuple does not convert to one implicitly: a
displacement literal names its type, `rect.translate(Vector(3, 4))`.
Only one type taking a bare tuple is what keeps `canvas.circle((0, 0), 20)`
unambiguous, and locations are the literals a program writes most;
displacements mostly arrive from arithmetic (`b - a`, `vel * dt`), which
already yields a `Vector`.

Crossing to another type is an explicit constructor: `Vector(p)` is
the displacement from the origin to the position `p`, and `Point(v)`
the reverse. Naming the target type is what
keeps the conversion visible. `xy` returns the components as a plain
tuple, to destructure: `var (x, y) = v.xy()`.

Angles are radians counter-clockwise from +x, as everywhere in the
library (y is up): `Vector.from_angle(a) * speed` aims, `v.angle()`
reads the heading back, `v.rotate(a)` turns. Like `normalize`, every
helper returns a new vector and leaves `self` alone.

The direction constants follow the screen's axes, y up: `UP` is
`Vector(0, 1)` and `DOWN` is `Vector(0, -1)`, so gravity is
`Vector.DOWN * 9.81`.

Implements `Copyable`, `Deinitable`, `Equatable`, `ImplicitlyCopyable`, `Movable`, `Writable`.

## Constants

- `ZERO = Vector(SIMD(0), SIMD(0))`
- `ONE = Vector(SIMD(1), SIMD(1))`
- `UP = Vector(SIMD(0), SIMD(1))`
- `DOWN = Vector(SIMD(0), SIMD(-1))`
- `LEFT = Vector(SIMD(-1), SIMD(0))`
- `RIGHT = Vector(SIMD(1), SIMD(0))`

## Fields

- `x: Float64`
- `y: Float64`

## Constructors

```mojo
@staticmethod
def __init__(out self, x: Float64, y: Float64)
@staticmethod
def __init__(out self, x: Int, y: Int)
@staticmethod
def __init__(out self, t: Tuple[Float64, Float64])
```

```mojo
@staticmethod
def __init__(out self, p: Point)
```

The displacement from the origin to `p`.

### `from_angle`

```mojo
@staticmethod
def from_angle(angle: Float64, length: Float64 = 1) -> Self
```

The vector of `length` pointing at `angle` radians, counter-clockwise from +x: `from_angle(0)` is `RIGHT`.

## Methods

### `magnitude`

```mojo
def magnitude(self) -> Float64
```

How long it is: `Vector(3, 4).magnitude()` is 5, by Pythagoras' theorem.

### `magnitude_squared`

```mojo
def magnitude_squared(self) -> Float64
```

The square of `magnitude`, without its square root: a little faster, and enough to compare lengths.

### `normalize`

```mojo
def normalize(self) -> Self
```

The vector pointing the same way, 1 long: its direction alone. The zero vector has no direction and gives NaN, so check `magnitude()` first where it can be zero.

### `dot`

```mojo
def dot(self, other: Self) -> Float64
```

The dot product: how much the two point the same way. For two vectors 1 long, 1 when they point the same way, 0 at right angles and -1 when opposite.

### `distance`

```mojo
def distance(self, other: Self) -> Float64
```

The length of the difference between the two vectors.

### `distance_squared`

```mojo
def distance_squared(self, other: Self) -> Float64
```

The square of `distance`, without its square root.

### `lerp`

```mojo
def lerp(self, other: Self, t: Float64) -> Self
```

A new vector `t` of the way from this one to `other`; this one is unchanged. Not clamped: `t` outside 0..1 carries on past either end.

### `angle`

```mojo
def angle(self) -> Float64
```

The heading in radians, counter-clockwise from +x, in `[-PI, PI]`. `0` for the zero vector.

### `rotate`

```mojo
def rotate(self, angle: Float64) -> Self
```

This vector turned by `angle` radians, counter-clockwise; its length is unchanged.

### `with_length`

```mojo
def with_length(self, length: Float64) -> Self
```

This direction at `length`. The zero vector has no direction and gives NaN, as with `normalize`.

### `limit`

```mojo
def limit(self, max_length: Float64) -> Self
```

This vector, shortened to `max_length` if it is longer: a speed cap. Shorter vectors, the zero vector among them, are unchanged.

### `xy`

```mojo
def xy(self) -> Tuple[Float64, Float64]
```

Its two numbers as a pair, to unpack: `var (x, y) = v.xy()`.

## Special methods

### `__neg__`

```mojo
def __neg__(self) -> Self
```

### `__eq__`

```mojo
def __eq__(self, other: Self) -> Bool
```

### `__ne__`

```mojo
def __ne__(self, other: Self) -> Bool
```

### `__add__`

```mojo
def __add__(self, other: Self) -> Self
```

### `__sub__`

```mojo
def __sub__(self, other: Self) -> Self
```

### `__mul__`

```mojo
def __mul__(self, s: Float64) -> Self
```

### `__truediv__`

```mojo
def __truediv__(self, s: Float64) -> Self
```

### `__rmul__`

```mojo
def __rmul__(self, s: Float64) -> Self
```

`s * v`, the same as `v * s`, so a formula reads as written.

### `__iadd__`

```mojo
def __iadd__(mut self, other: Self)
```

### `__isub__`

```mojo
def __isub__(mut self, other: Self)
```

### `__imul__`

```mojo
def __imul__(mut self, s: Float64)
```

### `__itruediv__`

```mojo
def __itruediv__(mut self, s: Float64)
```
