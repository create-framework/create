"""A menu made with a `UI` that shows every kind of widget, on four tabs:
Buttons, the four kinds of button; Toggles, checkboxes, switches and a
choice group; Values, a text field, a slider, a number field and a progress
bar; and Lists, a dropdown and a list in a scroll area. Labels and panels
sit around them, and a few have tooltips.

Each page is built in a file of its own (`buttons.mojo`, `toggles.mojo`,
`values.mojo` and `lists.mojo`), as a struct that adds its widgets to the
`UI` and reports what the player did to them. This file builds the panel,
the tabs and a column for each page, shows the selected tab's page, and
shows what the pages report in a line at the foot.

Click the widgets, or Tab through them and use Enter, Space and the arrows;
a gamepad's d-pad and A button work too. Left and right switch the tabs.
Up and down move the choice group's choice, step the number field, and move
through the dropdown's list once Enter opens it; Escape closes it. Rest the
pointer on a widget with a tooltip, or give it focus from the keyboard, to
see it. Turn the mouse wheel over the levels, or drag their scroll bar, to
see the rest.
"""

from create import *
from buttons import ButtonsPage
from toggles import TogglesPage
from values import ValuesPage
from lists import ListsPage

# the menu's panel, tall enough for its tallest page
comptime PANEL = Rectangle((0, 0), 500, 460)
# a soft shadow, lifting the panel off the background
comptime SHADOW = Style(
    shadow=Color(0, 0, 0, 60), shadow_offset=Vector(0, -3), shadow_blur=12
)


@fieldwise_init
struct Menu(Program):
    var ui: UI
    var tabs: WidgetHandle[Tabs]
    var pages: List[WidgetHandle[Column]]
    var buttons: ButtonsPage
    var toggles: TogglesPage
    var values: ValuesPage
    var lists: ListsPage
    var message: WidgetHandle[Label]

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> Menu:
        var ui = UI()
        var panel = ui.add(Panel(PANEL, style=SHADOW))
        var column = ui.add(Column(), panel)
        _ = ui.add(Label("Widgets", style=Style(font_size=22)), column)
        var tabs = ui.add(
            Tabs(["Buttons", "Toggles", "Values", "Lists"]), column
        )
        # a column per tab, in the same place: only the selected one shows
        var pages = List[WidgetHandle[Column]]()
        for i in range(4):
            pages.append(ui.add(Column(), column))
            ui.visible(pages[i], i == 0)
        var buttons = ButtonsPage(ui, pages[0])
        var toggles = TogglesPage(ui, pages[1])
        var values = ValuesPage(ui, pages[2])
        var lists = ListsPage(ui, pages[3])
        # what the pages report, at the foot of the panel whatever the page
        _ = ui.add(Space(), column, grow=1)
        var message = ui.add(Label(""), column)
        return Menu(
            ui^,
            tabs,
            pages^,
            buttons^,
            toggles^,
            values^,
            lists^,
            message,
        )

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        var dark = self.toggles.dark_theme(self.ui)
        var colors = ColorScheme.dark() if dark else ColorScheme.light()
        self.ui.colors(colors)
        self.ui[self.message].style = Style(
            text_color=colors.on_surface_variant
        )
        canvas.background(colors.background)

        self.ui.update(context, canvas)
        canvas.draw(self.ui)

        # show the selected tab's page
        if self.ui[self.tabs].changed():
            var selected = self.ui[self.tabs].selected
            for i in range(len(self.pages)):
                self.ui.visible(self.pages[i], i == selected)
        # each page reports what the player did to it, if anything
        var reports = [
            self.buttons.update(self.ui),
            self.toggles.update(self.ui),
            self.values.update(self.ui),
            self.lists.update(self.ui, colors),
        ]
        for report in reports:
            if report:
                self.ui[self.message].text = report.value()
        if self.buttons.quit(self.ui):
            context.quit()


def main() raises:
    run[Menu]("UI", width=800, height=600)
