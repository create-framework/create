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
comptime LABEL_WIDTH = 100.0  # the names before the sliders
comptime TURN_SPEED = 0.6  # radians a second

# The shadow the controls start at, and go back to on Reset.
comptime BLUR = 12.0
comptime SPREAD = 0.0
comptime OFFSET = Vector(6, -6)
comptime DARKNESS = 140.0


def add_setting(
    mut ui: UI,
    column: WidgetHandle[Column],
    name: String,
    value: Float64,
    minimum: Float64,
    maximum: Float64,
) -> WidgetHandle[Slider]:
    """A line of the panel: `name`, and a slider beside it setting one part
    of the shadow, in whole steps."""
    var line = ui.add(Row(), column)
    _ = ui.add(Label(name, alignment=Align.LEFT), line, width=LABEL_WIDTH)
    return ui.add(Slider(value, minimum, maximum, step=1), line)


@fieldwise_init
struct Shadows(Program):
    var ui: UI
    var panel: WidgetHandle[Panel]
    var blur: WidgetHandle[Slider]
    var spread: WidgetHandle[Slider]
    var offset_x: WidgetHandle[Slider]
    var offset_y: WidgetHandle[Slider]
    var darkness: WidgetHandle[Slider]
    """The shadow's alpha, 0 (invisible) to 255 (black)."""
    var inset: WidgetHandle[Checkbox]
    var follows_transform: WidgetHandle[Checkbox]
    var reset: WidgetHandle[Button]
    var logo: Image
    var angle: Float64

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> Shadows:
        # The panel of widgets on the left, each setting one part of the
        # shadow. `update` places the panel, and its column fills it.
        var ui = UI()
        ui.colors(COLORS)
        var panel = ui.add(Panel())
        var column = ui.add(Column(), panel)
        _ = ui.add(Label("Shadows", style=Style(font_size=28)), column)
        _ = ui.add(Space(), column)

        var blur = add_setting(ui, column, "Blur", BLUR, 0, 40)
        var spread = add_setting(ui, column, "Spread", SPREAD, 0, 20)
        var offset_x = add_setting(ui, column, "Offset x", OFFSET.x, -20, 20)
        var offset_y = add_setting(ui, column, "Offset y", OFFSET.y, -20, 20)
        var darkness = add_setting(ui, column, "Darkness", DARKNESS, 0, 255)

        _ = ui.add(Space(), column)
        var inset = ui.add(Checkbox("Inset"), column)
        var follows = ui.add(Checkbox("Follows transform"), column)

        _ = ui.add(Space(), column)
        var reset = ui.add(Button("Reset", variant=ButtonVariant.TONAL), column)

        return Shadows(
            ui=ui^,
            panel=panel,
            blur=blur,
            spread=spread,
            offset_x=offset_x,
            offset_y=offset_y,
            darkness=darkness,
            inset=inset,
            follows_transform=follows,
            reset=reset,
            logo=Image.load("../../assets/logo/png/logo-light-cutout.png"),
            angle=0,
        )

    def put_back(mut self):
        """Put every control back as it starts."""
        self.ui[self.blur].value = BLUR
        self.ui[self.spread].value = SPREAD
        self.ui[self.offset_x].value = OFFSET.x
        self.ui[self.offset_y].value = OFFSET.y
        self.ui[self.darkness].value = DARKNESS
        self.ui[self.inset].checked = False
        self.ui[self.follows_transform].checked = False

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        self.angle += TURN_SPEED * context.time.delta

        canvas.background(BACKGROUND)

        # The panel takes the left quarter of the screen, and the tiles the
        # rest.
        var halves = (
            canvas.bounds().inset(MARGIN).columns(weights=[1, 3], gap=GAP)
        )
        self.ui[self.panel].rect = halves[0]
        self.ui.update(context, canvas)
        canvas.draw(self.ui)

        if self.ui[self.reset].released():
            self.put_back()

        # Every tile is drawn with the shadow the controls set. The tiles
        # themselves are drawn first, outside the block, so they cast none.
        var rows = halves[1].rows(2, gap=GAP)
        var tiles = rows[0].columns(3, gap=GAP) + rows[1].columns(3, gap=GAP)
        with canvas.style(fill=TILE, stroke_enabled=False):
            for tile in tiles:
                canvas.rectangle(
                    tile.position, tile.width, tile.height, corner_radius=16
                )

        ref ui = self.ui
        with canvas.style(
            shadow=SHADOW.with_alpha(UInt8(Int(ui.get(self.darkness).value))),
            shadow_offset=Vector(
                ui.get(self.offset_x).value, ui.get(self.offset_y).value
            ),
            shadow_blur=ui.get(self.blur).value,
            shadow_spread=ui.get(self.spread).value,
            shadow_inset=ui.get(self.inset).checked,
            shadow_follows_transform=ui.get(self.follows_transform).checked,
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
