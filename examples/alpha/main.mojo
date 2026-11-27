"""Translucency, two ways.

On the left, three circles whose colours are half transparent mix where
they cross: alpha belongs to each colour. On the right, a card of fill,
stroke, text and image fades in and out by one `opacity`, which reaches
every part of a render call at once.
"""

from create import *

comptime COLORS = ColorScheme.dark()
comptime BACKGROUND = COLORS.background
comptime PANEL = COLORS.surface_container
comptime TEXT = COLORS.on_surface
comptime HINT = COLORS.on_surface_variant
comptime CARD = Point(200, 20)


@fieldwise_init
struct App(Program):
    var logo: Image

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> App:
        return App(Image.load("../../assets/logo/png/logo-cutout.png"))

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        canvas.background(BACKGROUND)
        canvas.stroke_enabled(False)

        # A panel behind each demonstration.
        canvas.fill(PANEL)
        canvas.rectangle((-185, 20), 300, 240, corner_radius=16)
        canvas.rectangle(CARD, 300, 240, corner_radius=16)

        # Overlapping translucent colours mix where they cross.
        canvas.fill(Color.RED.with_alpha(128))
        canvas.circle((-225, -5), 60)
        canvas.fill(Color.GREEN.with_alpha(128))
        canvas.circle((-145, -5), 60)
        canvas.fill(Color.BLUE.with_alpha(128))
        canvas.circle((-185, 65), 60)

        # One value fades fill, stroke, text and image alike. Each shape
        # still composites once, so the stroke never shows through the fill.
        var opacity = 0.5 + 0.5 * sin(context.time.elapsed * 1.5)

        with canvas.style(opacity=opacity):
            with canvas.style(
                fill=Color.MAGENTA,
                stroke=TEXT,
                stroke_thickness=6,
            ):
                canvas.rectangle(CARD, 220, 170, corner_radius=18)

            canvas.image(self.logo, CARD + Vector(0, 20), 100, 100)

            with canvas.style(text_color=TEXT, font_size=22):
                canvas.text(
                    String("Opacity ", round(opacity, 2)),
                    CARD - Vector(0, 55),
                )

        with canvas.style(text_color=HINT, font_size=18):
            canvas.text("Alpha: each colour its own", (-185, -120))
            canvas.text("Opacity: one value for every part", (200, -130))


def main() raises:
    run[App]("Alpha", width=800, height=600)
