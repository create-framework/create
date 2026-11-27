"""`Shape`, the kind of `Geometry` with an inside."""

from .geometry import Geometry
from create.math import Point


trait Shape(Geometry):
    """Geometry with an inside: `Rectangle`, `Circle`, `Ellipse`, `Capsule`,
    `Triangle`, `Sector` and `Polygon`, the types of `overlaps` and
    `contains`, and what `canvas.clip` takes. A curve has no inside, so it is
    not one."""

    def center(self) -> Point:
        """Its centre: where `move_to` puts `position` for a shape without
        a `position` of its own."""
        ...

    def area(self) -> Float64:
        """How much room it covers, in square units, its rounded corners
        taken into account."""
        ...

    def contains(self, p: Point) -> Bool:
        """Whether `p` is inside, its boundary included."""
        ...

    def move_to(self, position: Point) -> Self:
        """The shape moved so its `position` (or, without one, its
        `center()`) is at `position`; this one is unchanged."""
        ...
