# Matrix

```mojo
struct Matrix[rows: Int, cols: Int]
```

A fixed-size matrix, row-major, sized at compile time.

Transforms are homogeneous, so the library's 2D transforms are
`Matrix[3, 3]` — the extra row and column is what lets a translation be a
multiplication like any other, and so compose into a single matrix.

Build them with the free functions below rather than by hand:
`identity`, `translate`, `rotate`, `scale`. Compose with
`@`, which applies right to left — `translate(x, y) @ rotate(a)` rotates
first, then moves the rotated result. `apply(m, point)` maps a `Point2D`
through it, translation included; `apply(m, vector)` maps a `Vector2D`,
which a translation does not move.

Implements `Copyable`, `Deinitable`, `Equatable`, `ImplicitlyCopyable`, `Movable`, `Writable`.

## Fields

- `data: Array[Float64, (rows * cols)]`

## Constructors

```mojo
@staticmethod
def __init__(out self)
```

All zeros.

```mojo
@staticmethod
def __init__(out self, *values: Float64)
```

The entries, row by row: `Matrix[2, 2](1.0, 2.0, 3.0, 4.0)` has `1.0, 2.0` on top. Takes exactly `rows * cols` values.

```mojo
@staticmethod
def __init__(out self, *, copy: Self)
```

## Methods

### `transpose`

```mojo
def transpose(self) -> Matrix[cols, rows]
```

Rows and columns swapped, as a new matrix.

## Special methods

### `__getitem__`

```mojo
def __getitem__(self, r: Int, c: Int) -> Float64
```

### `__setitem__`

```mojo
def __setitem__(mut self, r: Int, c: Int, val: Float64)
```

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
def __matmul__[P: Int](self, rhs: Matrix[cols, P]) -> Matrix[rows, P]
```
