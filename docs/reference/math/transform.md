# Transform

```mojo
struct Transform
```

A change of position applied to points: moving, turning, scaling, mirroring and shearing, or any combination of them.

Build one from its parts, which apply in a fixed order: scaled first,
then turned, then moved.

```mojo
var placed = Transform(translation=Vector(100, 0), rotation=PI / 4, scale=2)
var stretched = Transform(scale_x=2, scale_y=0.5)
```

`Transform()` changes nothing. `a @ b` combines two transforms into one
that does both, and the one on the right happens first.
`t.apply(point)` moves a point, and `t.apply(vector)` turns and scales a
vector without moving it, since a vector is a movement rather than a
place. `t.inverse()` undoes `t`.

A transform is the top two rows of a 3 by 3 matrix whose bottom row is
always `0 0 1`, which is what makes it affine: straight lines stay
straight, and parallel lines stay parallel. `Matrix[3, 3](t)` gives the
full matrix, and `Transform(matrix)` converts one back.

Implements `Copyable`, `Deinitable`, `Equatable`, `ImplicitlyCopyable`, `Movable`, `Writable`.

## Constructors

```mojo
@staticmethod
def __init__(
    out self,
    *,
    translation: Vector = Vector.ZERO,
    rotation: Float64 = 0,
    scale: Float64 = 1,
)
```

Scaled by `scale`, then turned counter-clockwise by `rotation` radians about the origin, then moved by `translation`. A negative `scale` mirrors through the origin.

```mojo
@staticmethod
def __init__(
    out self,
    *,
    translation: Vector = Vector.ZERO,
    rotation: Float64 = 0,
    scale_x: Float64,
    scale_y: Float64,
)
```

Stretched by `scale_x` across and `scale_y` up and down, then turned counter-clockwise by `rotation` radians about the origin, then moved by `translation`. A negative scale mirrors along its axis.

```mojo
@staticmethod
def __init__(out self, matrix: Matrix[Int(3), Int(3)]) raises
```

The transform `matrix` describes. Raises if `matrix`'s bottom row isn't `0 0 1`: such a matrix is a perspective transform, which a `Transform` can't hold.

## Methods

### `apply`

```mojo
def apply(self, point: Point) -> Point
```

Where `point` ends up: turned, scaled and moved.

```mojo
def apply(self, vector: Vector) -> Vector
```

`vector` turned, scaled and sheared, but not moved: a movement is the same wherever it starts, so the translation doesn't change it.

### `inverse`

```mojo
def inverse(self) -> Self
```

The transform that undoes this one: it moves every point back to where it started.

A transform that squashes everything onto a line or a point, such as
`scale=0`, can't be undone, and its inverse holds meaningless numbers
rather than raising an error.

## Special methods

### `__eq__`

```mojo
def __eq__(self, other: Self) -> Bool
```

### `__ne__`

```mojo
def __ne__(self, other: Self) -> Bool
```

### `__matmul__`

```mojo
def __matmul__(self, rhs: Self) -> Self
```

The transform that does `rhs` first, then `self`.
