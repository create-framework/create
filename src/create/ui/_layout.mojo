"""What every widget and layout node shares about its size: `_UNSIZED`,
the size a widget leaves for its `UI` to choose, and `_sized`."""

from create.geometry import Rectangle
from create.math import Point


comptime _UNSIZED = Rectangle(Point(0.0, 0.0), 0.0, 0.0)
"""A rectangle with no size: the default of every widget's `rect`, which a
`UI` replaces with the size the widget prefers, or the slot it is given."""


def _sized(rect: Rectangle) -> Bool:
    """Whether `rect` has a size of its own, rather than being left for the
    `UI` to size."""
    return rect.width > 0 and rect.height > 0
