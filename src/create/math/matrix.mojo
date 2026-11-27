from .number import Number
from std.math import abs, min, max

from .transform import Transform

# The most multiply-adds `@` unrolls: a 4 by 4 product.
comptime _UNROLL_LIMIT = 64


struct Matrix[rows: Int, cols: Int](
    Copyable, Equatable, ImplicitlyCopyable, Movable, Writable
):
    """A grid of numbers, `rows` by `cols`, sized when the program is
    compiled: for linear algebra, such as solving equations or working in
    more dimensions than two.

    A 2D transform, moving, turning or scaling a drawing, is a `Transform`,
    not a `Matrix`. `Matrix[3, 3](transform)` gives a transform's full grid,
    and `Transform(matrix)` converts a 3 by 3 one back.

    `Matrix[2, 2](1, 2, 3, 4)` takes the numbers row by row. `m[row, column]`
    reads or changes one, counting from 0. `a @ b` multiplies two matrices,
    `m.transpose()` swaps rows and columns, `identity[N]()` is the N by N
    matrix that changes nothing when multiplied, and `inverse(m)` the one
    that undoes `m`.
    """

    var data: Array[Float64, Self.rows * Self.cols]

    def __init__(out self):
        """All zeros."""
        self.data = Array[Float64, Self.rows * Self.cols](fill=0.0)

    def __init__(out self, *values: Number):
        """The entries, row by row: `Matrix[2, 2](1.0, 2.0, 3.0, 4.0)` has
        `1.0, 2.0` on top. Takes exactly `rows * cols` values."""
        debug_assert(
            len(values) == Self.rows * Self.cols,
            "Matrix: takes exactly rows * cols values",
        )
        self.data = Array[Float64, Self.rows * Self.cols](fill=0.0)
        for i in range(min(len(values), Self.rows * Self.cols)):
            self.data[i] = Float64(values[i])

    def __init__(out self, transform: Transform):
        """The full 3 by 3 matrix of `transform`, its bottom row `0 0 1`.
        Only a `Matrix[3, 3]` can be built this way."""
        comptime assert (
            Self.rows == 3 and Self.cols == 3
        ), "Matrix: only a Matrix[3, 3] converts from a Transform"
        self = Self(
            transform._xx,
            transform._xy,
            transform._x0,
            transform._yx,
            transform._yy,
            transform._y0,
            0.0,
            0.0,
            1.0,
        )

    def __init__(out self, *, copy: Self):
        self.data = Array[Float64, Self.rows * Self.cols](copy=copy.data)

    @always_inline
    def __getitem__(self, r: Int, c: Int) -> Float64:
        return self.data[r * Self.cols + c]

    @always_inline
    def __setitem__(mut self, r: Int, c: Int, val: Number):
        self.data[r * Self.cols + c] = Float64(val)

    def __matmul__[
        P: Int
    ](self, rhs: Matrix[Self.cols, P]) -> Matrix[Self.rows, P]:
        var result = Matrix[Self.rows, P]()
        # Unrolled when small enough, which is most of the time: a loop costs
        # several times the arithmetic of a 3 by 3 product. A large product
        # keeps the loop, so it doesn't compile into thousands of lines.
        comptime if Self.rows * P * Self.cols <= _UNROLL_LIMIT:
            comptime for r in range(Self.rows):
                comptime for p in range(P):
                    var s = 0.0
                    comptime for k in range(Self.cols):
                        s += self[r, k] * rhs[k, p]
                    result[r, p] = s
        else:
            for r in range(Self.rows):
                for p in range(P):
                    var s = 0.0
                    for k in range(Self.cols):
                        s += self[r, k] * rhs[k, p]
                    result[r, p] = s
        return result^

    def transpose(self) -> Matrix[Self.cols, Self.rows]:
        """Rows and columns swapped, as a new matrix."""
        var result = Matrix[Self.cols, Self.rows]()
        for r in range(Self.rows):
            for c in range(Self.cols):
                result[c, r] = self[r, c]
        return result^

    def __eq__(self, other: Self) -> Bool:
        for i in range(Self.rows * Self.cols):
            if self.data[i] != other.data[i]:
                return False
        return True

    def __ne__(self, other: Self) -> Bool:
        return not (self == other)

    def write_to[W: Writer](self, mut writer: W):
        # One row per line, each column padded to its widest entry, so the
        # printed call reads as the matrix it builds.
        var widths = List[Int](length=Self.cols, fill=0)
        for i in range(Self.rows * Self.cols):
            var c = i % Self.cols
            widths[c] = max(widths[c], String(self.data[i]).byte_length())
        writer.write("Matrix[", Self.rows, ", ", Self.cols, "](\n")
        for r in range(Self.rows):
            writer.write("    ")
            for c in range(Self.cols):
                var entry = String(self[r, c])
                if c > 0:
                    writer.write(" ")
                writer.write(
                    " " * (widths[c] - entry.byte_length()), entry, ","
                )
            writer.write("\n")
        writer.write(")")


def identity[N: Int]() -> Matrix[N, N]:
    """The N by N matrix that changes nothing when multiplied by: ones along
    its diagonal, zeros everywhere else."""
    var m = Matrix[N, N]()
    comptime for i in range(N):
        m[i, i] = 1.0
    return m^


def inverse[N: Int](m: Matrix[N, N]) -> Matrix[N, N]:
    """The matrix that undoes `m`: `inverse(m) @ m` is the identity.

    Found by Gauss-Jordan elimination with partial pivoting. A singular
    matrix, one that squashes some direction to nothing, has no inverse, and
    the result holds meaningless numbers rather than raising an error.
    """
    var aug = Matrix[N, N * 2]()
    for r in range(N):
        for c in range(N):
            aug[r, c] = m[r, c]
        aug[r, N + r] = 1.0

    for col in range(N):
        var max_val = abs(aug[col, col])
        var max_row = col
        for r in range(col + 1, N):
            var v = abs(aug[r, col])
            if v > max_val:
                max_val = v
                max_row = r

        for c in range(N * 2):
            var tmp = aug[col, c]
            aug[col, c] = aug[max_row, c]
            aug[max_row, c] = tmp

        var pivot = aug[col, col]
        for c in range(N * 2):
            aug[col, c] /= pivot

        for r in range(N):
            if r != col:
                var factor = aug[r, col]
                for c in range(N * 2):
                    aug[r, c] -= factor * aug[col, c]

    var result = Matrix[N, N]()
    for r in range(N):
        for c in range(N):
            result[r, c] = aug[r, N + c]
    return result^
