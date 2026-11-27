"""Gradients: a sky behind everything, and a fill on every kind of shape.

    pixi run example gradients cpu    # CPU
    pixi run example gradients gpu    # the same scene through the GPU backend

The background spans the whole window (`EXTEND`), so resize it to watch the
sky stretch. A gradient spans each shape's own box, so the card's turns with
it.
"""
from create import *

comptime COLORS = ColorScheme.dark()
comptime TEXT = COLORS.on_surface
comptime OUTLINE = COLORS.on_surface
comptime SHADOW = Color(0, 0, 0, 90)


@fieldwise_init
struct App(Program):
    var sky: Gradient
    var card: Style
    var angle: Float64

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> App:
        # Built once: a gradient keeps its stops and ramp for as long as it
        # lives, so the GPU uploads it once.
        var sky = Gradient.linear(
            [
                (0, COLORS.surface_container_lowest),
                (0.55, COLORS.surface_container),
                (1, COLORS.surface_container_highest),
            ]
        )

        # A style can carry a gradient like any colour.
        var card = Style(
            fill_gradient=Gradient.linear(Color.CYAN, Color.MAGENTA),
            stroke_enabled=False,
            shadow=SHADOW,
            shadow_offset=Vector(0, -10),
            shadow_blur=16,
        )

        return App(sky, card, 0)

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        canvas.background(self.sky)

        self.angle += 0.5 * context.time.delta

        canvas.stroke(OUTLINE, thickness=2)

        # Left to right.
        canvas.fill(
            Gradient.linear(
                Color.MAGENTA,
                Color.BLUE,
                direction=Vector.RIGHT,
            )
        )
        canvas.rectangle((-450, 120), 160, 110)

        # Lit from the top left: a radial off the box's centre.
        canvas.fill(
            Gradient.radial(
                Color.WHITE,
                Color.CYAN,
                Color.BLUE,
                center=(-0.35, 0.35),
            )
        )
        canvas.circle((-220, 120), 65)

        # Corner to corner, with no trigonometry.
        canvas.fill(
            Gradient.linear(
                Color.YELLOW,
                Color.RED,
                direction=Vector(1, 1),
            )
        )
        canvas.triangle((-60, 55), (60, 55), (0, 185))

        # A sector spans its whole circle, so the slice shows part of it.
        canvas.fill(
            Gradient.linear(
                Color.GREEN,
                Color.CYAN,
                direction=Vector.RIGHT,
            )
        )
        canvas.sector((220, 120), 65, 0.5, 1.6 * PI)

        # Two colours on their own run from top to bottom.
        canvas.fill(Gradient.linear(Color.MAGENTA, Color.RED))
        canvas.draw(Polygon.star((450, 120), 70, 30, 5))

        # The card turns, and its gradient turns with it.
        with canvas.style(self.card):
            with canvas.transform(
                Transform(translation=Vector(-250, -140), rotation=self.angle)
            ):
                canvas.rectangle((0, 0), 220, 130, corner_radius=18)

        # A fade to transparent: a glow over whatever is behind it.
        with canvas.style(fill=Color.BLUE, stroke_enabled=False):
            canvas.circle((150, -140), 45)

        with canvas.style(
            fill_gradient=Gradient.radial(
                Color.WHITE.with_alpha(220), Color.WHITE.with_alpha(0)
            ),
            stroke_enabled=False,
        ):
            canvas.circle((150, -140), 120)

        with canvas.style(text_color=TEXT, font_size=18):
            canvas.text("Linear", (-450, 30))
            canvas.text("Radial", (-220, 30))
            canvas.text("Diagonal", (0, 30))
            canvas.text("Sector", (220, 30))
            canvas.text("Polygon", (450, 30))
            canvas.text("Turns with the shape", (-250, -250))
            canvas.text("Fades to transparent", (150, -250))


def main() raises:
    run[App](
        "Gradients",
        width=1280,
        height=720,
        autoscale=Autoscale.EXTEND,
        backend=RenderBackend.from_arguments(),
    )
