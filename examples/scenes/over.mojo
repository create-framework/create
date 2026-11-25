from create import *
from menu import Menu
from scene import Scene

comptime COLORS = ColorScheme.dark()
comptime BACKGROUND = COLORS.background
comptime TEXT = COLORS.on_surface
comptime HINT = COLORS.on_surface_variant
comptime BUTTONS = Rectangle((0, -60), 240, 100)


struct Over(Movable):
    """The game-over scene: the round's score, and whether it beat the best.

    `enter` hands it the numbers as the round ends, so it keeps its own copy
    and needs nothing from the game afterwards.
    """

    var menu: Menu
    var score: Int
    var previous_best: Int

    def __init__(out self):
        self.menu = Menu("Play again", "Menu", BUTTONS)
        self.score = 0
        self.previous_best = 0

    def enter(mut self, score: Int, previous_best: Int):
        self.score = score
        self.previous_best = previous_best

    def update(
        mut self, mut context: Context, mut canvas: Canvas
    ) raises -> Scene:
        canvas.background(BACKGROUND)
        with canvas.style(text_color=TEXT, font_size=48):
            canvas.text("Score: " + String(self.score), (0, 120))
        with canvas.style(text_color=HINT, font_size=20):
            if self.score > self.previous_best:
                canvas.text("A new best!", (0, 50))
            else:
                canvas.text("Best: " + String(self.previous_best), (0, 50))

        self.menu.update(context, canvas)
        if self.menu.first_clicked():
            return Scene.PLAY
        if self.menu.second_clicked():
            return Scene.TITLE
        return Scene.OVER
