from create import *

comptime COLORS = ColorScheme.dark()
comptime BACKGROUND = COLORS.background
comptime INK = Color.MAGENTA
comptime HINT = COLORS.on_surface_variant


@fieldwise_init
struct Paint:
    """The painting scene. Left-drag paints, right-click returns to the menu.

    `App.create` turns autoclear off, and this scene never paints a
    background in `update`, so the ink builds up from frame to frame.
    `enter`, which `App` calls on the frame it switches here, makes the
    scene clear the frame once, so the menu doesn't show under the first
    stroke.
    """

    var back_pressed: Bool
    var entering: Bool

    def enter(mut self):
        self.entering = True

    def update(mut self, context: Context, mut canvas: Canvas) raises:
        self.back_pressed = context.mouse.pressed(MouseButton.RIGHT)

        if self.entering:
            canvas.background(BACKGROUND)
            self.entering = False

        if context.mouse.down(MouseButton.LEFT):
            with canvas.style(fill=INK, stroke_enabled=False):
                canvas.circle(context.mouse.position, 14.0)

        # Align.BOTTOM anchors the text box's bottom edge at y, so it grows
        # upward from the margin instead of straddling it; the default
        # Align.CENTER would hang half the line below the margin, its
        # descenders against canvas.bottom() and the letterbox clip.
        with canvas.style(
            text_color=HINT,
            font_size=18,
            text_alignment=Align.BOTTOM,
        ):
            canvas.text(
                "Left-drag to paint   Right-click for the menu",
                (0, canvas.bottom() + 14.0),
            )
