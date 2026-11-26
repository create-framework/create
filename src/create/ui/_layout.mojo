"""What every widget and layout node shares about its size: `_UNSIZED`,
the size a widget leaves for its `UI` to choose, `_sized`, `_Placement`,
how a node fits in the column or row it is in, and `_shares`, how a column
or row shares out its length."""

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


def _shares(
    bases: List[Float64], grows: List[Float64], length: Float64, gap: Float64
) -> List[Float64]:
    """The lengths of the slots a column or row `length` long gives its
    children, with `gap` between each and the next: each child's `bases`
    length, and the room left over shared among them in proportion to their
    `grows`. With no room left over, or no child that grows, each has its
    base alone."""
    var lengths = bases.copy()
    var left = length - gap * Float64(max(len(bases) - 1, 0))
    var total_grow = 0.0
    for i in range(len(bases)):
        left -= bases[i]
        total_grow += grows[i]
    if left > 0 and total_grow > 0:
        for i in range(len(lengths)):
            lengths[i] += left * grows[i] / total_grow
    return lengths^
