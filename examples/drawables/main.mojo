"""A program's own type drawn with `canvas.draw`, like any shape.

`Rocket` is built from shapes, a `Capsule`, a nose and two fins, and is
`Drawable`: its `draw_to` draws those parts, and nothing else. It sets no
colour, so each rocket below takes the style around its `canvas.draw`, as a
`Circle` would: a fill, an outline, or both. It knows nothing of where it is
drawn either: each is drawn around the origin, inside a transform that places
it and rocks it.
"""

from create import *

comptime COLORS = ColorScheme.dark()
comptime BACKGROUND = COLORS.background
comptime CAPTION = COLORS.on_surface_variant
comptime TITLE = COLORS.on_surface
comptime WINDOW = COLORS.on_surface

comptime SPACING = 260.0
"""How far apart the rockets stand, in design units."""
comptime BOB = 12.0
"""How far each rocket rises and falls, in design units."""
comptime TILT = 0.15
"""How far each rocket rocks either way, in radians."""


struct Rocket(Copyable, Drawable, Movable):
    var body: Capsule
    var nose: Triangle
    var left_fin: Triangle
    var right_fin: Triangle

    def __init__(out self):
        self.body = Capsule((0, -60), (0, 20), 30)
        self.nose = Triangle((-30, 20), (30, 20), (0, 100))
        self.left_fin = Triangle((-30, -45), (-30, -100), (-70, -90))
        self.right_fin = Triangle((30, -45), (30, -100), (70, -90))

    def draw_to[T: DrawTarget](self, mut target: T):
        # Each part is a shape of its own, all in the same style: so an
        # outline goes round every part, even where two overlap. The fins'
        # inner edges line up with the body's sides, so a centred outline
        # draws the edge they share as one line.
        target.draw(self.nose)
        target.draw(self.left_fin)
        target.draw(self.right_fin)
        target.draw(self.body)


@fieldwise_init
struct App(Program):
    var rocket: Rocket

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> App:
        return App(Rocket())

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        canvas.background(BACKGROUND)

        for i in range(3):
            # Each rocket rocks a little out of step with the last.
            var phase = context.time.elapsed * 2.0 + Float64(i) * 1.3
            var place = Transform(
                translation=Vector(Float64(i - 1) * SPACING, BOB * sin(phase)),
                rotation=TILT * sin(phase * 0.7),
            )
            with canvas.transform(place):
                if i == 0:
                    with canvas.style(fill=Color.RED, stroke_enabled=False):
                        canvas.draw(self.rocket)
                elif i == 1:
                    with canvas.style(
                        fill_enabled=False,
                        stroke=Color.CYAN,
                        stroke_thickness=4,
                        stroke_alignment=StrokeAlign.CENTER,
                    ):
                        canvas.draw(self.rocket)
                else:
                    with canvas.style(
                        fill=Color.YELLOW,
                        stroke=BACKGROUND,
                        stroke_thickness=4,
                        stroke_alignment=StrokeAlign.CENTER,
                    ):
                        canvas.draw(self.rocket)

                # A part in a colour of its own is drawn on its own, after.
                with canvas.style(fill=WINDOW, stroke_enabled=False):
                    canvas.circle((0, 5), 12)

        with canvas.style(
            text_color=TITLE, font_size=30, text_alignment=Align.TOP
        ):
            canvas.text("canvas.draw(rocket)", (0, canvas.top() - 36))
        with canvas.style(text_color=CAPTION, font_size=18):
            var y = canvas.bottom() + 60
            canvas.text("a fill", (-SPACING, y))
            canvas.text("an outline", (0, y))
            canvas.text("both", (SPACING, y))


def main() raises:
    run[App]("Drawables", width=900, height=500)
