"""Reading the screen: `canvas.color_at` returns the colour drawn at a point.

A colour picker. On the left, a spectrum; on the right, the colour under the
mouse and its channels, read back from what the frame has drawn so far. Hover
anywhere to pick a colour.
"""

from create import *

comptime COLORS = ColorScheme.dark()
comptime BACKGROUND = COLORS.background
comptime TEXT = COLORS.on_surface
comptime HINT = COLORS.on_surface_variant
comptime OUTLINE = COLORS.outline

comptime SPECTRUM = Rectangle((-180, 20), 400, 320)
comptime SWATCH = Rectangle((240, 90), 180, 180)


@fieldwise_init
struct Pixels(Program):
    var hues: Gradient
    """Every hue, left to right."""
    var shade: Gradient
    """Laid over the hues: paler towards the top, darker towards the
    bottom."""

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> Pixels:
        var hues = Gradient.linear(
            Color.RED,
            Color.YELLOW,
            Color.GREEN,
            Color.CYAN,
            Color.BLUE,
            Color.MAGENTA,
            Color.RED,
            direction=Vector.RIGHT,
        )
        var shade = Gradient.linear(
            Color.WHITE,
            Color.WHITE.with_alpha(0),
            Color.BLACK.with_alpha(0),
            Color.BLACK,
        )
        return Pixels(hues^, shade^)

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        canvas.background(BACKGROUND)
        # What there is to pick from.
        with canvas.style(stroke_enabled=False):
            canvas.fill(self.hues)
            canvas.draw(SPECTRUM)
            canvas.fill(self.shade)
            canvas.draw(SPECTRUM)

        # Read before anything else is drawn: a read sees what the frame has
        # drawn so far, so the swatch and its text never show in it.
        var picked = canvas.color_at(context.mouse.position)

        with canvas.style(
            fill=picked, stroke=OUTLINE, stroke_thickness=2, corner_radius=16
        ):
            canvas.rectangle(SWATCH.position, SWATCH.width, SWATCH.height)
        with canvas.style(
            text_color=TEXT, font_size=20, text_alignment=Align.TOP
        ):
            canvas.text(
                "Red: "
                + String(picked.r)
                + "\nGreen: "
                + String(picked.g)
                + "\nBlue: "
                + String(picked.b)
                + "\nAlpha: "
                + String(picked.a),
                (SWATCH.position.x, SWATCH.bottom() - 30),
            )
        with canvas.style(text_color=HINT, font_size=18):
            canvas.text(
                "Hover anywhere to pick a colour.", (0, canvas.bottom() + 30)
            )


def main() raises:
    run[Pixels]("Pixels", width=900, height=600)
