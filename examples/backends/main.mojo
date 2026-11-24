"""One scene to run on each backend, CPU and GPU, made of the cases where
they could disagree.

    pixi run example backends cpu             # CPU
    pixi run example backends gpu             # the same scene through the GPU
    pixi run example backends gpu fullscreen  # letterboxed on a wide display

The two frames should look the same, apart from the GPU's multisampled
edges. Each card holds one case: a filled and stroked shape, translucent
fills under a translucent stroke, a turning square whose stroke follows the
turn, a fan of thin lines, a gradient inside a sweeping arc, and an image.
In full screen the scene also has the letterbox bars of `FIT`: the 4:3
design keeps its size, so on a 16:9 display the bars show from the first
frame. A cycles the antialiasing level, to compare the edges at each.
"""

from std.sys import argv

from create import *

comptime COLORS = ColorScheme.dark()
comptime BACKGROUND = COLORS.background
comptime CARD = COLORS.surface_container
comptime TEXT = COLORS.on_surface
comptime CAPTION = COLORS.on_surface_variant
comptime OUTLINE = COLORS.on_surface

comptime GRID = Rectangle((0, -30), 720, 440)
"""The area the cards are laid out in, below the header."""
comptime GAP = 20.0
comptime TURN_SPEED = 0.6
"""How fast the square turns and the arc sweeps, in radians per second."""


def captions() -> List[String]:
    return [
        "Fill and stroke",
        "Translucency",
        "Rotation",
        "Thin lines",
        "Gradient and arc",
        "Image",
    ]


@fieldwise_init
struct App(Program):
    var backend: RenderBackend
    """The backend `run` was given: `from_arguments` returns the same backend
    in `main` and here, and asks for it only once."""
    var logo: Image
    var angle: Float64

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> App:
        var logo = Image.load("../../assets/logo/png/logo-cutout.png")
        return App(RenderBackend.from_arguments(), logo^, 0.0)

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        self.angle += TURN_SPEED * context.time.delta
        if context.keyboard.pressed(Key.A):
            # The level is the canvas's: it lasts until changed, and covers
            # this whole frame.
            canvas.antialiasing(
                Antialiasing((canvas.antialiasing().value + 1) % 4)
            )

        canvas.background(BACKGROUND)

        var cards = List[Rectangle]()
        for row in GRID.rows(2, gap=GAP):
            for card in row.columns(3, gap=GAP):
                cards.append(card)
        var names = captions()
        with canvas.style(fill=CARD, stroke_enabled=False):
            for card in cards:
                canvas.rectangle(
                    card.center(), card.width, card.height, corner_radius=16
                )
        with canvas.style(text_color=CAPTION, font_size=16):
            for i in range(len(cards)):
                canvas.text(
                    names[i], (cards[i].center().x, cards[i].bottom() + 24)
                )

        # Each case sits a little above its card's centre, clear of the
        # caption.
        var centers = List[Point]()
        for card in cards:
            centers.append(card.center() + Vector(0, 14))

        # Fill and stroke.
        with canvas.style(fill=Color.RED, stroke=OUTLINE, stroke_thickness=6):
            canvas.rectangle(centers[0], 96, 96, corner_radius=14)

        # Translucent fills under a translucent stroke: where a fill blended
        # twice under its own stroke would show.
        with canvas.style(stroke=OUTLINE.with_alpha(0x99), stroke_thickness=6):
            canvas.fill(Color.CYAN.with_alpha(0x99))
            canvas.circle(centers[1] - Vector(24, 0), 44)
            canvas.fill(Color.MAGENTA.with_alpha(0x99))
            canvas.circle(centers[1] + Vector(24, 0), 44)

        # A turning square: the transform is baked per vertex, so the stroke
        # has to follow the shape rather than stay axis-aligned.
        with canvas.transform(
            Transform(translation=Vector(centers[2]), rotation=self.angle)
        ):
            with canvas.style(
                fill=Color.YELLOW, stroke=OUTLINE, stroke_thickness=4
            ):
                canvas.rectangle((0, 0), 84, 84, corner_radius=10)

        # A fan of hairlines, where edge smoothing differs most.
        var corner = centers[3] - Vector(60, 60)
        with canvas.style(stroke=Color.GREEN, stroke_thickness=1.5):
            for i in range(9):
                var direction = Vector.from_angle(Float64(i) * PI / 16.0, 120)
                canvas.line(corner, corner + direction)

        # A radial gradient, lit from the top left, inside a sweeping arc.
        canvas.fill(
            Gradient.radial(Color.CYAN, Color.BLUE, center=(-0.35, 0.35))
        )
        canvas.stroke_enabled(False)
        canvas.circle(centers[4], 46)
        with canvas.style(
            stroke=Color.CYAN, stroke_thickness=6, stroke_cap=StrokeCap.ROUND
        ):
            canvas.arc(centers[4], 66, self.angle * 1.5, PI)

        canvas.image(self.logo, centers[5], 150, 150)

        var backend = "GPU" if self.backend == RenderBackend.GPU else "CPU"
        with canvas.style(text_color=TEXT, font_size=20):
            canvas.text_alignment(Align.TOP_LEFT)
            canvas.text(
                "Render backend: "
                + backend
                + "\nFPS: "
                + String(Int(context.frame_rate())),
                (canvas.left() + 20, canvas.top() - 20),
            )
        with canvas.style(
            text_color=CAPTION, font_size=16, text_alignment=Align.TOP_RIGHT
        ):
            canvas.text(
                String(canvas.antialiasing()) + "\nPress A to cycle",
                (canvas.right() - 20, canvas.top() - 20),
            )


def main() raises:
    var mode = WindowMode.WINDOWED
    for i in range(1, len(argv())):
        if argv()[i] == "fullscreen":
            mode = WindowMode.FULLSCREEN
    run[App](
        "Backends",
        mode,
        width=800,
        height=600,
        backend=RenderBackend.from_arguments(),
    )
