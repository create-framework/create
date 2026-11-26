"""`Column`: widgets one under the other in a `UI`."""

from create.geometry import Rectangle
from create.math import OptionalNumber
from ._layout import _UNSIZED


struct Column(Copyable, Movable):
    """Widgets one under the other, from the top down, each across the
    column's whole width and as tall as it prefers: a button or a slider
    the `UI`'s `control_height`, a label one and a half times its text's
    size. A `gap` is left between each and the next.

    ```mojo
    # In `create`, building the `ui` field: a settings card.
    var card = ui.add(Panel())
    var list = ui.add(Column(), card)
    _ = ui.add(Label("Volume"), list)
    var volume = ui.add(Slider(0.8, 0, 1), list)
    var done = ui.add(Button("Done"), list)
    ```

    It fills the inside of the panel it is in, or the slot a column or row
    gives it. Elsewhere, with no `rect` of its own, it is as big as what is
    inside it, centred on its `rect`'s position. It draws nothing itself,
    and the pointer passes through it.
    """

    var rect: Rectangle
    """Where it is: given, or set by what it is in."""
    var gap: Optional[Float64]
    """What is left between each widget and the next: the `UI`'s `spacing`
    when `None`."""

    def __init__(
        out self, rect: Rectangle = _UNSIZED, *, gap: OptionalNumber = None
    ):
        self.rect = rect
        self.gap = gap._value
