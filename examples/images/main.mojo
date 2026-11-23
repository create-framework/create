"""Images: loaded from a file, built pixel by pixel, read back and tinted.

Along the top, one picture saved as JPEG, PNG and BMP, each loaded with
`Image.load`; hover one to read the pixel under the mouse with
`image.pixel`. Pixels are cells of the image, counted from its top-left
corner with y down, so the mouse's position is converted first.

Below, a sprite built cell by cell in a `PixelBuffer`, then made an `Image`.
W, A, S and D move it; T cycles the `tint` that recolours it, a multiply of
every pixel, so white keeps each colour and cyan, magenta and yellow
filter it.
"""

from create import *

comptime COLORS = ColorScheme.dark()
comptime BACKGROUND = COLORS.background
comptime TEXT = COLORS.on_surface
comptime HINT = COLORS.on_surface_variant
comptime SIZE = 220.0
"""How big each loaded picture is drawn, in design units."""
comptime ROW_Y = 120.0
comptime SPRITE_CELLS = 16
comptime SPRITE_SIZE = 128.0
comptime SPEED = 400.0
"""How fast the sprite moves, in design units per second."""


def formats() -> List[String]:
    return ["jpeg", "png", "bmp"]


def tints() -> List[Color]:
    return [Color.WHITE, Color.CYAN, Color.MAGENTA, Color.YELLOW]


def ring_colors() -> List[Color]:
    return [
        Color.RED,
        Color.YELLOW,
        Color.GREEN,
        Color.CYAN,
        Color.BLUE,
        Color.MAGENTA,
    ]


def sprite() raises -> Image:
    """A ring of colours, set one cell at a time. A buffer starts
    transparent, so the corners outside the ring stay see-through."""
    var buffer = PixelBuffer(SPRITE_CELLS, SPRITE_CELLS)
    var middle = Float64(SPRITE_CELLS - 1) / 2.0
    var colors = ring_colors()
    for y in range(SPRITE_CELLS):
        for x in range(SPRITE_CELLS):
            var offset = Vector(Float64(x) - middle, middle - Float64(y))
            var distance = offset.magnitude()
            if distance <= middle + 0.5:
                # Round the ring through `ring_colors()`, darker inside.
                var around = (offset.angle() / TAU + 0.5) * Float64(len(colors))
                var i = Int(around) % len(colors)
                var color = colors[i].lerp(
                    colors[(i + 1) % len(colors)], around - Float64(Int(around))
                )
                if distance < middle / 2.0:
                    color = color.lerp(BACKGROUND, 0.45)
                buffer.set(x, y, color)
    # The buffer is handed over, not copied: it can't be used after this.
    return Image(buffer^)


@fieldwise_init
struct Images(Program):
    var pictures: List[Image]
    """The same picture from each format in `formats()`."""
    var sprite: Image
    var position: Point
    var tint: Int
    """Which of `tints()` the sprite is drawn with."""

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> Images:
        var pictures = List[Image]()
        for format in formats():
            pictures.append(Image.load("assets/image." + format))
        return Images(
            pictures=pictures^,
            sprite=sprite(),
            position=Point(0, -170),
            tint=0,
        )

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        var step = SPEED * context.time.delta
        var x = self.position.x
        var y = self.position.y
        if context.keyboard.down(Key.W):
            y += step
        if context.keyboard.down(Key.S):
            y -= step
        if context.keyboard.down(Key.A):
            x -= step
        if context.keyboard.down(Key.D):
            x += step
        # Kept on screen, measured from the edges since the origin is the
        # middle of the screen.
        var half = SPRITE_SIZE / 2.0
        self.position = Point(
            clamp(x, canvas.left() + half, canvas.right() - half),
            clamp(y, canvas.bottom() + half, canvas.top() - half),
        )
        if context.keyboard.pressed(Key.T):
            self.tint = (self.tint + 1) % len(tints())

        canvas.background(BACKGROUND)

        var all_formats = formats()
        var reading = String("Hover a picture to read its pixels")
        for i in range(len(self.pictures)):
            ref picture = self.pictures[i]
            var center = Point(Float64(i - 1) * 300.0, ROW_Y)
            canvas.image(picture, center, SIZE, SIZE)
            with canvas.style(text_color=HINT, font_size=18):
                canvas.text(
                    "image." + all_formats[i], (center.x, ROW_Y - SIZE / 2 - 24)
                )

            # From the mouse to a cell: measured from the top-left corner,
            # y down, and scaled from the drawn size to the image's own.
            var left = center.x - SIZE / 2.0
            var top = center.y + SIZE / 2.0
            var column = Int(
                (context.mouse.position.x - left)
                / SIZE
                * Float64(picture.width())
            )
            var row = Int(
                (top - context.mouse.position.y)
                / SIZE
                * Float64(picture.height())
            )
            if (
                column >= 0
                and column < picture.width()
                and row >= 0
                and row < picture.height()
            ):
                var color = picture.pixel(column, row)
                reading = String(
                    "image.",
                    all_formats[i],
                    ".pixel(",
                    column,
                    ", ",
                    row,
                    ") is ",
                    color,
                )
                with canvas.style(fill=color, stroke=TEXT, stroke_thickness=2):
                    canvas.rectangle(
                        context.mouse.position + Vector(30, 30), 36, 36
                    )

        with canvas.style(text_color=TEXT, font_size=18):
            canvas.text(reading, (0.0, ROW_Y + SIZE / 2 + 30))

        var tint = tints()[self.tint]
        with canvas.style(tint=tint):
            canvas.image(self.sprite, self.position, SPRITE_SIZE, SPRITE_SIZE)
        with canvas.style(text_color=HINT, font_size=18):
            canvas.text(
                "W, A, S and D move the sprite; T tints it: " + String(tint),
                (0.0, canvas.bottom() + 30),
            )


def main() raises:
    run[Images]("Image", width=1280, height=720)
