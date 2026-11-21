"""Shadows: drop, inset, on text, on turning shapes and on an image.

    pixi run example shadows        # CPU
    pixi run example shadows gpu    # the same scene through the GPU backend

Space toggles every shadow between soft and hard.
"""

from create import *

comptime _PAGE = Color(240, 236, 222)
comptime _INK = Color(40, 40, 44)
comptime _SHADOW = Color(40, 40, 44, 90)
comptime _CARD_SHADOW = Color(40, 40, 44, 70)
comptime _SQUARE_SHADOW = Color(0, 0, 0, 80)
comptime _FIELD = Color(250, 248, 242)
comptime _FIELD_EDGE = Color(200, 196, 186)
comptime _PLACEHOLDER = Color(150, 146, 138)
comptime _SQUARE = Color(98, 104, 168)
comptime _CAPTION = Color(80, 78, 74)
comptime _HINT = Color(110, 108, 104)


@fieldwise_init
struct App(Program):
    var logo: Image
    var angle: Float64
    var soft: Bool

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> App:
        return App(
            Image.load("../../assets/logo/png/logo-cutout.png"),
            0.9,
            True,
        )

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        canvas.background(_PAGE)
        if context.keyboard.pressed(Key.SPACE):
            self.soft = not self.soft
        self.angle += 0.6 * context.time.delta
        # One blur for the whole scene; spreads and offsets stay as set.
        var blur = 16.0 if self.soft else 0.0

        # A heading whose glyphs cast their own shadow.
        with canvas.style(
            text_color=_INK,
            font_size=56,
            font_weight=FontWeight.BOLD,
            shadow=Shadow(_SHADOW, offset=Vector(3, -3), blur=blur / 4.0),
        ):
            canvas.text("Shadows", (0, canvas.top() - 70))

        # A card lifted off the page: soft, offset down, a rounded silhouette.
        with canvas.style(
            fill=Color.WHITE,
            stroke_enabled=False,
            shadow=Shadow(_CARD_SHADOW, offset=Vector(0, -10), blur=blur * 1.5),
        ):
            canvas.rectangle((-330, 60), 380, 220, corner_radius=18)
        with canvas.style(text_color=_INK, font_size=26):
            canvas.text("A card", (-330, 110))
        with canvas.style(text_color=_HINT, font_size=18):
            canvas.text("A drop shadow, offset straight down", (-330, 60))

        # A text field pressed into the page: the inset shadow darkens the
        # top-left inner edges, as if lit from above.
        with canvas.style(
            fill=_FIELD,
            stroke=_FIELD_EDGE,
            shadow=Shadow(
                _SHADOW, offset=Vector(3, -4), blur=blur / 2.0, inset=True
            ),
        ):
            canvas.rectangle((-330, -170), 380, 60, corner_radius=10)
        with canvas.style(
            text_color=_PLACEHOLDER,
            font_size=20,
            font_italic=True,
            text_alignment=Align.LEFT,
        ):
            canvas.text("Type here…", (-500, -170))

        # The same turning square twice. On the left the shadow is fixed to
        # the screen, as under a light overhead; on the right it turns with
        # the square.
        canvas.shadow(_SQUARE_SHADOW, offset=Vector(14, -14), blur=blur)
        var square = Rectangle((0, 0), 120, 120, corner_radius=14)
        with canvas.style(fill=_SQUARE, stroke_enabled=False):
            with canvas.transform(
                Transform(translation=Vector(170, 110), rotation=self.angle)
            ):
                canvas.draw(square)
            with canvas.style():
                canvas.shadow(follows_transform=True)
                with canvas.transform(
                    Transform(translation=Vector(430, 110), rotation=self.angle)
                ):
                    canvas.draw(square)

        # An image casts its alpha, not its box.
        canvas.image(self.logo, (300, -170), 150, 150)
        canvas.shadow_enabled(False)

        with canvas.style(text_color=_CAPTION, font_size=18):
            canvas.text("Fixed to the screen", (170, -20))
            canvas.text("Follows the transform", (430, -20))
            canvas.text("An image's alpha", (300, -265))

        with canvas.style(text_color=_HINT, font_size=18):
            canvas.text(
                "Space: " + ("soft" if self.soft else "hard") + " shadows",
                (0, canvas.bottom() + 40),
            )


def main() raises:
    # `gpu` on the command line runs it on the GPU; calling `run` once for
    # each backend compiles both
    if RenderBackend.from_arguments() == RenderBackend.GPU:
        run[App, backend=RenderBackend.GPU]("Shadows", width=1280, height=720)
    else:
        run[App]("Shadows", width=1280, height=720)
