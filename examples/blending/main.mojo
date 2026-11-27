"""Blend modes, each easiest to read against a range of brightness.

The circles cross bars from black to white:

    ADD       light: brightens, saturating to white over the light bars
    SUBTRACT  takes light away: vanishes over black, darkens elsewhere
    MULTIPLY  tinted film: plain colour over white, black stays black
    SCREEN    softer ADD: brightens without burning out to white

Space cycles the modes.
"""

from create import *

comptime BARS = 8
comptime COLORS = ColorScheme.dark()
comptime TEXT = COLORS.on_surface
comptime PANEL = COLORS.background.with_alpha(180)


def next_mode(mode: BlendMode) -> BlendMode:
    if mode == BlendMode.NORMAL:
        return BlendMode.ADD
    if mode == BlendMode.ADD:
        return BlendMode.SUBTRACT
    if mode == BlendMode.SUBTRACT:
        return BlendMode.MULTIPLY
    if mode == BlendMode.MULTIPLY:
        return BlendMode.SCREEN
    return BlendMode.NORMAL


@fieldwise_init
struct App(Program):
    var mode: BlendMode

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> App:
        return App(BlendMode.NORMAL)

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        if context.keyboard.pressed(Key.SPACE):
            self.mode = next_mode(self.mode)

        # Grey bars, black on the left to white on the right. Measured from
        # the edges, since the origin is the middle of the screen.
        #
        # Each bar reaches all the way to the right edge and the next one
        # paints over it. Bars that merely abutted would each antialias their
        # shared edge against the clear colour underneath, which shows as a
        # thin light seam whenever the window scale puts an edge mid-pixel.
        canvas.background(Color.BLACK)
        canvas.stroke_enabled(False)

        var bar_w = (canvas.right() - canvas.left()) / Float64(BARS)
        for i in range(BARS):
            var gray = UInt8(i * 255 // (BARS - 1))
            canvas.fill(Color(gray, gray, gray))
            var x0 = canvas.left() + Float64(i) * bar_w
            canvas.rectangle(
                ((x0 + canvas.right()) / 2, 0),
                canvas.right() - x0,
                canvas.height(),
            )

        # Three overlapping circles, turning slowly while the cluster swings
        # from the black bar to the white one. Only these render under the
        # mode: the guard puts everything after it back to NORMAL.
        var t = context.time.elapsed
        var center_x = 0.55 * canvas.right() * sin(t * 0.5)

        # The primaries a quarter of the way to white: with every channel at
        # 0 or 255, SCREEN and ADD give identical results.
        var colors = [
            Color.RED.lerp(Color.WHITE, 0.25),
            Color.GREEN.lerp(Color.WHITE, 0.25),
            Color.BLUE.lerp(Color.WHITE, 0.25),
        ]

        with canvas.style(blend_mode=self.mode):
            for i in range(3):
                var angle = t * 0.8 + Float64(i) * 2 * PI / 3
                canvas.fill(colors[i])
                canvas.circle(
                    (center_x + 70 * cos(angle), 40 + 70 * sin(angle)),
                    110,
                )

        # A plain panel behind the label, so it reads over any bar.
        canvas.fill(PANEL)
        canvas.rectangle((0, canvas.bottom() + 60), 360, 100)

        canvas.text_color(TEXT)
        canvas.font_size(28)
        canvas.text(String(self.mode), (0, canvas.bottom() + 75))
        canvas.font_size(18)
        canvas.text("(Space to cycle)", (0, canvas.bottom() + 45))


def main() raises:
    run[App]("Blending", width=800, height=600)
