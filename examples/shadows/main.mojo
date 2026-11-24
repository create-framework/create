"""One shadow, cast by six kinds of subject, and set with the widgets.

The sliders and checkboxes on the left set a single shadow, and every tile
on the right is drawn with it, so you can see what each part does and what
each kind of render call casts: a fill its shape, a shape with no fill only
its stroke, text its letters, an image its opaque pixels and a curve its
stroke. With Inset on, each casts it inside itself instead: within its fill,
its stroke, its letters or its opaque pixels.
Follows transform turns the turning triangle's shadow with it.

    pixi run example shadows cpu    # CPU
    pixi run example shadows gpu    # the same scene through the GPU backend
"""

from create import *

comptime COLORS = ColorScheme.dark()
comptime BACKGROUND = COLORS.background
comptime TILE = COLORS.surface_container_highest
"""Lighter than the background, so the shadows show against it."""
comptime CAPTION = COLORS.on_surface_variant
comptime SHADOW = Color.BLACK

comptime MARGIN = 24.0
comptime GAP = 24.0
comptime SUBJECT = 140.0
"""How big each subject is drawn, across."""
comptime TURN_SPEED = 0.6  # radians a second

# The shadow the controls start at, and go back to on Reset.
comptime BLUR = 12.0
comptime SPREAD = 0.0
comptime OFFSET = Vector(6, -6)
comptime DARKNESS = 140.0


@fieldwise_init
struct Shadows(Program):
    var ui: UI
    var logo: Image
    var blur: Float64
    var spread: Float64
    var offset_x: Float64
    var offset_y: Float64
    var darkness: Float64
    """The shadow's alpha, 0 (invisible) to 255 (black)."""
    var inset: Bool
    var follows_transform: Bool
    var angle: Float64

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> Shadows:
        return Shadows(
            ui=UI(),
            logo=Image.load("../../assets/logo/png/logo-light-cutout.png"),
            blur=BLUR,
            spread=SPREAD,
            offset_x=OFFSET.x,
            offset_y=OFFSET.y,
            darkness=DARKNESS,
            inset=False,
            follows_transform=False,
            angle=0,
        )

    def reset(mut self):
        """Put every control back as it starts."""
        self.blur = BLUR
        self.spread = SPREAD
        self.offset_x = OFFSET.x
        self.offset_y = OFFSET.y
        self.darkness = DARKNESS
        self.inset = False
        self.follows_transform = False

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        self.angle += TURN_SPEED * context.time.delta
        canvas.background(BACKGROUND)

        var halves = (
            canvas.bounds().inset(MARGIN).columns(weights=[1, 3], gap=GAP)
        )
        self.controls(context, canvas, halves[0])

        # Every tile is drawn with the shadow the controls set. The tiles
        # themselves are drawn first, outside the block, so they cast none.
        var rows = halves[1].rows(2, gap=GAP)
        var tiles = rows[0].columns(3, gap=GAP) + rows[1].columns(3, gap=GAP)
        with canvas.style(fill=TILE, stroke_enabled=False):
            for tile in tiles:
                canvas.rectangle(
                    tile.position, tile.width, tile.height, corner_radius=16
                )

        with canvas.style(
            shadow=SHADOW.with_alpha(UInt8(Int(self.darkness))),
            shadow_offset=Vector(self.offset_x, self.offset_y),
            shadow_blur=self.blur,
            shadow_spread=self.spread,
            shadow_inset=self.inset,
            shadow_follows_transform=self.follows_transform,
        ):
            self.subjects(canvas, tiles)

        with canvas.style(text_color=CAPTION, font_size=16):
            var captions = [
                "A fill casts its shape",
                "With no fill, only the stroke casts",
                "Text casts its letters",
                "An image casts its opaque pixels",
                "A curve casts its stroke",
                "A turning shape",
            ]
            for i in range(len(tiles)):
                canvas.text(
                    captions[i], (tiles[i].center().x, tiles[i].bottom() + 30)
                )

    def controls(
        mut self, mut context: Context, mut canvas: Canvas, area: Rectangle
    ) raises:
        """The panel of widgets on the left, each setting one part of the
        shadow."""
        with self.ui.screen(context, canvas, COLORS) as ui:
            with ui.panel(area):
                with ui.column():
                    ui.label("Shadows", style=Style(font_size=28))
                    ui.space()
                    with ui.row(2, 3):
                        ui.label("Blur", alignment=Align.LEFT)
                        ui.slider(self.blur, 0, 40, step=1)
                    with ui.row(2, 3):
                        ui.label("Spread", alignment=Align.LEFT)
                        ui.slider(self.spread, 0, 20, step=1)
                    with ui.row(2, 3):
                        ui.label("Offset x", alignment=Align.LEFT)
                        ui.slider(self.offset_x, -20, 20, step=1)
                    with ui.row(2, 3):
                        ui.label("Offset y", alignment=Align.LEFT)
                        ui.slider(self.offset_y, -20, 20, step=1)
                    with ui.row(2, 3):
                        ui.label("Darkness", alignment=Align.LEFT)
                        ui.slider(self.darkness, 0, 255, step=1)
                    ui.space()
                    ui.checkbox("Inset", self.inset)
                    ui.checkbox("Follows transform", self.follows_transform)
                    ui.space()
                    if ui.button("Reset", variant=ButtonVariant.TONAL):
                        self.reset()

    def subjects(self, mut canvas: Canvas, tiles: List[Rectangle]):
        """One subject in each tile, a little above its middle to leave room
        for the caption."""
        var centers = List[Point]()
        for tile in tiles:
            centers.append(tile.center() + Vector(0, 15))

        with canvas.style(fill=Color.CYAN, stroke_enabled=False):
            canvas.rectangle(centers[0], SUBJECT, SUBJECT, corner_radius=20)

        with canvas.style(
            fill_enabled=False, stroke=Color.MAGENTA, stroke_thickness=14
        ):
            canvas.circle(centers[1], SUBJECT / 2)

        with canvas.style(
            text_color=Color.YELLOW, font_size=120, font_weight=FontWeight.BOLD
        ):
            canvas.text("Aa", centers[2])

        # The logo fills only the middle of its square image.
        canvas.image(self.logo, centers[3], SUBJECT * 1.4, SUBJECT * 1.4)

        with canvas.style(
            stroke=Color.GREEN, stroke_thickness=16, stroke_cap=StrokeCap.ROUND
        ):
            canvas.draw(Arc(centers[4], SUBJECT / 2, 0.3, 4.0))

        # Built around the origin, then turned and moved into its tile.
        var r = SUBJECT / 2
        var triangle = Triangle(
            Point(Vector.from_angle(PI / 2, r)),
            Point(Vector.from_angle(PI / 2 + TAU / 3, r)),
            Point(Vector.from_angle(PI / 2 + 2 * TAU / 3, r)),
            corner_radius=10,
        )
        with canvas.style(fill=Color.RED, stroke_enabled=False):
            with canvas.transform(
                Transform(translation=Vector(centers[5]), rotation=self.angle)
            ):
                canvas.draw(triangle)


def main() raises:
    run[Shadows](
        "Shadows",
        width=1280,
        height=720,
        backend=RenderBackend.from_arguments(),
    )
