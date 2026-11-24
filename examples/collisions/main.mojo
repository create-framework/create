"""Collision tests against a circle that follows the mouse.

The six regions light up while the circle `overlaps` them, and the two
curves, a `Line` and an `Arc`, while it `intersects` them: a curve has no
inside, so it is crossed rather than overlapped. A thin line runs from the
mouse to each shape's `closest_point`, which inside a region is the mouse
itself.
"""

from create import *

comptime COLORS = ColorScheme.dark()
comptime BACKGROUND = COLORS.background
comptime SHAPE = Color.CYAN
comptime HIT = Color.RED
comptime GUIDE = COLORS.on_surface_variant
comptime TEXT = COLORS.on_surface


def reach[S: Geometry](mut canvas: Canvas, shape: S, mouse: Point):
    """A line from the mouse to the nearest point of `shape`, and a dot
    there. Any shape or curve answers `closest_point`, so one function serves all.
    """
    var nearest = shape.closest_point(mouse)
    with canvas.style(stroke=GUIDE, stroke_thickness=2):
        canvas.line(mouse, nearest)
    with canvas.style(fill=GUIDE, stroke_enabled=False):
        canvas.circle(nearest, 5)


@fieldwise_init
struct Collisions(Program):
    var probe: Circle
    """The circle that follows the mouse."""
    var rectangle: Rectangle
    var circle: Circle
    var triangle: Triangle
    var star: Polygon
    var ellipse: Ellipse
    var capsule: Capsule
    var line: Line
    var arc: Arc

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> Collisions:
        return Collisions(
            probe=Circle((0, 0), 45),
            rectangle=Rectangle(
                (-420, 110), 200, 140, corner_radius=16, rotation=0.2
            ),
            circle=Circle((-140, 110), 80),
            triangle=Triangle((80, 40), (240, 40), (160, 190)),
            star=Polygon.star((440, 110), 95, 42, 5),
            # The bottom row on the top row's columns, each about as big.
            ellipse=Ellipse((-420, -170), 200, 130),
            capsule=Capsule((-205, -205), (-75, -135), 35),
            line=Line((80, -240), (240, -100)),
            arc=Arc((440, -170), 75, 0.6, 5.0),
        )

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        var mouse = context.mouse.position
        self.probe = self.probe.move_to(mouse)

        canvas.background(BACKGROUND)

        # Regions: filled, lit while they overlap the probe.
        with canvas.style(stroke_enabled=False):
            canvas.fill(HIT if self.rectangle.overlaps(self.probe) else SHAPE)
            canvas.draw(self.rectangle)
            canvas.fill(HIT if self.circle.overlaps(self.probe) else SHAPE)
            canvas.draw(self.circle)
            canvas.fill(HIT if self.triangle.overlaps(self.probe) else SHAPE)
            canvas.draw(self.triangle)
            canvas.fill(HIT if self.star.overlaps(self.probe) else SHAPE)
            canvas.draw(self.star)
            canvas.fill(HIT if self.ellipse.overlaps(self.probe) else SHAPE)
            canvas.draw(self.ellipse)
            canvas.fill(HIT if self.capsule.overlaps(self.probe) else SHAPE)
            canvas.draw(self.capsule)

        # Curves: stroked, lit while they cross the probe.
        with canvas.style(stroke_thickness=8):
            canvas.stroke(HIT if self.line.intersects(self.probe) else SHAPE)
            canvas.draw(self.line)
            canvas.stroke(HIT if self.arc.intersects(self.probe) else SHAPE)
            canvas.draw(self.arc)

        with canvas.style(
            fill=TEXT.with_alpha(60), stroke=TEXT, stroke_thickness=2
        ):
            canvas.draw(self.probe)

        reach(canvas, self.rectangle, mouse)
        reach(canvas, self.circle, mouse)
        reach(canvas, self.triangle, mouse)
        reach(canvas, self.star, mouse)
        reach(canvas, self.ellipse, mouse)
        reach(canvas, self.capsule, mouse)
        reach(canvas, self.line, mouse)
        reach(canvas, self.arc, mouse)

        with canvas.style(
            text_color=TEXT, font_size=30, text_alignment=Align.TOP
        ):
            canvas.text("Collisions", (0, canvas.top() - 38))
        with canvas.style(
            text_color=TEXT, font_size=18, text_alignment=Align.TOP
        ):
            canvas.text(
                "Regions light up as they overlap the circle, curves as they"
                + " cross it; lines run to each shape's closest point",
                (0, canvas.top() - 78),
            )


def main() raises:
    run[Collisions]("Collisions", width=1280, height=800)
