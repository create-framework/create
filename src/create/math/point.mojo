from .vector import Vector


struct Point(Copyable, Equatable, ImplicitlyCopyable, Movable, Writable):
    """A location in world space: `distance`, `lerp`, the affine operators, and
    an explicit constructor from a `Vector` for crossing between the two.

    Every position in the library is one of these —
    `canvas.circle(position, r)`, `Rectangle.center()`, `context.mouse.position` — and no
    signature takes a location as a loose x/y pair instead. The tuple constructors are `@implicit`, so
    `canvas.circle((0, 0), 20)` works without naming the type and a program
    only spells `Point` when it is storing one. It is the only type here
    that converts from a bare tuple, which is what keeps that unambiguous.

    The surface is strictly affine, which is the whole point of the type
    existing beside `Vector`: subtracting two positions gives the
    displacement between them (`Vector`), and adding a displacement to a
    position gives another position. `magnitude`, `normalize`, `dot`, scalar `*`,
    unary `-` and `Point + Point` are absent on purpose — none of them
    means anything for a location, and `position.normalize()` compiling was the
    mistake this split exists to catch. A program that genuinely wants a
    position's components as a direction says so: `Vector(p)`.

    A displacement is always named: `p + Vector(1, 2)` moves a position.
    Mind `p - (1, 2)`: the tuple can only become a `Point`, so it is the
    displacement from `(1, 2)` to `p` -- a `Vector`, not a moved position.
    Moving backwards is `p - Vector(1, 2)`.

    There are no `zero()`/`one()` factories either. `(0, 0)` through the
    implicit constructor is shorter than any name for the origin, and `one()`
    has no meaning for a position at all.

    Crossing to another type is an explicit constructor, never an implicit
    one: `Vector(p)` is the displacement from the origin to `p`,
    and `Point(v)` the origin moved by `v`. Naming
    the target type is what keeps the conversion visible; an `@implicit` one
    would undo the split. `xy` returns the components as a plain tuple, to
    destructure: `var (x, y) = p.xy()`.
    """

    var x: Float64
    var y: Float64

    def __init__(out self, x: Float64, y: Float64):
        self.x = x
        self.y = y

    def __init__(out self, x: Int, y: Int):
        self = Point(Float64(x), Float64(y))

    @implicit
    def __init__(out self, t: Tuple[Float64, Float64]):
        self = Point(t[0], t[1])

    @implicit
    def __init__(out self, t: Tuple[Int, Int]):
        self = Point(Float64(t[0]), Float64(t[1]))

    @implicit
    def __init__(out self, t: Tuple[Int, Float64]):
        self = Point(Float64(t[0]), t[1])

    @implicit
    def __init__(out self, t: Tuple[Float64, Int]):
        self = Point(t[0], Float64(t[1]))

    def __init__(out self, v: Vector):
        """The origin moved by `v`: the position `v` points to."""
        self = Point(v.x, v.y)

    def __sub__(self, other: Point) -> Vector:
        """The displacement from `other` to `self`."""
        return Vector(self.x - other.x, self.y - other.y)

    def __add__(self, v: Vector) -> Point:
        return Point(self.x + v.x, self.y + v.y)

    def __sub__(self, v: Vector) -> Point:
        return Point(self.x - v.x, self.y - v.y)

    def __iadd__(mut self, v: Vector):
        self.x += v.x
        self.y += v.y

    def __isub__(mut self, v: Vector):
        self.x -= v.x
        self.y -= v.y

    def __eq__(self, other: Point) -> Bool:
        return self.x == other.x and self.y == other.y

    def __ne__(self, other: Point) -> Bool:
        return not (self == other)

    def write_to[W: Writer](self, mut writer: W):
        writer.write("Point(", self.x, ", ", self.y, ")")

    def distance(self, other: Point) -> Float64:
        return (self - other).magnitude()

    def distance_squared(self, other: Point) -> Float64:
        return (self - other).magnitude_squared()

    def lerp(self, other: Point, t: Float64) -> Point:
        """A new point `t` of the way from this one to `other`; this one is
        unchanged. Not clamped: `t` outside 0..1 carries on past either end.
        """
        return Point(
            self.x + (other.x - self.x) * t, self.y + (other.y - self.y) * t
        )

    def xy(self) -> Tuple[Float64, Float64]:
        return (self.x, self.y)
