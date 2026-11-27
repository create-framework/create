from .number import Number
from std.math import atan2, cos, sin, sqrt
from .constants import PI

from .point import Point


struct Vector(Copyable, Equatable, ImplicitlyCopyable, Movable, Writable):
    """A 2D displacement or direction: arithmetic operators, `magnitude`, `normalize`,
    `dot`, `distance`, `lerp`, the angle helpers `from_angle`, `angle` and
    `rotate`, the length helpers `with_length` and `limit`, and an explicit
    constructor from a `Point`.

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
    """

    var x: Float64
    var y: Float64

    def __init__(out self, x: Number, y: Number):
        self.x = Float64(x)
        self.y = Float64(y)

    def __init__(out self, t: Tuple[Float64, Float64]):
        self = Vector(t[0], t[1])

    def __init__(out self, p: Point):
        """The displacement from the origin to `p`."""
        self = Vector(p.x, p.y)

    def __add__(self, other: Vector) -> Vector:
        return Vector(self.x + other.x, self.y + other.y)

    def __sub__(self, other: Vector) -> Vector:
        return Vector(self.x - other.x, self.y - other.y)

    def __mul__(self, s: Number) -> Vector:
        var factor = Float64(s)
        return Vector(self.x * factor, self.y * factor)

    def __rmul__(self, s: Number) -> Vector:
        """`s * v`, the same as `v * s`, so a formula reads as written."""
        return self * s

    def __truediv__(self, s: Number) -> Vector:
        var divisor = Float64(s)
        return Vector(self.x / divisor, self.y / divisor)

    def __neg__(self) -> Vector:
        return Vector(-self.x, -self.y)

    def __iadd__(mut self, other: Vector):
        self.x += other.x
        self.y += other.y

    def __isub__(mut self, other: Vector):
        self.x -= other.x
        self.y -= other.y

    def __imul__(mut self, s: Number):
        self.x *= Float64(s)
        self.y *= Float64(s)

    def __itruediv__(mut self, s: Number):
        self.x /= Float64(s)
        self.y /= Float64(s)

    def __eq__(self, other: Vector) -> Bool:
        return self.x == other.x and self.y == other.y

    def __ne__(self, other: Vector) -> Bool:
        return not (self == other)

    def write_to[W: Writer](self, mut writer: W):
        writer.write("Vector(", self.x, ", ", self.y, ")")

    def magnitude(self) -> Float64:
        """How long it is: `Vector(3, 4).magnitude()` is 5, by Pythagoras'
        theorem."""
        return sqrt(self.x * self.x + self.y * self.y)

    def magnitude_squared(self) -> Float64:
        """The square of `magnitude`, without its square root: a little
        faster, and enough to compare lengths."""
        return self.x * self.x + self.y * self.y

    def normalize(self) -> Vector:
        """The vector pointing the same way, 1 long: its direction alone.
        The zero vector has no direction and gives NaN, so check
        `magnitude()` first where it can be zero."""
        var m = self.magnitude()
        return Vector(self.x / m, self.y / m)

    def dot(self, other: Vector) -> Float64:
        """The dot product: how much the two point the same way. For two
        vectors 1 long, 1 when they point the same way, 0 at right angles
        and -1 when opposite."""
        return self.x * other.x + self.y * other.y

    def distance(self, other: Vector) -> Float64:
        """The length of the difference between the two vectors."""
        return (self - other).magnitude()

    def distance_squared(self, other: Vector) -> Float64:
        """The square of `distance`, without its square root."""
        return (self - other).magnitude_squared()

    def lerp(self, other: Vector, t: Number) -> Vector:
        """A new vector `t` of the way from this one to `other`; this one is
        unchanged. Not clamped: `t` outside 0..1 carries on past either end.
        """
        var u = Float64(t)
        return Vector(
            self.x + (other.x - self.x) * u, self.y + (other.y - self.y) * u
        )

    @staticmethod
    def from_angle(angle: Number, length: Number = 1.0) -> Vector:
        """The vector of `length` pointing at `angle` radians,
        counter-clockwise from +x: `from_angle(0)` is `RIGHT`."""
        var turn = Float64(angle)
        var size = Float64(length)
        return Vector(cos(turn) * size, sin(turn) * size)

    def angle(self) -> Float64:
        """The heading in radians, counter-clockwise from +x, in
        `[-PI, PI]`. `0` for the zero vector."""
        return atan2(self.y, self.x)

    def rotate(self, angle: Number) -> Vector:
        """This vector turned by `angle` radians, counter-clockwise; its
        length is unchanged."""
        var turn = Float64(angle)
        var c = cos(turn)
        var s = sin(turn)
        return Vector(self.x * c - self.y * s, self.x * s + self.y * c)

    def with_length(self, length: Number) -> Vector:
        """This direction at `length`. The zero vector has no direction and
        gives NaN, as with `normalize`."""
        return self * (Float64(length) / self.magnitude())

    def limit(self, max_length: Number) -> Vector:
        """This vector, shortened to `max_length` if it is longer: a speed
        cap. Shorter vectors, the zero vector among them, are unchanged."""
        var cap = Float64(max_length)
        var length_squared = self.magnitude_squared()
        if length_squared <= cap * cap:
            return self
        return self * (cap / sqrt(length_squared))

    def xy(self) -> Tuple[Float64, Float64]:
        """Its two numbers as a pair, to unpack: `var (x, y) = v.xy()`."""
        return (self.x, self.y)

    comptime ZERO = Vector(0.0, 0.0)
    comptime ONE = Vector(1.0, 1.0)

    comptime UP = Vector(0.0, 1.0)
    comptime DOWN = Vector(0.0, -1.0)
    comptime LEFT = Vector(-1.0, 0.0)
    comptime RIGHT = Vector(1.0, 0.0)
