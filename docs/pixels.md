# Pixels and recording

## Reading pixels

`canvas.color_at(position) -> Color` and `canvas.snapshot([region], scale=1.0) -> Image` read what the
frame has drawn **so far**. They are a CPU replay of the commands recorded up to the call, like
`save_image`, so both backends read the same pixels and the GPU is never stalled. See
[examples/pixels/main.mojo](../examples/pixels/main.mojo).
- **Screen space**, not world: the transform and camera don't apply. `canvas.color_at(context.mouse.position)`
  picks under the mouse as it is, and a snapshot region is always upright (a turned `Rectangle` raises). Off the screen reads
  transparent.
- **Design size × `scale`**, without the letterbox. `snapshot()` drawn back with
  `canvas.image(shot, (0, 0), canvas.width(), canvas.height())` lines up exactly;
  `scale=canvas.scale()` gives window pixels.
- **One replay per drawing**: reads are cached until something more is recorded, so many `color_at`
  calls in a row cost one. A full-frame replay costs about a CPU frame. Fine for picking, a
  capture, or a feedback effect; read once rather than per object.
- **With `canvas.autoclear(False)`** a read starts from the last frame's pixels, as the frame did,
  from the frame after the first read on. The first read sees only its own frame. CPU backend
  only, the one that accumulates.

**Offscreen canvas:** `Canvas(width, height, scale=1.0, antialiasing=Antialiasing.MEDIUM)` builds a
canvas of the program's own, drawn into with every render call and guard and read back with
`color_at`/`snapshot` — the way to draw into an image. Build it anywhere, `create` included; keep it as a
field to draw into across frames. See [examples/offscreen/main.mojo](../examples/offscreen/main.mojo).
- **Starts transparent**, no autoclear; screen space as usual (origin centred, y up). Always
  rasterised on the CPU, whatever the program's backend; the `Image` it gives draws on either.
- **Bakes on read:** each read replays what was drawn since the last one onto the canvas's own
  pixels and drops those commands, so a long-lived canvas stays bounded and drawing after a read
  lands on what is there. Read when something changed, not every frame regardless.
- **Density is fixed by `scale`** (pixels per unit). `snapshot(scale=canvas.scale())` reads the
  pixels as they are; any other scale resamples them, nearest pixel. Don't take `scale` from the
  frame canvas in `create` ([gotcha 2](programs.md#critical-gotchas)) — pick a fixed density.
- `save_image` and `save_screenshot` write **at once**, having no frame to defer to.
  `save_screenshot` writes the pixels at their own density with alpha; `save_image` keeps alpha
  with `transparent=True`. `autoclear` and `letterbox_color` have no effect.
- Each has its own glyph cache and image cache (fonts themselves are shared): a few long-lived
  ones are cheap, one per entity per frame is not.

`canvas.clear()` discards everything drawn so far, back to how the canvas started: an offscreen
canvas to transparent, the frame canvas to its opening clear (or, with the autoclear off, the last
frame's pixels). Style, transform and settings are untouched; `background()` paints over instead.

**An `Image` is immutable**, an asset like `Sound`: `image.pixel(x, y)` reads it, nothing writes it.
Build one pixel by pixel in a `PixelBuffer` — `set(x, y, color)`/`pixel(x, y)`, transparent to start
— then `Image(buffer^)` takes the pixels over without copying. Both use **image coordinates**
(top-left origin, y down, whole `Int` cells — the one place a position is two numbers rather than a
`Point2D`, since a cell is not a point in the program's space); off the image, reads are
transparent and writes do nothing. "Pixel" always names such a cell; a colour at a screen point is
`canvas.color_at`.
`image.resize(w, h)` returns a new image, nearest pixel. Copying an image shares its pixels, and so
does a backend's cache of it, so drawing a new image costs no copy. An image not drawn for
`IMAGE_KEEP_FRAMES` (120) frames is dropped from the backends' caches, so a fresh snapshot every
frame costs bounded memory. Shapes, text and gradients go into an image through an offscreen
`Canvas` instead (above).

## Recording

`canvas.start_recording(path, seconds=, frames=, fps=30, scale=1.0, dither=False)` records the frames from
the one it is called in as an animated GIF (the only format; the path must end in `.gif`). See
[examples/capture/main.mojo](../examples/capture/main.mojo).
- **Each frame is a `save_image`:** design size × `scale`, no letterbox, replayed on the CPU, so
  either backend and every machine record the same bytes, and a headless run records
  deterministically. With the autoclear off a frame holds only its own drawing, as an image does.
- **Lasts across frames**, like the canvas settings above: until `seconds` of the run's time or
  `frames` frames, `canvas.stop_recording()` (the file is complete when it returns), or the end of
  the run, which finishes it. `canvas.cancel_recording()` ends it without saving.
  `canvas.recording()` reads it back; a new `start_recording` finishes the one in progress first.
- **Written beside the target first**, to `path` + `.partial`, which replaces `path` when the
  recording finishes: a file already there survives a cancel, and a crash leaves a `.partial`
  rather than a broken GIF.
- **Timed by the run's clock**, sampled `fps` times a second (at most 50): a display faster than
  `fps` skips frames, and a slow frame stays on screen longer, so the GIF plays at the program's
  speed.
- **A palette per frame:** exact with 256 colours or fewer, median cut otherwise; `dither` trades
  banding for grain. Capturing and encoding run at present, so recording a heavy scene slows it.
- Raises at once for a bad path or extension, `seconds` with `frames`, a value that isn't
  positive, and on an offscreen canvas.
