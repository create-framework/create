"""Images: loaded from a file, built pixel by pixel, read back and tinted.

Along the top, one picture saved as JPEG, PNG and BMP, each loaded with
`Image.load`.

Below, a colour wheel built cell by cell in a `PixelBuffer`, then made an
`Image`. Hover it to tint the pictures with the colour under the mouse, read
back with `image.pixel`: a tint multiplies every pixel, so the white centre
leaves them as they are.
"""

from create import *

comptime COLORS = ColorScheme.dark()
comptime BACKGROUND = COLORS.background
comptime TEXT = COLORS.on_surface
comptime HINT = COLORS.on_surface_variant
comptime SIZE = 220.0
"""How big each loaded picture is drawn, in design units."""
comptime ROW_Y = 120.0
comptime WHEEL_POSITION = Point(0, -200)
comptime WHEEL_SIZE = 200.0
"""How big the colour wheel is drawn, in design units."""
comptime WHEEL_CELLS = 400
"""The wheel's width and height in pixels: twice its drawn size, so it stays
smooth on a window scaled up to twice the design."""


def formats() -> List[String]:
    return ["jpeg", "png", "bmp"]


def color_wheel() raises -> Image:
    """Every hue around the rim, paling to white at the centre, set one
    cell at a time. A buffer starts transparent, so the corners outside the
    wheel stay see-through."""
    var buffer = PixelBuffer(WHEEL_CELLS, WHEEL_CELLS)
    var radius = Float64(WHEEL_CELLS) / 2

    for y in range(WHEEL_CELLS):
        for x in range(WHEEL_CELLS):
            # From the wheel's centre to the middle of the cell, y up.
            var offset = Vector(
                Float64(x) + 0.5 - radius, radius - Float64(y) - 0.5
            )
            var distance = offset.magnitude()
            if distance >= radius:
                continue

            var color = Color.hsv(degrees(offset.angle()), distance / radius, 1)
            # The outermost cell fades out, so the rim is smooth.
            var edge = clamp(radius - distance, 0, 1)
            buffer.set(x, y, color.with_alpha(UInt8(edge * 255)))

    # The buffer is handed over, not copied: it can't be used after this.
    return Image(buffer^)


@fieldwise_init
struct Images(Program):
    var pictures: List[Image]
    """The same picture from each format in `formats()`."""
    var wheel: Image

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> Images:
        var pictures = List[Image]()
        for format in formats():
            pictures.append(Image.load("assets/sprite." + format))

        return Images(pictures=pictures^, wheel=color_wheel())

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        # The colour under the mouse on the wheel tints the pictures; off
        # the wheel, white leaves them as they are.
        var tint = Color.WHITE

        # From the mouse to a cell of the wheel: measured from its top-left
        # corner, y down, and scaled from the drawn size to the image's own.
        var corner = WHEEL_POSITION + Vector(-WHEEL_SIZE / 2, WHEEL_SIZE / 2)
        var scale = Float64(WHEEL_CELLS) / WHEEL_SIZE
        var column = Int(floor((context.mouse.position.x - corner.x) * scale))
        var row = Int(floor((corner.y - context.mouse.position.y) * scale))

        if 0 <= column < WHEEL_CELLS and 0 <= row < WHEEL_CELLS:
            var color = self.wheel.pixel(column, row)
            # Outside the circle the wheel is transparent.
            if color.a > 0:
                tint = color.with_alpha(255)

        canvas.background(BACKGROUND)

        var all_formats = formats()
        for i in range(len(self.pictures)):
            var center = Point(Float64(i - 1) * 300, ROW_Y)
            with canvas.style(tint=tint):
                canvas.image(self.pictures[i], center, SIZE, SIZE)
            with canvas.style(text_color=HINT, font_size=18):
                canvas.text(
                    "sprite." + all_formats[i],
                    (center.x, ROW_Y - SIZE / 2 - 30),
                )

        with canvas.style(text_color=TEXT, font_size=18):
            canvas.text(
                "Hover colorwheel to tint the pictures",
                (0, ROW_Y + SIZE / 2 + 50),
            )

        canvas.image(self.wheel, WHEEL_POSITION, WHEEL_SIZE, WHEEL_SIZE)


def main() raises:
    run[Images]("Image", width=1280, height=720)
