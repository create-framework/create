"""`_Layout`: an open panel, column or row, and how it hands out the
rectangles of what is called inside it."""

from create.geometry import Rectangle
from create.math import Point


comptime _PANEL = 0
comptime _COLUMN = 1
comptime _ROW = 2


struct _Layout(Copyable, Movable):
    """One open `ui.panel`, `ui.column` or `ui.row` block.

    A column hands out strips down its width, from `top`, each as tall as
    the widget asks; a row hands out the slots it was cut into when it
    opened. A panel hands out nothing to a widget, only its inside to a
    column or row opened directly in it. Every slot is known when it is
    asked for, so a widget knows where it is when it is called.
    """

    var kind: Int
    var rect: Rectangle
    var gap: Float64
    var top: Float64
    """A column's next free edge: where the next strip starts."""
    var slots: List[Rectangle]
    """A row's slots, left first."""
    var next: Int
    """A row's next free slot."""

    def __init__(
        out self,
        kind: Int,
        rect: Rectangle,
        gap: Float64,
        var slots: List[Rectangle] = [],
    ):
        self.kind = kind
        self.rect = rect
        self.gap = gap
        self.top = rect.top()
        self.slots = slots^
        self.next = 0

    def take(mut self, height: Float64, what: String) raises -> Rectangle:
        """The next slot, for something `height` tall named `what`: a strip
        of a column, or a row's next slot, whatever its height."""
        if self.kind == _COLUMN:
            var strip = Rectangle(
                Point(self.rect.position.x, self.top - height / 2),
                self.rect.width,
                height,
            )
            self.top -= height + self.gap
            return strip
        if self.kind == _ROW:
            if self.next >= len(self.slots):
                raise Error(
                    what
                    + ": the ui.row around it has "
                    + String(len(self.slots))
                    + " slots, and they are all taken; give the row more"
                    + " weights or columns"
                )
            self.next += 1
            return self.slots[self.next - 1]
        raise Error(
            what + ": give it a rect, or call it inside a ui.column or ui.row"
        )

    def take_rest(mut self, what: String) raises -> Rectangle:
        """All that is left, for a column or panel opened inside: the rest of a
        column, or a row's next slot."""
        if self.kind == _COLUMN:
            var height = max(self.top - self.rect.bottom(), 0.0)
            return self.take(height, what)
        return self.take(0.0, what)

    def space(mut self, amount: Float64) raises:
        """Leave `amount` of a column empty."""
        if self.kind != _COLUMN:
            raise Error("ui.space: call it inside a ui.column")
        self.top -= amount
