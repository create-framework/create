"""`Shape`, the kind of `Geometry` with an inside."""

from .geometry import Geometry
from create.math import Point


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
