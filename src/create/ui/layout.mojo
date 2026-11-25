"""`Column`, `Row` and `Space`: what places the widgets inside them in a
`UI`."""

from create.geometry import Rectangle
from create.math import Point
from create._optional import _OptionalFloat64


comptime _UNSIZED = Rectangle(Point(0.0, 0.0), 0.0, 0.0)
"""A rectangle with no size: the default of every widget's `rect`, which a
`UI` replaces with the size the widget prefers, or the slot it is given."""


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
        out self, rect: Rectangle = _UNSIZED, *, gap: _OptionalFloat64 = None
    ):
        self.rect = rect
        self.gap = gap._value


struct Row(Copyable, Movable):
    """Widgets side by side, from the left, each in a slot of its own as
    tall as the row. The slots share the row's width in proportion to
    `weights`, one for each widget, so `Row(1, 3)` gives the first a quarter
    of it and the second three quarters; with no weights, every widget gets
    an equal slot. A `gap` is left between each slot and the next.

    ```mojo
    # In `create`: a label and a slider for it, on one line of a column.
    var line = ui.add(Row(1, 3), list)
    _ = ui.add(Label("Volume", alignment=Align.LEFT), line)
    var volume = ui.add(Slider(0.8, 0, 1), line)
    ```

    In a column it is a strip as tall as its tallest widget, or `height`.
    It fills the inside of the panel it is in, and elsewhere, with no
    `rect` of its own, it is as big as what is inside it.
    """

    var rect: Rectangle
    """Where it is: given, or set by what it is in."""
    var weights: List[Float64]
    """How the slots share the width, left first; equal slots when
    empty."""
    var gap: Optional[Float64]
    """What is left between each slot and the next: the `UI`'s `spacing`
    when `None`."""
    var height: Optional[Float64]
    """How tall it is in a column: its tallest widget's height when
    `None`."""

    def __init__(
        out self,
        *weights: Float64,
        rect: Rectangle = _UNSIZED,
        gap: _OptionalFloat64 = None,
        height: _OptionalFloat64 = None,
    ):
        self.weights = []
        for weight in weights:
            self.weights.append(weight)
        self.rect = rect
        self.gap = gap._value
        self.height = height._value


struct Space(Copyable, Movable):
    """Room left empty in a column, or a row, such as to set one group of
    widgets apart from the next: twice the `UI`'s `spacing` unless given an
    `amount`."""

    var amount: Optional[Float64]

    def __init__(out self, amount: _OptionalFloat64 = None):
        self.amount = amount._value


def _sized(rect: Rectangle) -> Bool:
    """Whether `rect` has a size of its own, rather than being left for the
    `UI` to size."""
    return rect.width > 0 and rect.height > 0
