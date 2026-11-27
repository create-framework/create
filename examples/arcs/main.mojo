"""Arcs as progress rings: one tween sweeps two arcs from the top, one
clockwise and one counter-clockwise.
"""

from create import *

comptime COLORS = ColorScheme.dark()
comptime BACKGROUND = COLORS.background
comptime TEXT = COLORS.on_surface
comptime TRACK = COLORS.outline_variant
comptime CLOCKWISE = Color.CYAN
comptime COUNTER = Color.MAGENTA

comptime RING_RADIUS = 140.0
comptime RING_THICKNESS = 18


@fieldwise_init
struct App(Program):
    var progress: Tween
    """Walks both rings from empty to full."""

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> App:
        var progress = Tween(3.0, Easing.IN_OUT_CUBIC)
        progress.loop()

        return App(progress=progress)

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        canvas.background(BACKGROUND)
        canvas.fill_enabled(False)

        # Two progress rings off one tween. Angles count counter-clockwise
        # from +x because y is up, so the clockwise ring (cyan, like a
        # clock's hand) starts at the top and sweeps negatively.
        var sweep = TAU * self.progress.value()
        var clockwise = Point(-200.0, -20.0)
        var counter = Point(200.0, -20.0)

        canvas.stroke(TRACK, thickness=RING_THICKNESS)
        canvas.arc(clockwise, RING_RADIUS, 0.0, TAU)
        canvas.arc(counter, RING_RADIUS, 0.0, TAU)

        # The progress, drawn over the tracks.
        canvas.stroke(CLOCKWISE)
        canvas.arc(clockwise, RING_RADIUS, PI / 2.0, -sweep)
        canvas.stroke(COUNTER)
        canvas.arc(counter, RING_RADIUS, PI / 2.0, sweep)

        canvas.text_color(TEXT)
        canvas.font_size(30)
        canvas.text_alignment(Align.TOP)
        canvas.text("Arcs", (0, canvas.top() - 38))

        canvas.font_size(18)
        canvas.text(
            "One tween, swept clockwise and counter-clockwise from the top",
            (0, canvas.top() - 78),
        )


def main() raises:
    run[App]("Arcs", width=1280, height=800)
