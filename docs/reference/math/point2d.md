# Point2D

```mojo
struct Point2D
```

A location in world space: `distance`, `lerp`, the affine operators, and an explicit constructor from a `Vector2D` for crossing between the two.

Every position in the library is one of these —
`canvas.circle(position, r)`, `Rectangle.center()`, `context.mouse.position` — and no
signature takes a location as a loose x/y pair instead. The tuple constructors are `@implicit`, so
`canvas.circle((0, 0), 20)` works without naming the type and a program
only spells `Point2D` when it is storing one. It is the only type here
that converts from a bare tuple, which is what keeps that unambiguous.

The surface is strictly affine, which is the whole point of the type
existing beside `Vector2D`: subtracting two positions gives the
displacement between them (`Vector2D`), and adding a displacement to a
position gives another position. `magnitude`, `normalize`, `dot`, scalar `*`,
unary `-` and `Point2D + Point2D` are absent on purpose — none of them
means anything for a location, and `position.normalize()` compiling was the
mistake this split exists to catch. A program that genuinely wants a
position's components as a direction says so: `Vector2D(p)`.

A displacement is always named: `p + Vector2D(1, 2)` moves a position.
Mind `p - (1, 2)`: the tuple can only become a `Point2D`, so it is the
displacement from `(1, 2)` to `p` -- a `Vector2D`, not a moved position.
Moving backwards is `p - Vector2D(1, 2)`.

There are no `zero()`/`one()` factories either. `(0, 0)` through the
implicit constructor is shorter than any name for the origin, and `one()`
has no meaning for a position at all.

Crossing to another type is an explicit constructor, never an implicit
one: `Vector2D(p)` is the displacement from the origin to `p`,
and `Point2D(v)` the origin moved by `v`. Naming
the target type is what keeps the conversion visible; an `@implicit` one
would undo the split. `xy` returns the components as a plain tuple, to
destructure: `var (x, y) = p.xy()`.

Implements `Copyable`, `Deinitable`, `Equatable`, `ImplicitlyCopyable`, `Movable`, `Writable`.

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
@staticmethod
def __init__(out self, t: Tuple[Int, Int])
@staticmethod
def __init__(out self, t: Tuple[Int, Float64])
@staticmethod
def __init__(out self, t: Tuple[Float64, Int])
```

```mojo
@staticmethod
def __init__(out self, v: Vector2D)
```

The origin moved by `v`: the position `v` points to.

## Methods

### `distance`

```mojo
def distance(self, other: Self) -> Float64
```

### `distance_squared`

```mojo
def distance_squared(self, other: Self) -> Float64
```

### `lerp`

```mojo
def lerp(self, other: Self, t: Float64) -> Self
```

A new point `t` of the way from this one to `other`; this one is unchanged. Not clamped: `t` outside 0..1 carries on past either end.

### `xy`

```mojo
def xy(self) -> Tuple[Float64, Float64]
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

### `__add__`

```mojo
def __add__(self, v: Vector2D) -> Self
```

### `__sub__`

```mojo
def __sub__(self, other: Self) -> Vector2D
```

The displacement from `other` to `self`.

```mojo
def __sub__(self, v: Vector2D) -> Self
```

### `__iadd__`

```mojo
def __iadd__(mut self, v: Vector2D)
```

### `__isub__`

```mojo
def __isub__(mut self, v: Vector2D)
```
