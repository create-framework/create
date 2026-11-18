from create import *


@fieldwise_init
struct Menu:
    """The menu scene: a plain struct with an `update`, not a `Program`.

    `App` reads `start_pressed` after calling `update`, as it would read any
    other field, and switches scene when it is set.
    """

    var start_pressed: Bool

    def update(mut self, context: Context, mut canvas: Canvas) raises:
        self.start_pressed = context.mouse.pressed()

        canvas.background(Color(40, 40, 44))
        with canvas.style(
            text_color=Color(240, 236, 222),
            font_size=48,
            text_alignment=Align.TOP,
        ):
            canvas.text("Scenes", (0, 40))
        with canvas.style(
            text_color=Color(176, 172, 162),
            font_size=20,
            text_alignment=Align.TOP,
        ):
            canvas.text("Click to start painting", (0, -20))
