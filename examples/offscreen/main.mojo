"""Drawing offscreen: a `Canvas(width, height)` of the program's own, read
back as an `Image` with `snapshot`.

Two uses. A badge drawn once in `create` and kept as an image, stamped
where the mouse is. And a paint layer kept as a field: drag to paint into
it, and the strokes stay while the frame under them is redrawn every frame.
C clears the layer.
"""

from create import *

comptime COLORS = ColorScheme.dark()
comptime BACKGROUND = COLORS.background
comptime HINT = COLORS.on_surface_variant
comptime ORBIT = COLORS.outline_variant
comptime PAINT_FROM = Color.CYAN
comptime PAINT_TO = Color.MAGENTA
comptime BADGE_LIGHT = Color.YELLOW
comptime BADGE_DARK = Color.RED
comptime BADGE_RIM = COLORS.on_surface
comptime BADGE_TEXT = COLORS.background

comptime BADGE_SIZE = 80


def badge() raises -> Image:
    """A badge drawn offscreen, at twice the design density so it stays
    crisp on a window scaled up to 2x."""
    var canvas = Canvas(BADGE_SIZE, BADGE_SIZE, pixel_scale=2.0)
    canvas.shadow(blur=6)
    canvas.fill(Gradient.radial(BADGE_LIGHT, BADGE_DARK))
    canvas.stroke(BADGE_RIM, thickness=3)
    canvas.circle((0, 0), 32)
    canvas.shadow_enabled(False)
    canvas.text_color(BADGE_TEXT)
    canvas.font_size(28)
    canvas.text("1st", (0, 0))
    return canvas.snapshot(pixel_scale=canvas.pixel_scale())


@fieldwise_init
struct Offscreen(Program):
    var badge: Image
    var layer: Canvas
    """The paint layer: the size of the design, transparent but for the
    strokes painted into it."""
    var strokes: Image
    """The layer as last read, redrawn every frame."""
    var last_mouse: Point

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> Offscreen:
        var layer = Canvas(canvas.width(), canvas.height())
        var strokes = layer.snapshot()
        return Offscreen(badge(), layer^, strokes^, Point(0, 0))

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        if context.keyboard.pressed(Key.C):
            self.layer.clear()
            self.strokes = self.layer.snapshot()
        if context.mouse.down():
            # From where the mouse was, so a fast drag paints a line, not dots.
            var start = (
                context.mouse.position if context.mouse.pressed() else self.last_mouse
            )
            with self.layer.style(
                stroke=PAINT_FROM.lerp(
                    PAINT_TO,
                    0.5 + 0.5 * sin(context.time.elapsed * 2.0),
                ),
                stroke_thickness=12,
                stroke_cap=StrokeCap.ROUND,
            ):
                # Round caps join each segment to the next without a notch.
                self.layer.line(start, context.mouse.position)
            # Read only when something was painted: a read copies the layer.
            self.strokes = self.layer.snapshot()
        self.last_mouse = context.mouse.position

        # The frame under the layer, redrawn and cleared every frame.
        canvas.background(BACKGROUND)
        var t = context.time.elapsed
        with canvas.style(fill=ORBIT, stroke_enabled=False):
            canvas.circle((cos(t) * 200, sin(t * 1.3) * 120), 40)

        canvas.image(self.strokes, (0, 0), canvas.width(), canvas.height())
        canvas.image(self.badge, context.mouse.position, BADGE_SIZE, BADGE_SIZE)

        with canvas.style(text_color=HINT, font_size=18):
            canvas.text("Drag to paint, C to clear", (0, canvas.bottom() + 30))


def main() raises:
    run[Offscreen](
        "Offscreen",
        width=800,
        height=600,
        backend=RenderBackend.from_arguments(),
    )
