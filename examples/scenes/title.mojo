from create import *
from scene import Scene

comptime COLORS = ColorScheme.dark()
comptime BACKGROUND = COLORS.background
comptime TEXT = COLORS.on_surface
comptime HINT = COLORS.on_surface_variant
comptime BUTTONS = Rectangle((0, -60), 240, 100)


@fieldwise_init
struct Title:
    """The title scene: the game's name, the best score so far, and buttons
    to play or quit."""

    var ui: UI

    def update(
        mut self, mut context: Context, mut canvas: Canvas, best: Int
    ) raises -> Scene:
        """`best` belongs to `App`, which keeps it across every round, so it
        comes in as an argument rather than living here."""
        canvas.background(BACKGROUND)
        with canvas.style(text_color=TEXT, font_size=64):
            canvas.text("Catch", (0, 120))
        with canvas.style(text_color=HINT, font_size=20):
            canvas.text("Best: " + String(best), (0, 50))

        var next = Scene.TITLE
        with self.ui.screen(context, canvas, COLORS) as ui:
            with ui.column(BUTTONS):
                if ui.button("Play"):
                    next = Scene.PLAY
                if ui.button("Quit", variant=ButtonVariant.TONAL):
                    context.quit()
        return next
