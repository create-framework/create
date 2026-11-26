"""A settings menu made with a `UI`, with every kind of widget: labels, a
text field, a slider, checkboxes, the four kinds of button, and a list of
levels in a scroll area.

The widgets are built once, in `create`, and the `UI` keeps them; each frame
it updates them all, then draws them, and the program asks them what
happened through the handles it kept.

Click the widgets, or Tab through them and use Enter, Space and the arrows;
a gamepad's d-pad and A button work too. Escape leaves the text field. Turn
the mouse wheel over the levels, or drag their scroll bar, to see the rest.
"""

from create import *

# the settings panel, tall enough for the column of widgets inside it
comptime PANEL = Rectangle((0, 0), 460, 510)
# how much of the list of levels shows at once: three and a half buttons,
# so the one cut in half says there are more
comptime LEVELS_HEIGHT = 3.5 * 40
# how far inside its surface the list of levels sits
comptime LEVELS_PADDING = 4
# a soft shadow, lifting the panel off the background
comptime SHADOW = Style(
    shadow=Color(0, 0, 0, 60), shadow_offset=Vector(0, -3), shadow_blur=12
)


def level_names() -> List[String]:
    """The levels to pick from: more than fit in their scroll area."""
    return ["Forest", "Caves", "River", "Castle", "Tower", "Sky", "Moon"]


@fieldwise_init
struct Menu(Program):
    var ui: UI
    var name: WidgetHandle[TextField]
    var volume: WidgetHandle[Slider]
    var music: WidgetHandle[Checkbox]
    var dark: WidgetHandle[Checkbox]
    var levels_surface: WidgetHandle[Panel]
    var levels: List[WidgetHandle[Button]]
    var buttons: List[WidgetHandle[Button]]
    var message: WidgetHandle[Label]

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> Menu:
        var ui = UI()
        var panel = ui.add(Panel(PANEL, style=SHADOW))
        # Each widget below takes the next place down the column.
        var column = ui.add(Column(), panel)
        _ = ui.add(Label("Settings", style=Style(font_size=22)), column)
        var name = ui.add(
            TextField(placeholder="Your name", max_length=16), column
        )
        var line = ui.add(Row(), column)
        # a quarter for the label, three quarters for the slider
        _ = ui.add(Label("Volume", alignment=Align.LEFT), line, width=0, grow=1)
        var volume = ui.add(Slider(0.6, 0, 1, step=0.1), line, width=0, grow=3)
        var music = ui.add(Checkbox("Music", checked=True), column)
        var dark = ui.add(Checkbox("Dark theme", checked=True), column)
        # the levels: a column of buttons, in a window that shows a few, on
        # a surface of its own so it stands out from the panel
        var pick = ui.add(Row(), column)
        _ = ui.add(Label("Level", alignment=Align.LEFT), pick, width=0, grow=1)
        var levels_surface = ui.add(
            Panel(padding=LEVELS_PADDING), pick, width=0, grow=3
        )
        var inside = ui.add(Column(), levels_surface)
        var window = ui.add(ScrollArea(max_height=LEVELS_HEIGHT), inside)
        var list = ui.add(Column(gap=0), window)
        var levels = List[WidgetHandle[Button]]()
        for name in level_names():
            levels.append(
                ui.add(Button(name, variant=ButtonVariant.TEXT), list)
            )
        _ = ui.add(Space(), column)
        var row = ui.add(Row(), column)
        var buttons = List[WidgetHandle[Button]]()
        # four equal slots: each starts from nothing and grows alike
        buttons.append(ui.add(Button("Play"), row, width=0, grow=1))
        buttons.append(
            ui.add(
                Button("Load", variant=ButtonVariant.TONAL),
                row,
                width=0,
                grow=1,
            )
        )
        buttons.append(
            ui.add(
                Button("Credits", variant=ButtonVariant.OUTLINED),
                row,
                width=0,
                grow=1,
            )
        )
        buttons.append(
            ui.add(
                Button("Quit", variant=ButtonVariant.TEXT),
                row,
                width=0,
                grow=1,
            )
        )
        var message = ui.add(Label(""), column)
        return Menu(
            ui^,
            name,
            volume,
            music,
            dark,
            levels_surface,
            levels^,
            buttons^,
            message,
        )

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        var dark = self.ui[self.dark].checked
        var colors = ColorScheme.dark() if dark else ColorScheme.light()
        self.ui.colors(colors)
        self.ui[self.levels_surface].style = Style(
            fill=colors.surface_container_highest
        )
        self.ui[self.message].style = Style(
            text_color=colors.on_surface_variant
        )
        canvas.background(colors.background)

        self.ui.update(context, canvas)
        canvas.draw(self.ui)

        if self.ui[self.name].submitted():
            var name = self.ui[self.name].text()
            self.ui[self.message].text = "Hello, " + name
        for level in self.levels:
            if self.ui[level].released():
                self.ui[self.message].text = "Level: " + self.ui[level].text
        for i in range(len(self.buttons)):
            if self.ui[self.buttons[i]].released():
                if i == len(self.buttons) - 1:
                    context.quit()
                var pressed = self.ui[self.buttons[i]].text
                self.ui[self.message].text = "Pressed " + pressed


def main() raises:
    run[Menu]("UI", width=800, height=600)
