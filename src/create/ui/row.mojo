"""`Row`: widgets side by side in a `UI`."""

from create.geometry import Rectangle
from create.math import OptionalNumber
from create.render import Align
from ._layout import _UNSIZED


struct Row(Copyable, Movable):
    """Widgets side by side, from the left, each as tall as the row and as
    wide as it prefers, or as the `width` it was added with.

    A `gap` is left between each widget and the next. The room left over
    goes to the widgets added with a `grow`, shared in proportion to it:

    ```mojo
    # In `create`: a label and a slider for it, on one line of a column.
    var line = ui.add(Row(), list)
    _ = ui.add(Label("Volume", alignment=Align.LEFT), line)
    var volume = ui.add(Slider(0.8, 0, 1), line, grow=1)  # the rest
    ```

    `Row(align=Align.CENTER)` sets each widget at the height it prefers
    instead, centred; `Align.TOP` and `Align.BOTTOM` set them against an
    edge. A widget added with an `align` of its own goes by that instead.

    In a column it is a strip as tall as its tallest widget, or the
    `height` it was added with. It fills the inside of the panel it is in,
    and elsewhere, with no `rect` of its own, it is as big as what is
    inside it.
    """

    var rect: Rectangle
    """Where it is: given, or set by what it is in."""
    var align: Optional[Align]
    """Where its widgets sit across it, each as tall as it prefers: at
    the top, centre or bottom. Each stretches across it when `None`."""
    var gap: OptionalNumber
    """What is left between each widget and the next: the `UI`'s `spacing`
    when `None`."""

    def __init__(
        out self,
        rect: Rectangle = _UNSIZED,
        *,
        gap: OptionalNumber = None,
        align: Optional[Align] = None,
    ):
        self.rect = rect
        self.gap = gap._value
        self.align = align
