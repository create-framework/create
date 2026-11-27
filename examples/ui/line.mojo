"""`line`, the layout every page of the menu shares: a name on the left and
a widget beside it."""

from create import *


def line(
    mut ui: UI, page: WidgetHandle[Column], name: String
) -> WidgetHandle[Row]:
    """A line of `page`: `name` on the left, in a quarter of it, leaving the
    rest for the widget the caller adds to it with `width=0, grow=3`."""
    var row = ui.add(Row(), page)
    _ = ui.add(Label(name, alignment=Align.LEFT), row, width=0, grow=1)
    return row
