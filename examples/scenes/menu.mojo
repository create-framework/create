from create import *

comptime COLORS = ColorScheme.dark()


struct Menu(Movable):
    """Two buttons, one under the other, in a `UI` of their own: the first
    filled, the second tonal. Each scene with a menu keeps one."""

    var ui: UI
    var first: WidgetHandle[Button]
    var second: WidgetHandle[Button]

    def __init__(out self, first: String, second: String, area: Rectangle):
        """The buttons stacked in `area`, which they share."""
        var ui = UI()
        ui.colors(COLORS)
        var column = ui.add(Column(area))
        self.first = ui.add(Button(first), column)
        self.second = ui.add(Button(second, style=Button.TONAL), column)
        self.ui = ui^

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        """Update the buttons, then draw them."""
        self.ui.update(context, canvas)
        canvas.draw(self.ui)

    def first_clicked(self) -> Bool:
        return self.ui[self.first].released()

    def second_clicked(self) -> Bool:
        return self.ui[self.second].released()
