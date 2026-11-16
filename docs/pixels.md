# Pixels, saving and recording

Reading back what has been drawn, drawing into an image of your own, saving the frame as a PNG,
and recording it as a GIF. Loading and drawing images, and building one pixel by pixel, is in
[Images](images.md).

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

Reading works the same on both backends and never slows the GPU down: the frame so far is drawn
again on the CPU, as [`save_image`](#saving-images) does. See
[examples/pixels](../examples/pixels/main.mojo).

- **Screen space**, not world: the transform and camera don't apply.
  `canvas.color_at(context.mouse.position)` picks under the mouse as it is, and a snapshot region
  is always upright (a turned `Rectangle` raises). Off the screen reads transparent.
- **Sized by the design:** a snapshot is the design size times `scale` (1 by default), without the
  letterbox bars. `snapshot()` drawn back with `canvas.image(shot, (0, 0), canvas.width(),
  canvas.height())` lines up exactly, which is how a feedback effect works (each frame drawing the
  last one back in, changed); `scale=canvas.scale()` gives window pixels.
- **One replay per drawing**: reads are cached until something more is recorded, so many
  `color_at` calls in a row cost one. A full-frame replay costs about a CPU frame. Fine for
  picking, a capture or a feedback effect; read once rather than per object.
- **With `canvas.autoclear(False)`**, a read includes what earlier frames left on screen, as the
  frame itself does, but only from the frame after the program's first read: that first read
  starts the keeping of past frames, so it sees only its own frame's drawing. CPU backend only,
  the one that keeps past frames.

## Drawing into an image

An offscreen canvas, `Canvas(width, height, scale=1.0, antialiasing=Antialiasing.MEDIUM)`, is a
canvas of the program's own: draw into it with every render call and guard, and read it back with
`color_at` or `snapshot`. It is the way to draw shapes, text and gradients into an image:

```mojo
# In `create`, or anywhere else:
var badge = Canvas(64, 64)
badge.fill(Color.YELLOW)
badge.circle((0, 0), 30)
badge.text("1", (0, 0))
var icon = badge.snapshot()  # an Image, drawn later with canvas.image(icon, position)
```

Build one anywhere, `create` included, and keep it as a field to draw into across frames. See
[examples/offscreen](../examples/offscreen/main.mojo).

- **Starts transparent**, with no autoclear, in screen space as usual (origin centred, y up).
- **Always drawn on the CPU**, whatever the program's backend; the `Image` it gives draws on
  either.
- **Reading flattens it:** each read draws what was drawn since the last one into the canvas's own
  pixels and forgets those drawing calls, so a long-lived canvas stays bounded and drawing after a
  read lands on what is there. Read when something changed, not every frame regardless.
- **Density is fixed by `scale`** (pixels per unit). `snapshot(scale=canvas.scale())` reads the
  pixels as they are; any other scale resamples them, nearest pixel. Don't take `scale` from the
  frame canvas in `create`; pick a fixed density (see
  [The window's size on the first frame](programs.md#the-windows-size-on-the-first-frame)).
- **`save_image` and `save_screenshot` write at once**, since an offscreen canvas has no frame to
  wait for. `save_screenshot` writes the pixels at their own density with alpha; `save_image` keeps
  alpha with `transparent=True`. `autoclear` and `letterbox_color` have no effect.
- Each has its own glyph cache and image cache (fonts themselves are shared): a few long-lived
  ones are cheap, one per entity per frame is not.

**Starting over.** `canvas.clear()` discards everything drawn so far, back to how the canvas
started: an offscreen canvas to transparent, the frame canvas to its opening clear (or, with the
autoclear off, the last frame's pixels). Style, transform and settings are untouched. To paint
over what is there instead, use `background()`.

## Saving images

Two calls save the frame as a PNG. Each writes its file when the frame is shown, so it holds the
whole frame wherever in `update` it is called:

```mojo
# In `update`: S saves the frame at twice the design size.
if context.keyboard.pressed(Key.S):
    canvas.save_image("poster.png", scale=2.0)
```

- **`canvas.save_image(path, scale=1.0, transparent=False)`** saves what the program drew: the
  design size times `scale`, without the letterbox bars. It comes out the same on every machine
  and on both backends, so it is the one for artwork, posters and tests. `transparent=True`
  leaves the background out, so wherever nothing was drawn is transparent.
- **`canvas.save_screenshot(path)`** saves what the user saw: the window's own pixels, letterbox
  bars included. It depends on the window's size and the machine, so it is the one for a bug
  report or sharing a running sketch.

On an offscreen canvas both write at once (see [Drawing into an image](#drawing-into-an-image)).

## Recording

`canvas.start_recording(path, seconds=, frames=, fps=30, scale=1.0, dither=False)` records an
animated GIF, starting with the frame it is called in. GIF is the only format, so the path must
end in `.gif`:

```mojo
# In `update`: R records the next five seconds.
if context.keyboard.pressed(Key.R):
    canvas.start_recording("capture.gif", seconds=5)
```

See [examples/capture](../examples/capture/main.mojo).

- **Each frame is a `save_image`:** design size × `scale`, no letterbox, replayed on the CPU, so
  either backend and every machine record the same bytes, and a headless run records
  deterministically.
- **With the autoclear off, it keeps what the screen keeps:** a frame holds the ink of every
  frame since recording started, the frames between two captured ones included, since every
  frame is replayed into the recording while it runs. That costs a CPU replay of each frame.
  Whatever starts the screen's picture over (resizing the window, or on the GPU changing the
  antialiasing) starts the recording's over too.
- **Lasts across frames**, like the [canvas settings](drawing.md#settings-that-outlive-the-frame):
  until `seconds` of the run's time or `frames` frames, `canvas.stop_recording()` (the file is
  complete when it returns), or the end of the run, which finishes it. `canvas.cancel_recording()`
  ends it without saving. `canvas.recording()` is whether one is running; a new `start_recording`
  finishes the one in progress first.
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
