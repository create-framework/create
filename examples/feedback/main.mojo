"""Feedback: each frame draws the last one back in, slightly changed.

The frame is read back with `canvas.snapshot()` and drawn under the next
frame a little larger and fainter, so the dots leave trails that drift
outwards and fade.
"""

from create import *

comptime COLORS = ColorScheme.dark()
comptime BACKGROUND = COLORS.background

comptime GROWTH = 1.01
"""How much larger the last frame is drawn back each frame."""
comptime FADE: UInt8 = 30
"""How much of the background is laid over the last frame, out of 255: the
higher, the shorter the trails."""
comptime DOT_RADIUS = 18.0


def dot_colors() -> List[Color]:
    return [Color.RED, Color.GREEN, Color.BLUE]


@fieldwise_init
struct Feedback(Program):
    var last: Optional[Image]
    """The last frame, read back at its end."""

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> Feedback:
        return Feedback(None)

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        canvas.background(BACKGROUND)
        if self.last:
            # The last frame, a little larger, faded by a translucent
            # background: a trail that drifts outwards.
            canvas.image(
                self.last.value(),
                (0, 0),
                canvas.width() * GROWTH,
                canvas.height() * GROWTH,
            )
            canvas.background(BACKGROUND.with_alpha(FADE))

        var t = context.time.elapsed
        var colors = dot_colors()
        with canvas.style(stroke_enabled=False):
            for i in range(len(colors)):
                var angle = t * (0.7 + 0.3 * Float64(i)) + Float64(i) * 2.1
                canvas.fill(colors[i])
                canvas.circle(
                    (cos(angle) * 180, sin(angle * 1.3) * 120), DOT_RADIUS
                )

        self.last = canvas.snapshot()


def main() raises:
    run[Feedback]("Feedback", width=800, height=600)
