# Pixels

A pixel is one of the tiny squares of colour a screen, or an image, is made of. Most programs never
need to think about them: they draw shapes, text and images, and Create works out the pixels. Some
programs do need them, though: a colour picker reads the colour under the mouse, a feedback effect
draws the last frame back into the next, and a generated texture is built one pixel at a time. This
page explains how to read back what has been drawn and how to build an image pixel by pixel.

## Reading the screen

`canvas.color_at(position)` returns the `Color` at a point. `canvas.snapshot()` returns an `Image`
of the screen, and `snapshot(region)` an image of part of it; both snapshots take an optional
`pixel_scale=`. All three read what the frame has drawn **so far**. A colour picker:

```mojo
from create import *


@fieldwise_init
struct Picker(Program):
    var spectrum: Gradient

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> Picker:
        var spectrum = Gradient.linear(
            Color.RED, Color.YELLOW, Color.GREEN, Color.BLUE,
            direction=Vector.RIGHT,
        )
        return Picker(spectrum)

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        canvas.background(Color.WHITE)
        canvas.fill(self.spectrum)
        canvas.rectangle((0, 50), 500, 150)
        var picked = canvas.color_at(context.mouse.position)
        canvas.fill(picked)
        canvas.rectangle((0, -120), 100, 100)  # the colour under the mouse


def main() raises:
    run[Picker]("Picker")
```

Reading works the same on both backends and never slows the GPU down: the frame so far is drawn
again on the CPU, as [`save_image`](../media/capture.md#saving-images) does. See
[examples/pixels](../../../examples/pixels/main.mojo).

- **Positions are in screen space**, not world space: the transform and camera don't apply (see
  [Coordinates](../basics/coordinates.md#screen-world-and-local-space)). So
  `canvas.color_at(context.mouse.position)` reads the colour under the mouse as it is. A snapshot's
  region is always upright, and a turned `Rectangle` raises an error. Reading off the screen gives
  transparent.
- **A snapshot is sized by the design:** it is the design size times `pixel_scale` (1 by default),
  without the letterbox bars. So `snapshot()` drawn back with `canvas.image(shot, (0, 0),
  canvas.width(), canvas.height())` lines up exactly, which is how a feedback effect works: each
  frame draws the last one back in, slightly changed. `pixel_scale=canvas.pixel_scale()` gives the
  window's own pixels instead.
- **Many reads cost one:** the frame is drawn again only when something new has been drawn since the
  last read, so many `color_at` calls in a row cost the same as one. Drawing the frame again takes
  about as long as drawing a frame on the CPU, which is fine for picking a colour, a snapshot or a
  feedback effect. Read once per frame, though, rather than once for every object.
- **With `canvas.autoclear(False)`**, the screen keeps the drawing of earlier frames, and reads see
  it too, except for the very first read a program makes. A read draws the frame again on the CPU,
  and the CPU starts keeping its own copy of earlier frames only at that first read, so the first
  read sees only its own frame's drawing. A recording keeps its copy from its first frame on (see
  [Recording](../media/capture.md#recording)).

## Building an image pixel by pixel

**An `Image` never changes** once it is made, like every asset (see [Assets and
playheads](../basics/programs.md#assets-and-playheads)): `image.pixel(x, y)` reads one of its
pixels, but nothing writes them. To build an image pixel by pixel, start with a `PixelBuffer`, which
begins transparent, and set its pixels with `set(x, y, color)` (and read them back with `pixel(x,
y)`). Then turn it into an image with `Image(buffer^)`, which takes the pixels over without copying
them:

```mojo
# In `create`: an 8 by 8 chessboard.
var buffer = PixelBuffer(8, 8)
for y in range(8):
    for x in range(8):
        if (x + y) % 2 == 0:
            buffer.set(x, y, Color.BLACK)
var board = Image(buffer^)
```

Pixels are counted in **image coordinates**, which work differently from the rest of Create: the
origin is the image's top-left pixel, y increases *downwards*, and x and y are whole numbers
(`Int`), one per pixel. This is the one place a position is two numbers rather than a `Point`, since
a pixel of an image is not a point on the screen. Reading off the image gives transparent, and
writing off it does nothing.

Shapes, text and gradients go into an image through an offscreen `Canvas` instead (see [Drawing into
an image](../media/images.md#drawing-into-an-image)).
