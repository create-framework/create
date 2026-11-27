"""`Curve`, the kind of `Geometry` without an inside, traced from one end
to the other."""

from .bezier import Bezier
from .geometry import Geometry
from create.math import Number, Point
from create.math import Vector


trait Curve(Geometry):
    """Geometry with no inside, traced from one end to the other: `Line`,
    `Arc`, `Bezier` and `Spline`. A straight line is a curve too, as in
    mathematics.

    `t` runs from 0 at the start to 1 at the end; only on a `Line` and an
    `Arc` is it proportional to distance, which `at_distance` always is."""

    def at(self, t: Number) -> Point:
        """The point at parameter `t`."""
        ...

    def tangent(self, t: Number) -> Vector:
        """The derivative at `t`: the direction of travel, with the speed
        per unit of `t` as its magnitude."""
        ...

    def length(self) -> Float64:
        """The distance along the curve from start to end."""
        ...

    def at_distance(self, distance: Number) -> Point:
        """The point `distance` along the curve from its start, clamped to
        its ends."""
        ...

    def flatten(self, tolerance: Number) -> List[Point]:
        """Points along the curve, start to end, whose straight segments
        stray from it by at most `tolerance`."""
        ...

    def beziers(self) -> List[Bezier]:
        """The curve as cubic Béziers, each ending where the next starts."""
        ...
