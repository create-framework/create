"""The traits every shape and curve shares: `Geometry`, and its two kinds,
`Shape` (with an inside) and `Curve` (without one).

They describe the values and the tests between them, never how they are
drawn: `render` decides that, so collision code never sees a canvas.
"""

from .bezier import Bezier
from .rectangle import Rectangle
from create.math import Point
from create.math import Vector


trait Geometry(Copyable, Deinitable):
    """A piece of geometry: a `Shape` or a `Curve`. What every one of them
    answers, whichever it is, and a plain value generic code can keep, copy
    and drop. Tests between two of them (`contains`, `intersects`,
    `overlaps`) are methods overloaded per type they take, not part of
    this."""

    def bounds(self) -> Rectangle:
        """The tightest axis-aligned rectangle around it."""
        ...

    def closest_point(self, p: Point) -> Point:
        """Its point nearest `p`: `p` itself inside a `Shape`."""
        ...

    def translate(self, delta: Vector) -> Self:
        """It moved by `delta`; this one is unchanged."""
        ...


trait Shape(Geometry):
    """Geometry with an inside: `Rectangle`, `Circle`, `Ellipse`, `Capsule`,
    `Triangle`, `Sector` and `Polygon`, the types of `overlaps` and
    `contains`, and what `canvas.clip` takes. A curve has no inside, so it is
    not one."""

    def center(self) -> Point:
        ...

    def area(self) -> Float64:
        ...

    def contains(self, p: Point) -> Bool:
        """Whether `p` is inside, its boundary included."""
        ...

    def move_to(self, position: Point) -> Self:
        """The shape moved so its `position` (or, without one, its
        `center()`) is at `position`; this one is unchanged."""
        ...


trait Curve(Geometry):
    """Geometry with no inside, traced from one end to the other: `Line`,
    `Arc`, `Bezier` and `Spline`. A straight line is a curve too, as in
    mathematics.

    `t` runs from 0 at the start to 1 at the end; only on a `Line` and an
    `Arc` is it proportional to distance, which `at_distance` always is."""

    def at(self, t: Float64) -> Point:
        """The point at parameter `t`."""
        ...

    def tangent(self, t: Float64) -> Vector:
        """The derivative at `t`: the direction of travel, with the speed
        per unit of `t` as its magnitude."""
        ...

    def length(self) -> Float64:
        """The distance along the curve from start to end."""
        ...

    def at_distance(self, distance: Float64) -> Point:
        """The point `distance` along the curve from its start, clamped to
        its ends."""
        ...

    def flatten(self, tolerance: Float64) -> List[Point]:
        """Points along the curve, start to end, whose straight segments
        stray from it by at most `tolerance`."""
        ...

    def beziers(self) -> List[Bezier]:
        """The curve as cubic Béziers, each ending where the next starts."""
        ...
