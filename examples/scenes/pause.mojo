from create import *
from scene import Scene

comptime COLORS = ColorScheme.dark()
comptime TEXT = COLORS.on_surface
comptime DIM = Color(0, 0, 0, 160)  # darkens the frozen game behind the menu
comptime BUTTONS = Rectangle((0, -40), 240, 100)


@fieldwise_init
struct Pause:
    """The pause scene, drawn over the game. `App` draws the game first,
    without moving it on, so this scene only dims it and adds a menu."""

    var ui: UI

    def update(
        mut self, mut context: Context, mut canvas: Canvas
    ) raises -> Scene:
        with canvas.style(fill=DIM, stroke_enabled=False):
            canvas.draw(canvas.bounds())
        with canvas.style(text_color=TEXT, font_size=48):
            canvas.text("Paused", (0, 80))

        var next = Scene.PAUSE
        if context.keyboard.pressed(Key.ESCAPE):
            next = Scene.PLAY
        with self.ui.screen(context, canvas, COLORS) as ui:
            with ui.column(BUTTONS):
                if ui.button("Resume"):
                    next = Scene.PLAY
                if ui.button("Menu", variant=ButtonVariant.TONAL):
                    next = Scene.TITLE
        return next
