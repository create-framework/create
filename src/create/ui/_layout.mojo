"""What every widget and layout node shares about its size: `_UNSIZED`,
the size a widget leaves for its `UI` to choose, `_sized`, and
`_Placement`, how a node fits in the column or row it is in."""

from create.geometry import Rectangle
from create.math import Point
from create.render import Align


comptime _UNSIZED = Rectangle(Point(0.0, 0.0), 0.0, 0.0)
"""A rectangle with no size: the default of every widget's `rect`, which a
`UI` replaces with the size the widget prefers, or the slot it is given."""


def _sized(rect: Rectangle) -> Bool:
    """Whether `rect` has a size of its own, rather than being left for the
    `UI` to size."""
    return rect.width > 0 and rect.height > 0


@fieldwise_init
struct _Placement(Copyable, Movable):
    """How a node fits in the column or row it is in, as `ui.add` was told:
    the size it starts from along each axis, how much of the room left over
    it takes, and where it sits across."""

    var grow: Float64
    """Its share of the room left over: none at 0."""
    var width: Optional[Float64]
    """The width it starts from, in place of the one it prefers."""
    var height: Optional[Float64]
    """The height it starts from, in place of the one it prefers."""
    var align: Optional[Align]
    """Where it sits across the column or row, in place of the column's or
    row's own `align`."""

    def __init__(out self):
        self.grow = 0
        self.width = None
        self.height = None
        self.align = None
