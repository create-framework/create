"""A cubic `Bezier` with handles to drag, and a dot travelling along it at
constant speed with `at_distance`.

Drag the four handles to reshape the curve.
"""

from create import *

comptime GRAB_RADIUS = 18.0
"""How close, in design units, a press must land to pick up a handle."""

comptime SPEED = 260.0
"""How fast the dot travels along the curve, in design units per second."""

comptime COLORS = ColorScheme.dark()
comptime BACKGROUND = COLORS.background
comptime TEXT = COLORS.on_surface
comptime CONTROL_LINE = COLORS.outline_variant
comptime CURVE = Color.CYAN
comptime SHADOW = Color(0, 0, 0, 160)
comptime DOT = Color.GREEN
comptime ENDPOINT = COLORS.on_surface
comptime CONTROL = COLORS.on_surface_variant
comptime RING = 4.0
"""The background-coloured ring around the dot and the handles."""


@fieldwise_init
struct App(Program):
    var handles: List[Point]
    """`start`, `control1`, `control2`, `end`, in the order `Bezier`
    takes them."""

    var dragging: Int
    """The handle being dragged, or -1."""

    var travelled: Float64
    """How far along the curve the dot is."""

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> App:
        # Authored against the 1280x800 passed to run(): the origin is the
        # centre of the window and y grows upward.
        return App(
            handles=[
                (-420.0, -180.0),
                (-260.0, 260.0),
                (260.0, -260.0),
                (420.0, 180.0),
            ],
            dragging=-1,
            travelled=0.0,
        )

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        # No camera, so the mouse is already in the space the handles are in.
        var mouse = context.mouse.position
        if context.mouse.pressed():
            for i in range(len(self.handles)):
                if (mouse - self.handles[i]).magnitude() <= GRAB_RADIUS:
                    self.dragging = i
        if context.mouse.released():
            self.dragging = -1
        if self.dragging >= 0:
            self.handles[self.dragging] = mouse

        var curve = Bezier(
            self.handles[0], self.handles[1], self.handles[2], self.handles[3]
        )

        # `at` would bunch the dot up wherever the controls pull the curve
        # tight; `at_distance` moves it the same distance every second.
        var length = curve.length()
        self.travelled += SPEED * context.time.delta
        if self.travelled > length:
            self.travelled = 0.0
        var dot = curve.at_distance(self.travelled)

        canvas.background(BACKGROUND)

        # The control polygon: each control's pull on its endpoint.
        canvas.stroke(CONTROL_LINE, thickness=2)
        canvas.line(self.handles[0], self.handles[1])
        canvas.line(self.handles[3], self.handles[2])

        # The curve itself, with a soft shadow. A curve has no interior, so
        # only the stroke draws and casts.
        with canvas.style(
            stroke=CURVE,
            stroke_thickness=12,
            stroke_cap=StrokeCap.ROUND,
            shadow=SHADOW,
            shadow_offset=Vector(6, -10),
            shadow_blur=18,
        ):
            canvas.draw(curve)

        # A ring of the background colour parts the dot and the handles from
        # the curve, so their colours never touch the curve's along an edge.
        with canvas.style(
            stroke=BACKGROUND,
            stroke_thickness=RING,
            stroke_alignment=StrokeAlign.OUTSIDE,
        ):
            canvas.fill(DOT)
            canvas.circle(dot, 13)
            for i in range(len(self.handles)):
                var endpoint = i == 0 or i == 3
                canvas.fill(
                    ENDPOINT if endpoint or i == self.dragging else CONTROL
                )
                canvas.circle(self.handles[i], 10 if endpoint else 8)

        canvas.text_color(TEXT)
        canvas.font_size(30)
        canvas.text_alignment(Align.TOP)
        canvas.text("Cubic Bézier", (0, canvas.top() - 38))
        canvas.font_size(18)
        canvas.text(
            "Drag the handles to reshape the curve", (0, canvas.top() - 78)
        )


def main() raises:
    run[App]("Cubic Bézier", width=1280, height=800)
