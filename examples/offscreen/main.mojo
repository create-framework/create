"""Drawing offscreen: a `Canvas(width, height)` of the program's own, read
back as an `Image` with `snapshot`.

Two offscreen canvases make a small paint program. The brush, a soft round
tip, is drawn once in `create` and kept as an image. The paint layer is a
canvas kept as a field: dragging stamps the brush into it, and the strokes
stay while the frame under them is redrawn every frame. C clears the layer.
"""

from create import *

comptime COLORS = ColorScheme.dark()
comptime BACKGROUND = COLORS.background
comptime HINT = COLORS.on_surface_variant
comptime BACKDROP = COLORS.outline_variant
comptime PAINT_FROM = Color.CYAN
comptime PAINT_TO = Color.MAGENTA

comptime BRUSH_SIZE = 48.0
"""How wide the brush is, in design units."""
comptime SPACING = BRUSH_SIZE / 12
"""How far apart the brush is stamped along a drag, in design units."""
comptime PREVIEW_OPACITY = 0.35
"""How strongly the brush shows under the mouse when not painting."""
comptime DRIFT_SPEED = 0.3
"""How fast the backdrop's rings drift, in radians per second."""


def brush() raises -> Image:
    """A white disc fading out to its rim, drawn offscreen at twice the
    design density so it stays smooth on a window scaled up to 2x. White,
    so a tint gives it any colour."""
    var canvas = Canvas(BRUSH_SIZE, BRUSH_SIZE, pixel_scale=2.0)
    canvas.fill(Gradient.radial(Color.WHITE, Color.WHITE.with_alpha(0)))
    canvas.stroke_enabled(False)
    canvas.circle((0, 0), BRUSH_SIZE / 2)

    return canvas.snapshot(pixel_scale=canvas.pixel_scale())


@fieldwise_init
struct Offscreen(Program):
    var brush: Image
    var layer: Canvas
    """The paint layer: the size of the design, transparent but for the
    strokes painted into it."""
    var strokes: Image
    """The layer as last read, drawn every frame."""
    var last_stamp: Point
    """Where the brush was last stamped, so the next stamp keeps its
    distance."""

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> Offscreen:
        var layer = Canvas(canvas.width(), canvas.height())
        var strokes = layer.snapshot()

        return Offscreen(brush(), layer^, strokes^, Point(0, 0))

    def stamp(mut self, position: Point, color: Color):
        with self.layer.style(tint=color):
            self.layer.image(self.brush, position, BRUSH_SIZE, BRUSH_SIZE)

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        var mouse = context.mouse.position
        var t = context.time.elapsed

        # The paint swings back and forth between two colours.
        var color = PAINT_FROM.lerp(PAINT_TO, 0.5 + 0.5 * sin(t * 2.0))

        # C wipes the layer clean.
        if context.keyboard.pressed(Key.C):
            self.layer.clear()
            self.strokes = self.layer.snapshot()

        if context.mouse.pressed():
            self.stamp(mouse, color)
            self.last_stamp = mouse
        elif context.mouse.down():
            # Stamps evenly spaced from the last one towards the mouse, so a
            # fast drag paints a line rather than dots.
            var to_mouse = mouse - self.last_stamp
            var step = to_mouse.with_length(SPACING)
            for _ in range(Int(to_mouse.magnitude() / SPACING)):
                var at = self.last_stamp + step
                self.last_stamp = at
                self.stamp(at, color)

        if context.mouse.down():
            # Read only while painting: a read copies the layer.
            self.strokes = self.layer.snapshot()

        # The frame under the layer, redrawn every frame.
        canvas.background(BACKGROUND)

        with canvas.style(
            fill_enabled=False, stroke=BACKDROP, stroke_thickness=2
        ):
            for i in range(5):
                var angle = t * DRIFT_SPEED + Float64(i) * TAU / 5
                canvas.circle(
                    Point(0, 0) + Vector.from_angle(angle, 180),
                    50 + 20 * sin(t + Float64(i)),
                )

        canvas.image(self.strokes, (0, 0), canvas.width(), canvas.height())

        # The brush under the mouse, faint, in the colour it would paint.
        if not context.mouse.down():
            with canvas.style(tint=color, opacity=PREVIEW_OPACITY):
                canvas.image(self.brush, mouse, BRUSH_SIZE, BRUSH_SIZE)

        with canvas.style(text_color=HINT, font_size=18):
            canvas.text(
                (
                    "Drag to paint, C to clear. The strokes stay while the"
                    " frame under them is redrawn."
                ),
                (0, canvas.bottom() + 30),
            )


def main() raises:
    run[Offscreen](
        "Offscreen",
        width=800,
        height=600,
        backend=RenderBackend.from_arguments(),
    )
