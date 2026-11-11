"""Collision tests against a circle that follows the mouse.

The six regions light up while they `overlap` it, and the two curves, a
`Line` and an `Arc`, while they `intersect` it: a curve has no inside, so it
is crossed rather than overlapped. A thin line runs from the mouse to each
shape's `closest_point`, which inside a region is the mouse itself.
"""

from create import *

comptime _BACKGROUND = Color(40, 40, 44)
comptime _SHAPE = Color(98, 104, 168)
comptime _HIT = Color(226, 46, 56)
comptime _GUIDE = Color(176, 172, 162)
comptime _TEXT = Color(240, 236, 222)


def _reach[S: Shape](mut canvas: Canvas, shape: S, mouse: Point2D):
    """A line from the mouse to the nearest point of `shape`, and a dot
    there. Any shape answers `closest_point`, so one function serves all."""
    var nearest = shape.closest_point(mouse)
    with canvas.style(stroke=_GUIDE, stroke_thickness=2):
        canvas.line(mouse, nearest)
    with canvas.style(fill=_GUIDE, stroke_enabled=False):
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
            rectangle=Rectangle((-420, 110), 200, 140, corner_radius=16),
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

        canvas.background(_BACKGROUND)

        # Regions: filled, lit while they overlap the probe.
        with canvas.style(stroke_enabled=False):
            canvas.fill(
                _HIT if overlaps(self.rectangle, self.probe) else _SHAPE
            )
            canvas.draw(self.rectangle)
            canvas.fill(_HIT if overlaps(self.circle, self.probe) else _SHAPE)
            canvas.draw(self.circle)
            canvas.fill(_HIT if overlaps(self.triangle, self.probe) else _SHAPE)
            canvas.draw(self.triangle)
            canvas.fill(_HIT if overlaps(self.star, self.probe) else _SHAPE)
            canvas.draw(self.star)
            canvas.fill(_HIT if overlaps(self.ellipse, self.probe) else _SHAPE)
            canvas.draw(self.ellipse)
            canvas.fill(_HIT if overlaps(self.capsule, self.probe) else _SHAPE)
            canvas.draw(self.capsule)

        # Curves: stroked, lit while they cross the probe.
        with canvas.style(stroke_thickness=8):
            canvas.stroke(_HIT if self.line.intersects(self.probe) else _SHAPE)
            canvas.draw(self.line)
            canvas.stroke(_HIT if self.arc.intersects(self.probe) else _SHAPE)
            canvas.draw(self.arc)

        with canvas.style(
            fill=Color(240, 236, 222, 60), stroke=_TEXT, stroke_thickness=2
        ):
            canvas.draw(self.probe)

        _reach(canvas, self.rectangle, mouse)
        _reach(canvas, self.circle, mouse)
        _reach(canvas, self.triangle, mouse)
        _reach(canvas, self.star, mouse)
        _reach(canvas, self.ellipse, mouse)
        _reach(canvas, self.capsule, mouse)
        _reach(canvas, self.line, mouse)
        _reach(canvas, self.arc, mouse)

        with canvas.style(
            text_color=_TEXT, font_size=30, text_alignment=Align.TOP
        ):
            canvas.text("Collisions", (0, 362))
        with canvas.style(
            text_color=_TEXT, font_size=18, text_alignment=Align.TOP
        ):
            canvas.text(
                "Regions light up as they overlap the circle, curves as they"
                + " cross it; lines run to each shape's closest point",
                (0, 322),
            )


def main() raises:
    run[Collisions]("Collisions", width=1280, height=800)
