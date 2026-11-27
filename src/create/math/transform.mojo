from .number import Number
from std.math import sin, cos

from .matrix import Matrix
from .point import Point
from .vector import Vector


struct Transform(Copyable, Equatable, ImplicitlyCopyable, Movable, Writable):
    """A change of position applied to points: moving, turning, scaling,
    mirroring and shearing, or any combination of them.

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
    """

    var _xx: Float64
    var _xy: Float64
    var _x0: Float64
    var _yx: Float64
    var _yy: Float64
    var _y0: Float64

    def __init__(
        out self,
        *,
        translation: Vector = Vector.ZERO,
        rotation: Number = 0.0,
        scale: Number = 1.0,
    ):
        """Scaled by `scale`, then turned counter-clockwise by `rotation`
        radians about the origin, then moved by `translation`. A negative
        `scale` mirrors through the origin."""
        self = Self(
            translation=translation,
            rotation=rotation,
            scale_x=scale,
            scale_y=scale,
        )

    def __init__(
        out self,
        *,
        translation: Vector = Vector.ZERO,
        rotation: Number = 0.0,
        scale_x: Number,
        scale_y: Number,
    ):
        """Stretched by `scale_x` across and `scale_y` up and down, then
        turned counter-clockwise by `rotation` radians about the origin, then
        moved by `translation`. A negative scale mirrors along its axis."""
        var c = cos(Float64(rotation))
        var s = sin(Float64(rotation))
        self._xx = c * Float64(scale_x)
        self._xy = 0.0 - s * Float64(
            scale_y
        )  # not -s * scale_y, which prints -0.0
        self._x0 = translation.x
        self._yx = s * Float64(scale_x)
        self._yy = c * Float64(scale_y)
        self._y0 = translation.y

    def __init__(
        out self,
        *,
        _xx: Float64,
        _xy: Float64,
        _x0: Float64,
        _yx: Float64,
        _yy: Float64,
        _y0: Float64,
    ):
        """The six numbers, for the library's own use."""
        self._xx = _xx
        self._xy = _xy
        self._x0 = _x0
        self._yx = _yx
        self._yy = _yy
        self._y0 = _y0

    def __init__(out self, matrix: Matrix[3, 3]) raises:
        """The transform `matrix` describes. Raises if `matrix`'s bottom row
        isn't `0 0 1`: such a matrix is a perspective transform, which a
        `Transform` can't hold."""
        if matrix[2, 0] != 0.0 or matrix[2, 1] != 0.0 or matrix[2, 2] != 1.0:
            raise Error(
                "Transform: the matrix's bottom row must be 0 0 1, not ",
                matrix[2, 0],
                " ",
                matrix[2, 1],
                " ",
                matrix[2, 2],
            )
        self._xx = matrix[0, 0]
        self._xy = matrix[0, 1]
        self._x0 = matrix[0, 2]
        self._yx = matrix[1, 0]
        self._yy = matrix[1, 1]
        self._y0 = matrix[1, 2]

    def __matmul__(self, rhs: Self) -> Self:
        """The transform that does `rhs` first, then `self`."""
        return Self(
            _xx=self._xx * rhs._xx + self._xy * rhs._yx,
            _xy=self._xx * rhs._xy + self._xy * rhs._yy,
            _x0=self._xx * rhs._x0 + self._xy * rhs._y0 + self._x0,
            _yx=self._yx * rhs._xx + self._yy * rhs._yx,
            _yy=self._yx * rhs._xy + self._yy * rhs._yy,
            _y0=self._yx * rhs._x0 + self._yy * rhs._y0 + self._y0,
        )

    def apply(self, point: Point) -> Point:
        """Where `point` ends up: turned, scaled and moved."""
        var p = self._apply_xy(point.x, point.y)
        return Point(p[0], p[1])

    def apply(self, vector: Vector) -> Vector:
        """`vector` turned, scaled and sheared, but not moved: a movement is
        the same wherever it starts, so the translation doesn't change it."""
        return Vector(
            self._xx * vector.x + self._xy * vector.y,
            self._yx * vector.x + self._yy * vector.y,
        )

    def _apply_xy(self, x: Float64, y: Float64) -> Tuple[Float64, Float64]:
        """The point `(x, y)` moved, as plain numbers, for the renderer's
        per-vertex loops."""
        return (
            self._xx * x + self._xy * y + self._x0,
            self._yx * x + self._yy * y + self._y0,
        )

    def inverse(self) -> Self:
        """The transform that undoes this one: it moves every point back to
        where it started.

        A transform that squashes everything onto a line or a point, such as
        `scale=0`, can't be undone, and its inverse holds meaningless numbers
        rather than raising an error."""
        var det = self._xx * self._yy - self._xy * self._yx
        var xx = self._yy / det
        var xy = -self._xy / det
        var yx = -self._yx / det
        var yy = self._xx / det
        return Self(
            _xx=xx,
            _xy=xy,
            _x0=-(xx * self._x0 + xy * self._y0),
            _yx=yx,
            _yy=yy,
            _y0=-(yx * self._x0 + yy * self._y0),
        )

    def __eq__(self, other: Self) -> Bool:
        return (
            self._xx == other._xx
            and self._xy == other._xy
            and self._x0 == other._x0
            and self._yx == other._yx
            and self._yy == other._yy
            and self._y0 == other._y0
        )

    def __ne__(self, other: Self) -> Bool:
        return not (self == other)

    def write_to[W: Writer](self, mut writer: W):
        # The full matrix is the only source form that holds every transform,
        # shears included.
        writer.write("Transform(", Matrix[3, 3](self), ")")
