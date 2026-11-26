"""A settings menu made with a `UI`, with every kind of widget: labels, a
text field, a slider, checkboxes and the four kinds of button.

The widgets are built once, in `create`, and the `UI` keeps them; each frame
it updates them all, then draws them, and the program asks them what
happened through the handles it kept.

Click the widgets, or Tab through them and use Enter, Space and the arrows;
a gamepad's d-pad and A button work too. Escape leaves the text field.
"""

from create import *

# the settings panel, tall enough for the column of widgets inside it
comptime PANEL = Rectangle((0, 0), 460, 360)
# a soft shadow, lifting the panel off the background
comptime SHADOW = Style(
    shadow=Color(0, 0, 0, 60), shadow_offset=Vector(0, -3), shadow_blur=12
)


@fieldwise_init
struct Menu(Program):
    var ui: UI
    var name: WidgetHandle[TextField]
    var volume: WidgetHandle[Slider]
    var music: WidgetHandle[Checkbox]
    var dark: WidgetHandle[Checkbox]
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
        return Menu(ui^, name, volume, music, dark, buttons^, message)

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        var dark = self.ui[self.dark].checked
        var colors = ColorScheme.dark() if dark else ColorScheme.light()
        self.ui.colors(colors)
        self.ui[self.message].style = Style(
            text_color=colors.on_surface_variant
        )
        canvas.background(colors.background)

        self.ui.update(context, canvas)
        canvas.draw(self.ui)

        if self.ui[self.name].submitted():
            var name = self.ui[self.name].text()
            self.ui[self.message].text = "Hello, " + name
        for i in range(len(self.buttons)):
            if self.ui[self.buttons[i]].released():
                if i == len(self.buttons) - 1:
                    context.quit()
                var pressed = self.ui[self.buttons[i]].text
                self.ui[self.message].text = "Pressed " + pressed


def main() raises:
    run[Menu]("UI", width=800, height=600)
