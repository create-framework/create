# Pixels and recording

Reading back what has been drawn, drawing into an image of your own, building an image pixel by
pixel, and recording the screen as a GIF.

## Reading the screen

`canvas.color_at(position)` returns the `Color` at a point, and `canvas.snapshot()` (or
`snapshot(region)`, with an optional `scale=`) returns an `Image` of the screen. Both read what the
frame has drawn **so far**. A colour picker:

```mojo
from create import *


@fieldwise_init
struct Picker(Program):
    var spectrum: Gradient

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> Picker:
        var spectrum = Gradient.linear(
            Color.RED, Color.YELLOW, Color.GREEN, Color.BLUE,
            direction=Vector2D.RIGHT,
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

A read is a CPU replay of the commands recorded up to the call, like `save_image`, so both backends
read the same pixels and the GPU is never stalled. See [examples/pixels](../examples/pixels/main.mojo).

- **Screen space**, not world: the transform and camera don't apply.
  `canvas.color_at(context.mouse.position)` picks under the mouse as it is, and a snapshot region
  is always upright (a turned `Rectangle` raises). Off the screen reads transparent.
- **Design size × `scale`**, without the letterbox. `snapshot()` drawn back with
  `canvas.image(shot, (0, 0), canvas.width(), canvas.height())` lines up exactly, which is how a
  feedback effect works; `scale=canvas.scale()` gives window pixels.
- **One replay per drawing**: reads are cached until something more is recorded, so many
  `color_at` calls in a row cost one. A full-frame replay costs about a CPU frame. Fine for
  picking, a capture or a feedback effect; read once rather than per object.
- **With `canvas.autoclear(False)`** a read starts from the last frame's pixels, as the frame did,
  from the frame after the first read on. The first read sees only its own frame. This is CPU
  backend only, the one that accumulates.

## Drawing into an image

An offscreen canvas, `Canvas(width, height, scale=1.0, antialiasing=Antialiasing.MEDIUM)`, is a
canvas of the program's own: draw into it with every render call and guard, and read it back with
`color_at` or `snapshot`. It is the way to draw shapes, text and gradients into an image:

```mojo
# A fragment, inside `create` (or anywhere else).
var badge = Canvas(64, 64)
badge.fill(Color.YELLOW)
badge.circle((0, 0), 30)
badge.text("1", (0, 0))
var icon = badge.snapshot()  # an Image, drawn later with canvas.image(icon, position)
```

Build one anywhere, `create` included, and keep it as a field to draw into across frames. See
[examples/offscreen](../examples/offscreen/main.mojo).

- **Starts transparent**, with no autoclear, in screen space as usual (origin centred, y up).
- **Always rasterised on the CPU**, whatever the program's backend; the `Image` it gives draws on
  either.
- **Bakes on read:** each read replays what was drawn since the last one onto the canvas's own
  pixels and drops those commands, so a long-lived canvas stays bounded and drawing after a read
  lands on what is there. Read when something changed, not every frame regardless.
- **Density is fixed by `scale`** (pixels per unit). `snapshot(scale=canvas.scale())` reads the
  pixels as they are; any other scale resamples them, nearest pixel. Don't take `scale` from the
  frame canvas in `create` ([gotcha 1](programs.md#critical-gotchas)); pick a fixed density.
- **`save_image` and `save_screenshot` write at once**, having no frame to defer to.
  `save_screenshot` writes the pixels at their own density with alpha; `save_image` keeps alpha
  with `transparent=True`. `autoclear` and `letterbox_color` have no effect.
- Each has its own glyph cache and image cache (fonts themselves are shared): a few long-lived
  ones are cheap, one per entity per frame is not.

**Starting over.** `canvas.clear()` discards everything drawn so far, back to how the canvas
started: an offscreen canvas to transparent, the frame canvas to its opening clear (or, with the
autoclear off, the last frame's pixels). Style, transform and settings are untouched. To paint
over what is there instead, use `background()`.

## Images and pixel buffers

**An `Image` is immutable**, an asset like `Sound`: `image.pixel(x, y)` reads it, nothing writes
it. To build one pixel by pixel, fill a `PixelBuffer` with `set(x, y, color)` (read back with
`pixel(x, y)`; it starts transparent), then `Image(buffer^)` takes the pixels over without copying:

```mojo
# A fragment: an 8 by 8 checkerboard.
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

- `image.resize(w, h)` returns a new image, nearest pixel.
- Copying an image shares its pixels, and so does a backend's cache of it, so drawing a new image
  costs no copy.
- An image not drawn for `IMAGE_KEEP_FRAMES` (120) frames is dropped from the backends' caches,
  so a fresh snapshot every frame costs bounded memory.
- Shapes, text and gradients go into an image through an offscreen `Canvas` instead
  ([above](#drawing-into-an-image)).

## Recording

`canvas.start_recording(path, seconds=, frames=, fps=30, scale=1.0, dither=False)` records the
frames from the one it is called in as an animated GIF, the only format; the path must end in
`.gif`:

```mojo
# A fragment of an `update`: R records the next five seconds.
if context.keyboard.pressed(Key.R):
    canvas.start_recording("capture.gif", seconds=5)
```

See [examples/capture](../examples/capture/main.mojo).

- **Each frame is a `save_image`:** design size × `scale`, no letterbox, replayed on the CPU, so
  either backend and every machine record the same bytes, and a headless run records
  deterministically. With the autoclear off a frame holds only its own drawing, as an image does.
- **Lasts across frames**, like the [canvas settings](drawing.md#settings-that-outlive-the-frame):
  until `seconds` of the run's time or `frames` frames, `canvas.stop_recording()` (the file is
  complete when it returns), or the end of the run, which finishes it.
  `canvas.cancel_recording()` ends it without saving. `canvas.recording()` reads it back; a new
  `start_recording` finishes the one in progress first.
- **Written beside the target first**, to `path` + `.partial`, which replaces `path` when the
  recording finishes: a file already there survives a cancel, and a crash leaves a `.partial`
  rather than a broken GIF.
- **Timed by the run's clock**, sampled `fps` times a second (at most 50): a display faster than
  `fps` skips frames, and a slow frame stays on screen longer, so the GIF plays at the program's
  speed.
- **A palette per frame:** exact with 256 colours or fewer, median cut otherwise; `dither` trades
  banding for grain. Capturing and encoding run when the frame is presented, so recording a heavy
  scene slows it.
- It raises at once for a bad path or extension, `seconds` with `frames`, a value that isn't
  positive, and on an offscreen canvas.
