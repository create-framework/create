"""A settings menu made with a `UI`, with every kind of widget: labels, a
text field, a slider, checkboxes and the four kinds of button.

Click the widgets, or Tab through them and use Enter, Space and the arrows;
a gamepad's d-pad and A button work too. Escape leaves the text field, and
quits when nothing has focus.
"""

from create import *

comptime WIDTH = 420.0
comptime ROW = 52.0


@fieldwise_init
struct Menu(Program):
    var ui: UI
    var name: String
    var volume: Float64
    var music: Bool
    var dark: Bool
    var message: String

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> Menu:
        return Menu(UI(), "", 0.6, True, False, "")

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        if (
            context.keyboard.pressed(Key.ESCAPE)
            and not self.ui.wants_keyboard()
        ):
            context.quit()
        self.ui.theme(Theme.dark() if self.dark else Theme.light())
        canvas.background(self.ui.theme().colors.background)

        with self.ui.screen(context, canvas) as ui:
            with ui.panel(
                Rectangle((0, 0), WIDTH + 40, 7.6 * ROW),
                style=PanelStyle(shadow=True),
            ):
                var y = 3.0 * ROW
                ui.label(
                    "Settings",
                    Rectangle((0, y), WIDTH, 32.0),
                    style=LabelStyle(text_style=ui.theme().typography.title),
                )
                y -= ROW
                if ui.text_field(
                    self.name,
                    Rectangle((0, y), WIDTH, 44.0),
                    placeholder="Your name",
                    max_length=16,
                ).submitted:
                    self.message = "Hello, " + self.name
                y -= ROW
                ui.label(
                    "Volume",
                    Rectangle((-WIDTH / 2 + 50, y), 100.0, 24.0),
                    alignment=Align.LEFT,
                )
                _ = ui.slider(
                    self.volume,
                    0,
                    1,
                    Rectangle((60, y), WIDTH - 120, 32.0),
                    step=0.1,
                )
                y -= ROW
                # Each checkbox on a row of its own, its box lined up with
                # the field's left edge.
                var left = -WIDTH / 2
                _ = ui.checkbox(
                    "Music",
                    self.music,
                    Rectangle((left + 100, y), 200.0, 32.0),
                )
                y -= ROW * 0.8
                _ = ui.checkbox(
                    "Dark theme",
                    self.dark,
                    Rectangle((left + 100, y), 200.0, 32.0),
                )
                y -= ROW * 1.2
                var names = ["Play", "Load", "Credits", "Quit"]
                var variants = [
                    ButtonVariant.FILLED,
                    ButtonVariant.TONAL,
                    ButtonVariant.OUTLINED,
                    ButtonVariant.TEXT,
                ]
                for i in range(4):
                    var x = -WIDTH / 2 + WIDTH / 8 + Float64(i) * WIDTH / 4
                    if ui.button(
                        names[i],
                        Rectangle((x, y), WIDTH / 4 - 8, 44.0),
                        variant=variants[i],
                    ):
                        if i == 3:
                            context.quit()
                        self.message = "Pressed " + names[i]
                y -= ROW
                ui.label(
                    self.message,
                    Rectangle((0, y), WIDTH, 24.0),
                    style=LabelStyle(
                        color=ui.theme().colors.on_surface_variant
                    ),
                )


def main() raises:
    run[Menu]("UI", width=800, height=600)
