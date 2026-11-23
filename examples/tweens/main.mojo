"""Easing curves side by side, played by one `Tween`.

Hover a row to play its curve.
"""

from create import *

comptime COLORS = ColorScheme.dark()
comptime BACKGROUND = COLORS.background
comptime TEXT = COLORS.on_surface
comptime HINT = COLORS.on_surface_variant
comptime TRACK = COLORS.outline_variant
comptime ACTIVE_TRACK = COLORS.outline
comptime DOT = Color.CYAN
comptime ACTIVE_LABEL = Color.RED

comptime ROW_SPACING = 70.0
comptime TOP_ROW = 250.0
comptime TRACK_START = -360.0
comptime TRACK_END = 580.0


def curves() -> List[Easing]:
    # LINEAR first so every other row reads as a departure from it.
    return [
        Easing.LINEAR,
        Easing.IN_OUT_QUAD,
        Easing.OUT_CUBIC,
        Easing.IN_OUT_CUBIC,
        Easing.OUT_SINE,
        Easing.OUT_EXPO,
        Easing.OUT_BACK,
        Easing.OUT_ELASTIC,
        Easing.OUT_BOUNCE,
    ]


@fieldwise_init
struct App(Program):
    var clock: Tween
    """The hovered row's playhead. The rows differ only in which curve they
    bend `clock.progress` with, so one tween serves whichever is hovered:
    `ease` needs no state of its own."""

    var curves: List[Easing]
    var hovered: Int
    """The row under the mouse, or -1 for none."""

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> App:
        return App(clock=Tween(1.6), curves=curves(), hovered=-1)

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        var hovered = -1
        for i in range(len(self.curves)):
            if abs(context.mouse.position.y - row_y(i)) < ROW_SPACING / 2.0:
                hovered = i
        if hovered != self.hovered:
            # ping_pong rather than loop: progress runs back down on the
            # return leg, so the dot travels its curve backwards instead of
            # snapping to the start.
            self.hovered = hovered
            self.clock.ping_pong()

        canvas.background(BACKGROUND)

        canvas.text_color(TEXT)
        canvas.font_size(30)
        canvas.text_alignment(Align.TOP)
        canvas.text("Easing and tweens", (0, canvas.top() - 38))
        canvas.font_size(18)
        canvas.text_color(HINT)
        canvas.text("Hover over a curve to play it", (0, canvas.top() - 82))

        canvas.text_alignment(Align.LEFT)
        for i in range(len(self.curves)):
            var y = row_y(i)
            var active = i == self.hovered
            canvas.stroke(ACTIVE_TRACK if active else TRACK, thickness=3)
            canvas.line((TRACK_START, y), (TRACK_END, y))

            # A resting row sits at the start of its track. OUT_BACK and
            # OUT_ELASTIC leave 0..1 mid-run, so the hovered dot visibly
            # overshoots the ends of its track.
            var t = 0.0
            if active:
                t = ease(self.curves[i], self.clock.progress())
            with canvas.style(fill=DOT, stroke_enabled=False):
                canvas.circle((lerp(TRACK_START, TRACK_END, t), y), 11)

            canvas.text_color(ACTIVE_LABEL if active else HINT)
            canvas.text(String(self.curves[i]), (canvas.left() + 26, y))


def row_y(i: Int) -> Float64:
    return TOP_ROW - Float64(i) * ROW_SPACING


def main() raises:
    run[App]("Easing and tweens", width=1280, height=800)
