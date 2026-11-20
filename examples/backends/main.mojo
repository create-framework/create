"""One scene to run on each backend, CPU and GPU, made of the cases where
they could disagree.

    pixi run example backends                 # CPU
    pixi run example backends gpu             # the same scene through the GPU
    pixi run example backends gpu fullscreen  # letterboxed on a wide display

The two frames should look the same, apart from the GPU's multisampled
edges. The scene has filled and stroked rectangles and circles, a
translucent fill under a stroke, a stroke wider than its shape, a turning
rectangle, a diagonal line, text at each alignment and one image at two
sizes. In full screen it also has the letterbox bars of `FIT`: the 4:3
design keeps its size, so on a 16:9 display the bars show from the first
frame. A cycles the antialiasing level, to compare the edges at each, and
Escape quits.
"""

from std.sys import argv

from create import *

comptime _BACKGROUND = Color(40, 40, 44)
comptime _CREAM = Color(240, 236, 222)
comptime _ROSE = Color(201, 140, 150)
comptime _INDIGO = Color(98, 104, 168)
comptime _LAVENDER = Color(150, 154, 206)
comptime _RED = Color(226, 46, 56)
comptime _CHARCOAL = Color(30, 30, 33)


@fieldwise_init
struct App(Program):
    var angle: Float64
    var logo: Image
    var fps: Int

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> App:
        # Twice, below, from one interned image and so one GL upload.
        var logo = Image.load("../../assets/logo/png/logo.png")
        return App(0.0, logo^, 0)

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        self.angle += context.time.delta
        self.fps = Int(context.frame_rate())
        if context.keyboard.pressed(Key.A):
            # The level is the canvas's: it lasts until changed, and covers
            # this whole frame.
            canvas.antialiasing(
                Antialiasing((canvas.antialiasing().value + 1) % 4)
            )

        canvas.background(_BACKGROUND)

        # A plain filled rectangle and a stroked one, side by side.
        with canvas.style(fill=_INDIGO, stroke_enabled=False):
            canvas.rectangle((-260, 180), 160, 100)

        with canvas.style(
            fill=_ROSE,
            stroke=Color.BLACK,
            stroke_thickness=6,
        ):
            canvas.rectangle((-60, 180), 160, 100)

        # A stroke wider than the shape: all stroke, no interior.
        with canvas.style(
            fill=_RED,
            stroke=_CREAM,
            stroke_thickness=30,
        ):
            canvas.rectangle((160, 180), 40, 40)

        # Translucent over the indigo rectangle: the case a double-blended fill
        # under its own stroke would get visibly wrong.
        with canvas.style(
            fill=_ROSE.with_alpha(0x80),
            stroke=_CREAM.with_alpha(0x80),
            stroke_thickness=8,
        ):
            canvas.circle((-260, 180), 70)

        with canvas.style(fill=_RED, stroke_enabled=False):
            canvas.circle((0, 0), 90)

        with canvas.style(
            fill=_CHARCOAL,
            stroke=_ROSE,
            stroke_thickness=10,
        ):
            canvas.circle((220, 0), 80)

        # A rotating rectangle: the transform is baked per vertex, so a rotated
        # stroke ring has to follow the shape rather than stay axis-aligned.
        with canvas.transform(
            Transform(translation=Vector(-230, 0), rotation=self.angle)
        ):
            with canvas.style(
                fill=_CREAM,
                stroke=Color.BLACK,
                stroke_thickness=4,
            ):
                canvas.rectangle((0, 0), 120, 120)

        with canvas.style(stroke=_LAVENDER, stroke_thickness=5):
            canvas.line((-340, -140), (340, -260))

        with canvas.style(
            fill=_LAVENDER,
            stroke=_CREAM,
            stroke_thickness=3,
        ):
            canvas.triangle((-140, -180), (40, -180), (-50, -30))

        # The same image at two sizes: one texture, one upload and (since
        # the two renders are adjacent) one extra batch for the pair.
        # Text before the images: solids and glyphs share the atlas binding
        # and so share one batch, which the image texture then breaks.
        with canvas.style(
            text_color=_CREAM,
            font_size=28,
            text_alignment=Align.CENTER,
        ):
            canvas.text("Centre / middle", (0, 0))

        with canvas.style(
            text_color=_ROSE,
            font_size=20,
            text_alignment=Align.TOP_LEFT,
        ):
            canvas.text("Left / top", (canvas.left() + 12, canvas.top() - 12))

        with canvas.style(
            text_color=_CREAM.with_alpha(0xA0),
            font_size=20,
            text_alignment=Align.BOTTOM_RIGHT,
        ):
            canvas.text(
                "Right / bottom — translucent",
                (canvas.right() - 12, canvas.bottom() + 12),
            )

        canvas.image(self.logo, (250, -170), 140, 140)
        canvas.image(self.logo, (90, -230), 70, 70)

        with canvas.style(
            text_color=_CREAM,
            font_size=20,
            text_alignment=Align.TOP_RIGHT,
        ):
            canvas.text(
                "FPS: " + String(self.fps),
                (canvas.right() - 12, canvas.top() - 12),
            )
            canvas.text(
                String(canvas.antialiasing()) + " (A to cycle)",
                (canvas.right() - 12, canvas.top() - 40),
            )


def main() raises:
    var mode = WindowMode.WINDOWED
    for i in range(1, len(argv())):
        if argv()[i] == "fullscreen":
            mode = WindowMode.FULLSCREEN
    # `gpu` on the command line runs it on the GPU; calling `run` once for
    # each backend compiles both
    if RenderBackend.from_arguments() == RenderBackend.GPU:
        run[App, backend=RenderBackend.GPU](
            "Backends", mode, width=800, height=600
        )
    else:
        run[App]("Backends", mode, width=800, height=600)
