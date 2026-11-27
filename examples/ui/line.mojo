"""`line`, the layout every page of the menu shares: a name on the left and
a widget beside it."""

from create import *


def line(
    mut ui: UI, page: WidgetHandle[Column], name: String
) -> WidgetHandle[Row]:
    """A line of `page`: `name` on the left, in a quarter of it, leaving the
    rest for the widget the caller adds to it with `width=0, grow=3`.

    The name is as tall as a control and set against the top of the line,
    so it lines up with the widget's first row, such as a choice group's
    first option, and every line is at least a control tall."""
    var row = ui.add(Row(), page)
    _ = ui.add(
        Label(name),
        row,
        width=0,
        height=ui.control_height(),
        grow=1,
        align=Align.TOP,
    )
    return row
