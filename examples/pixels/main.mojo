"""Reading back what is drawn: each frame is drawn over a slightly larger,
fainter copy of the last one, so the circles leave trails that drift
outwards, and the swatch at the bottom shows the colour under the
mouse.
"""

from create import *

comptime COLORS = ColorScheme.dark()
comptime BACKGROUND = COLORS.background
comptime TEXT = COLORS.on_surface


@fieldwise_init
struct Pixels(Program):
    var last: Optional[Image]

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> Pixels:
        return Pixels(None)

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        canvas.background(BACKGROUND)
        if self.last:
            # The last frame, 1% larger, faded by a translucent background:
            # a trail that drifts outwards.
            canvas.image(
                self.last.value(),
                (0, 0),
                canvas.width() * 1.01,
                canvas.height() * 1.01,
            )
            canvas.background(BACKGROUND.with_alpha(30))

        var t = context.time.elapsed
        canvas.stroke_enabled(False)
        var colors = [Color.RED, Color.GREEN, Color.BLUE]
        for i in range(3):
            var angle = t * (0.7 + 0.3 * Float64(i)) + Float64(i) * 2.1
            canvas.fill(colors[i])
            canvas.circle((cos(angle) * 180, sin(angle * 1.3) * 120), 18)

        # Kept before the swatch, so the trail never shows it.
        self.last = canvas.snapshot()

        var under = canvas.color_at(context.mouse.position)
        canvas.fill(under)
        canvas.stroke(TEXT)
        canvas.rectangle((0, canvas.bottom() + 40), 60, 40)
        canvas.text_color(TEXT)
        canvas.text(String(under), (0, canvas.bottom() + 80))


def main() raises:
    run[Pixels]("Pixels", width=800, height=600)
