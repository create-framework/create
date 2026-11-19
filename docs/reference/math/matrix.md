# Matrix

```mojo
struct Matrix[rows: Int, cols: Int]
```

A grid of numbers, `rows` by `cols`, sized when the program is compiled: for linear algebra, such as solving equations or working in more dimensions than two.

A 2D transform, moving, turning or scaling a drawing, is a `Transform`,
not a `Matrix`. `Matrix[3, 3](transform)` gives a transform's full grid,
and `Transform(matrix)` converts a 3 by 3 one back.

`Matrix[2, 2](1, 2, 3, 4)` takes the numbers row by row. `m[row, column]`
reads or changes one, counting from 0. `a @ b` multiplies two matrices,
`m.transpose()` swaps rows and columns, `identity[N]()` is the N by N
matrix that changes nothing when multiplied, and `inverse(m)` the one
that undoes `m`.

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
def __init__(out self, transform: Transform)
```

The full 3 by 3 matrix of `transform`, its bottom row `0 0 1`. Only a `Matrix[3, 3]` can be built this way.

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
