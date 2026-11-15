# Images

Loading and drawing images, and building an image pixel by pixel. Drawing shapes and text into an
image of your own is in [Pixels](pixels.md#drawing-into-an-image), and animating a sprite sheet
in [Animation](animation.md#sprite-animation).

## Drawing an image

An `Image` is loaded once, in `create`, kept as a field and drawn with `canvas.image`:

```mojo
from create import *


@fieldwise_init
struct Sprites(Program):
    var player: Image

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> Sprites:
        return Sprites(Image.load("assets/player.png"))

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        canvas.background(Color.WHITE)
        canvas.image(self.player, (-200, 0))  # at its own size
        canvas.image(self.player, (0, 0), 128, 128)  # stretched to 128 by 128
        with canvas.style(tint=Color.RED, opacity=0.5):
            canvas.image(self.player, (200, 0))  # reddened, half transparent


def main() raises:
    run[Sprites]("Sprites")
```

- **`Image.load(path)`** reads a PNG, JPEG or BMP file. A relative path is relative to the source
  file that makes the call (see [File paths](programs.md#file-paths)).
- **`canvas.image(image, position)`** draws the image centred on `position`, like every shape,
  one unit per image pixel. `canvas.image(image, position, width, height)` stretches it to that
  size. Either way it is the right way up, although y points up.
- **It is a render call like any other:** the transform turns, scales and mirrors it, the camera
  places it, and the style's `tint`, `opacity`, `blend_mode` and shadow apply (an image casts the
  shadow of its opaque pixels). Fill and stroke don't apply. See [Style](style.md).
- `image.width()` and `image.height()` are its size in pixels, `Image.solid(width, height, color)`
  is an image of one colour, and `image.resize(width, height)` returns a resized copy, nearest
  pixel.
- An `Image` is an asset: copying one is cheap, since copies share their pixels, and drawing one
  costs no copy either (see [Assets and playheads](programs.md#assets-and-playheads)). An image
  not drawn for 120 frames is dropped from the renderer's cache, so drawing a fresh image every
  frame, such as a snapshot, uses bounded memory.

See [examples/image](../examples/image/main.mojo).

## Building an image pixel by pixel

**An `Image` is immutable**, an asset like `Sound`: `image.pixel(x, y)` reads it, nothing writes
it. To build one pixel by pixel, fill a `PixelBuffer` with `set(x, y, color)` (read back with
`pixel(x, y)`; it starts transparent), then `Image(buffer^)` takes the pixels over without copying:

```mojo
# An 8 by 8 checkerboard:
var buffer = PixelBuffer(8, 8)
for y in range(8):
    for x in range(8):
        if (x + y) % 2 == 0:
            buffer.set(x, y, Color.BLACK)
var board = Image(buffer^)
```

Both use **image coordinates**: top-left origin, y down, whole `Int` cells. This is the one place
a position is two numbers rather than a `Point2D`, since a cell is not a point in the program's
space. Off the image, reads are transparent and writes do nothing. "Pixel" always names such a
cell; a colour at a screen point is `canvas.color_at`.

Shapes, text and gradients go into an image through an offscreen `Canvas` instead (see
[Drawing into an image](pixels.md#drawing-into-an-image)).
