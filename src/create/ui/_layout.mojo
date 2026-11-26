"""What every widget and layout node shares about its size: `_UNSIZED`,
the size a widget leaves for its `UI` to choose, `_sized`, `_Placement`,
how a node fits in the column or row it is in, `_shares`, how a column or
row shares out its length, `_across`, where a node sits across it, and
`_overlap`, what two rectangles share."""

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


def _across(
    slot: Rectangle,
    size: Float64,
    align: Optional[Align],
    sized: Bool,
    column: Bool,
) -> Rectangle:
    """Where a node goes in `slot`, the strip of a column (`column`) or the
    slot of a row it is given. Placed by `align`, it is `size` across, at
    the side `align` names: a column reads its left or right, and a row its
    top or bottom, so `TOP_LEFT` in a column is its left. With no `align`,
    it stretches across the whole slot, unless it was `sized` across by
    `ui.add`, when it is centred."""
    if not align and not sized:
        return slot
    var x = slot.position.x
    var y = slot.position.y
    if align:
        var a = align.value()
        if column:
            if a == Align.LEFT or a == Align.TOP_LEFT or a == Align.BOTTOM_LEFT:
                x = slot.left() + size / 2
            elif (
                a == Align.RIGHT
                or a == Align.TOP_RIGHT
                or a == Align.BOTTOM_RIGHT
            ):
                x = slot.right() - size / 2
        else:
            if a == Align.TOP or a == Align.TOP_LEFT or a == Align.TOP_RIGHT:
                y = slot.top() - size / 2
            elif (
                a == Align.BOTTOM
                or a == Align.BOTTOM_LEFT
                or a == Align.BOTTOM_RIGHT
            ):
                y = slot.bottom() + size / 2
    if column:
        return Rectangle(Point(x, y), size, slot.height)
    return Rectangle(Point(x, y), slot.width, size)


def _overlap(a: Rectangle, b: Rectangle) -> Rectangle:
    """What two upright rectangles share, as the clips of scroll areas one inside
    another do: no size, where they meet or at `a`'s centre, when they don't
    overlap."""
    var left = max(a.left(), b.left())
    var right = max(min(a.right(), b.right()), left)
    var bottom = max(a.bottom(), b.bottom())
    var top = max(min(a.top(), b.top()), bottom)
    return Rectangle(
        Point((left + right) / 2, (bottom + top) / 2),
        right - left,
        top - bottom,
    )
