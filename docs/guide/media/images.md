# Images

An image is a picture loaded from a file, such as a character's sprite, a background or a tile, or
one the program makes itself. This page explains how to load and draw images, and how to draw
shapes, text and gradients into an image of your own. Building an image one pixel at a time is in
[Pixels](../drawing/pixels.md#building-an-image-pixel-by-pixel), and animating a sprite sheet in
[Animations](../motion/animations.md).

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
  file that makes the call (see [File paths](../basics/programs.md#file-paths)).
- **`canvas.image(image, position)`** draws the image centred on `position`, like every shape, one
  unit per image pixel. `canvas.image(image, position, width, height)` stretches it to that size.
  Either way it is the right way up, even though y increases upwards.
- **It is a render call like any other:** the transform turns, scales and mirrors it, the camera
  places it, and the style's `tint`, `opacity`, `blend_mode` and shadow apply (an image casts the
  shadow of its opaque pixels). Fill and stroke don't apply. See [Style](../drawing/style.md).
- `image.width()` and `image.height()` are its size in pixels, `Image.solid(width, height, color)`
  is an image of one colour, and `image.resize(width, height)` returns a resized copy. Resizing
  takes each new pixel from the nearest old one, so pixel art stays crisp rather than blurring.
- An `Image` is an asset: copying one is cheap, since copies share their pixels, and drawing one
  costs no copy either (see [Assets and playheads](../basics/programs.md#assets-and-playheads)). An
  image not drawn for 120 frames is dropped from the renderer's cache, so drawing a fresh image
  every frame, such as a snapshot, doesn't make memory use keep growing.

See [examples/images](../../../examples/images/main.mojo).

## Drawing into an image

An **offscreen canvas** is a canvas that draws into an image of its own rather than onto the screen.
Build one with `Canvas(width, height, scale=1.0, antialiasing=Antialiasing.MEDIUM)`. It has every
render call and `with` block that a frame's canvas has, so draw into it as usual. Then read the
result back with `snapshot`, which gives an `Image`, or with `color_at` (see [Reading the
screen](../drawing/pixels.md#reading-the-screen)). It is the way to draw shapes, text and gradients
into an image, such as a badge, a label or a texture made once and drawn many times:

```mojo
# In `create`, or anywhere else:
var badge = Canvas(64, 64)
badge.fill(Color.YELLOW)
badge.circle((0, 0), 30)
badge.text("1", (0, 0))
var icon = badge.snapshot()  # an Image, drawn later with canvas.image(icon, position)
```

Build one anywhere, `create` included, and keep it as a field to draw into across frames. See
[examples/offscreen](../../../examples/offscreen/main.mojo).

- **It starts transparent**, and is never cleared automatically. Its coordinates are the usual ones:
  the origin at its centre, and y increasing upwards.
- **It is always drawn on the CPU**, whatever the program's backend, though the `Image` it gives can
  be drawn by either.
- **Reading it bakes in the drawing:** each read draws everything drawn since the last read into the
  canvas's own pixels, and then forgets those drawing calls. So a canvas kept for a long time
  doesn't keep growing, and what is drawn after a read lands on top of what is there. Read it when
  something has changed, rather than every frame regardless.
- **`scale` fixes its sharpness:** it is how many pixels the canvas has per unit.
  `snapshot(scale=canvas.scale())` reads its pixels as they are, and any other scale resizes them,
  taking each new pixel from the nearest old one. Choose a fixed scale rather than taking it from
  the frame's canvas in `create`, where the window's size may not be final yet (see [The window's
  size on the first frame](../basics/programs.md#the-windows-size-on-the-first-frame)).
- **[`save_image` and `save_screenshot`](capture.md#saving-images) write at once**, since an
  offscreen canvas has no frame to wait for. `save_screenshot` writes the canvas's pixels at its own
  `scale`, with their alpha, and `save_image` keeps the alpha only with `transparent=True`. The
  `autoclear` and `letterbox_color` settings have no effect on an offscreen canvas.
- **Each one keeps its own caches** of the letters and images drawn into it (the fonts themselves
  are shared). So a few canvases kept for the whole run are cheap, but a new one for every object
  every frame is not.
