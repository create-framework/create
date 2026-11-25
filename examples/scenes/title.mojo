from create import *
from menu import Menu
from scene import Scene

comptime COLORS = ColorScheme.dark()
comptime BACKGROUND = COLORS.background
comptime TEXT = COLORS.on_surface
comptime HINT = COLORS.on_surface_variant
comptime BUTTONS = Rectangle((0, -60), 240, 100)


struct Title(Movable):
    """The title scene: the game's name, the best score so far, and buttons
    to play or quit."""

    var menu: Menu

    def __init__(out self):
        self.menu = Menu("Play", "Quit", BUTTONS)

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

        self.menu.update(context, canvas)
        if self.menu.second_clicked():
            context.quit()
        if self.menu.first_clicked():
            return Scene.PLAY
        return Scene.TITLE
