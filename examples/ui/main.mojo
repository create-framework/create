"""A settings menu made with a `UI`, with every kind of widget: labels, a
text field, a slider, checkboxes and the four kinds of button.

Click the widgets, or Tab through them and use Enter, Space and the arrows;
a gamepad's d-pad and A button work too. Escape leaves the text field, and
quits when nothing has focus.
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
    var colors: ColorScheme
    var name: String
    var volume: Float64
    var music: Bool
    var dark: Bool
    var message: String

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> Menu:
        return Menu(UI(), ColorScheme.light(), "", 0.6, True, False, "")

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        if (
            context.keyboard.pressed(Key.ESCAPE)
            and not self.ui.wants_keyboard()
        ):
            context.quit()
        self.colors = ColorScheme.dark() if self.dark else ColorScheme.light()
        canvas.background(self.colors.background)

        with self.ui.screen(context, canvas, self.colors) as ui:
            with ui.panel(PANEL, style=SHADOW):
                # Each widget below takes the next place down the column.
                with ui.column():
                    ui.label("Settings", style=Style(font_size=22))
                    ui.text_field(
                        self.name, placeholder="Your name", max_length=16
                    )
                    if ui.submitted():
                        self.message = "Hello, " + self.name
                    with ui.row(1, 3):  # a quarter for the label
                        ui.label("Volume", alignment=Align.LEFT)
                        ui.slider(self.volume, 0, 1, step=0.1)
                    ui.checkbox("Music", self.music)
                    ui.checkbox("Dark theme", self.dark)
                    ui.space()
                    var names = ["Play", "Load", "Credits", "Quit"]
                    var variants = [
                        ButtonVariant.FILLED,
                        ButtonVariant.TONAL,
                        ButtonVariant.OUTLINED,
                        ButtonVariant.TEXT,
                    ]
                    with ui.row(columns=4):
                        for i in range(4):
                            if ui.button(names[i], variant=variants[i]):
                                if i == 3:
                                    context.quit()
                                self.message = "Pressed " + names[i]
                    ui.label(
                        self.message,
                        style=Style(text_color=self.colors.on_surface_variant),
                    )


def main() raises:
    run[Menu]("UI", width=800, height=600)
