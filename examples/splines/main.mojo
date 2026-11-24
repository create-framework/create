"""A `Spline` through points you place, and a dot travelling along it at
constant speed.

Click to add a point, drag to move one, right-click to remove one. C closes
the curve; 1, 2 and 3 set its alpha: uniform, centripetal, chordal.
"""

from create import *

comptime GRAB_RADIUS = 18.0
"""How close, in design units, a click must land to pick up a point."""

comptime SPEED = 260.0
"""How fast the dot travels along the curve, in design units per second."""

comptime COLORS = ColorScheme.dark()
comptime BACKGROUND = COLORS.background
comptime TEXT = COLORS.on_surface
comptime CURVE = Color.CYAN.with_alpha(170)
comptime SHADOW = Color(0, 0, 0, 160)
comptime DOT = Color.GREEN
comptime POINT = COLORS.on_surface
comptime RING = 4.0
"""The background-coloured ring around the dot and the points."""


@fieldwise_init
struct App(Program):
    var points: List[Point]
    """What the curve passes through, in order."""

    var alpha: Float64
    """0 uniform, 0.5 centripetal, 1 chordal."""

    var closed: Bool

    var dragging: Int
    """The point being dragged, or -1."""

    var travelled: Float64
    """How far along the curve the dot is."""

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> App:
        # Authored against the 1280x800 passed to run(): the origin is the
        # centre of the window and y grows upward.
        return App(
            points=[
                (-480.0, -120.0),
                (-300.0, 160.0),
                (-80.0, -40.0),
                (180.0, 200.0),
                (440.0, -160.0),
            ],
            alpha=0.5,
            closed=False,
            dragging=-1,
            travelled=0.0,
        )

    def point_under(self, position: Point) -> Int:
        for i in range(len(self.points)):
            if (position - self.points[i]).magnitude() <= GRAB_RADIUS:
                return i
        return -1

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        # No camera, so the mouse is already in the space the points are in.
        var mouse = context.mouse.position
        if context.mouse.pressed():
            self.dragging = self.point_under(mouse)
            if self.dragging < 0:
                self.points.append(mouse)
                self.dragging = len(self.points) - 1
        if context.mouse.released():
            self.dragging = -1
        if self.dragging >= 0:
            self.points[self.dragging] = mouse
        if context.mouse.pressed(MouseButton.RIGHT):
            var i = self.point_under(mouse)
            if i >= 0:
                _ = self.points.pop(i)
        if context.keyboard.pressed(Key.C):
            self.closed = not self.closed
        if context.keyboard.pressed(Key.ONE):
            self.alpha = 0.0
        if context.keyboard.pressed(Key.TWO):
            self.alpha = 0.5
        if context.keyboard.pressed(Key.THREE):
            self.alpha = 1.0

        var spline = Spline(self.points.copy(), self.alpha, self.closed)

        # `at` would move the dot faster along long stretches than short
        # ones; `at_distance` moves it the same distance every second.
        var length = spline.length()
        self.travelled += SPEED * context.time.delta
        if self.travelled > length:
            self.travelled = 0.0
        var dot = spline.at_distance(self.travelled)

        canvas.background(BACKGROUND)

        # Translucent, so any joint painted twice would show as a brighter
        # seam; there is none, closed or not.
        with canvas.style(
            stroke=CURVE,
            stroke_thickness=14,
            shadow=SHADOW,
            shadow_offset=Vector(6, -10),
            shadow_blur=18,
        ):
            canvas.draw(spline)

        # A ring of the background colour parts the dot and the points from
        # the curve, so their colours never touch the curve's along an edge.
        with canvas.style(
            stroke=BACKGROUND,
            stroke_thickness=RING,
            stroke_alignment=StrokeAlign.OUTSIDE,
        ):
            if len(self.points) > 0:
                canvas.fill(DOT)
                canvas.circle(dot, 13)
            canvas.fill(POINT)
            for point in self.points:
                canvas.circle(point, 9)

        var kind: String
        if self.alpha == 0.0:
            kind = "uniform"
        elif self.alpha == 0.5:
            kind = "centripetal"
        else:
            kind = "chordal"
        canvas.text_color(TEXT)
        canvas.font_size(30)
        canvas.text_alignment(Align.TOP)
        canvas.text(
            String(
                "Spline, ",
                kind,
                " (alpha ",
                self.alpha,
                ")",
                ", closed" if self.closed else "",
            ),
            (0, canvas.top() - 38),
        )
        canvas.font_size(18)
        canvas.text(
            (
                "Click to add a point, drag to move, right-click to remove;"
                " C closes the curve; 1, 2 and 3 set alpha"
            ),
            (0, canvas.top() - 78),
        )


def main() raises:
    run[App]("Spline", width=1280, height=800)
