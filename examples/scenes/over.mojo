from create import *
from scene import Scene

comptime COLORS = ColorScheme.dark()
comptime BACKGROUND = COLORS.background
comptime TEXT = COLORS.on_surface
comptime HINT = COLORS.on_surface_variant
comptime BUTTONS = Rectangle((0, -60), 240, 100)


@fieldwise_init
struct Over:
    """The game-over scene: the round's score, and whether it beat the best.

    `enter` hands it the numbers as the round ends, so it keeps its own copy
    and needs nothing from the game afterwards.
    """

    var ui: UI
    var score: Int
    var previous_best: Int

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

        var next = Scene.OVER
        with self.ui.screen(context, canvas, COLORS) as ui:
            with ui.column(BUTTONS):
                if ui.button("Play again"):
                    next = Scene.PLAY
                if ui.button("Menu", variant=ButtonVariant.TONAL):
                    next = Scene.TITLE
        return next
