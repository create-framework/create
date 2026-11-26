"""`Geometry`, the trait every shape and curve shares.

It describes the values and the tests between them, never how they are
drawn: `render` decides that, so collision code never sees a canvas.
"""

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
