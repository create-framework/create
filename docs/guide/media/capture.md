# Capture

A program can save what it draws: a single frame as a PNG image, to share or print, or a stretch of
frames as an animated GIF. This page explains both. Reading the colours of what has been drawn from
inside the program is in [Pixels](../drawing/pixels.md#reading-the-screen), and making images of
your own in [Images](images.md).

## Saving images

Two calls save the frame as a PNG. Each writes its file when the frame is shown, so it holds the
whole frame wherever in `update` it is called:

```mojo
# In `update`: S saves the frame at twice the design size, as image-0001.png, image-0002.png, …
if context.keyboard.pressed(Key.S):
    canvas.save_image(pixel_scale=2.0)
```

- **`canvas.save_image(path, pixel_scale=1.0, transparent=False)`** saves what the program drew: the
  design size times `pixel_scale`, without the letterbox bars. It comes out the same on every
  machine and on both backends, so it is the one for artwork, posters and tests. `transparent=True`
  leaves the background out, so wherever nothing was drawn is transparent.
- **`canvas.save_screenshot(path)`** saves what the user saw: the window's own pixels, letterbox
  bars included. It depends on the window's size and the machine, so it is the one for a bug report
  or sharing a running sketch.

Every call saves a file, so a frame can be saved more than once, such as a preview and a print at a
larger `pixel_scale`. On an offscreen canvas both write at once (see [Drawing into an
image](images.md#drawing-into-an-image)).

## Naming the files

**Without a path, every capture gets a file of its own.** `save_image()` saves `image-0001.png`,
then `image-0002.png` and so on, `save_screenshot()` saves `screenshot-0001.png` and onwards, and
`start_recording()` saves `recording-0001.gif` and onwards. The files go beside the source file that
makes the call, as every path does (see [File paths](../basics/programs.md#file-paths)). The first
capture of a run looks for the highest number already in the folder and carries on from there, so a
new run never replaces what an earlier one saved.

**With a path, the file is saved there**, replacing a file already there, so
`save_image("poster.png")` always leaves one `poster.png`, the latest. The folder must exist
already.

`naming=` chooses for yourself, with a `FileNaming`:

| `naming` | File |
|---|---|
| `FileNaming.EXACT` | The path as given. The default when a path is given |
| `FileNaming.NUMBERED` | The path with a number added before the extension. The default when no path is given |

So a path of your own can be numbered too:

```mojo
# In `update`: P saves posters/poster-0001.png, posters/poster-0002.png, …
if context.keyboard.pressed(Key.P):
    canvas.save_image("posters/poster.png", naming=FileNaming.NUMBERED)
```

A number has four digits, and more once it passes 9999.

**Saving every frame** makes a sequence of images to turn into a video. The numbers count up one a
frame, which is what a video tool such as [ffmpeg](https://ffmpeg.org/) reads:

```mojo
# At the end of `update`: frames/frame-0001.png, frames/frame-0002.png, …
canvas.save_image("frames/frame.png", naming=FileNaming.NUMBERED)
```

```bash
ffmpeg -framerate 60 -i frames/frame-%04d.png -pix_fmt yuv420p video.mp4
```

Saving a PNG every frame is slow, so the program runs slower than usual while it saves. Motion that
moves by `context.time.delta` then moves further each frame, and the video plays faster than the
program looked.

## Recording

`canvas.start_recording(path, seconds=, frames=, fps=30, pixel_scale=1.0, dither=False,
transparent=False)` records an animated GIF, starting with the frame it is called in. GIF is the
only format, so the path must end in `.gif`. Without a path, it records `recording-0001.gif`,
`recording-0002.gif` and so on (see [Naming the files](#naming-the-files)):

```mojo
# In `update`: R records the next five seconds.
if context.keyboard.pressed(Key.R):
    canvas.start_recording("capture.gif", seconds=5)
```

See [examples/capture](../../../examples/capture/main.mojo).

- **Each frame is a `save_image`:** the design size times `pixel_scale`, without the letterbox bars,
  drawn on the CPU. So both backends and every machine record exactly the same file, and a headless
  run records the same file every time. The one exception is below.
- **With the autoclear off, it keeps what the screen keeps.** Each recorded frame holds the drawing
  of every frame since recording started, including the frames between two captured ones, because
  every frame is drawn into the recording while it runs. That means every frame is drawn a second
  time, on the CPU.

  It starts from the picture already on screen: the recording's first frame is the window's own
  pixels, scaled to the recording's size, so that one frame depends on the window and the backend.
  Whatever starts the screen's picture over, such as resizing the window or, on the GPU, changing
  the antialiasing, starts the recording's over too.
- **It lasts across frames**, like the [canvas
  settings](../drawing/canvas.md#settings-that-outlive-the-frame), until one of these ends it and
  saves the file:
  - `seconds` of the run's time have passed, or `frames` frames have been recorded;
  - `canvas.stop_recording()` is called, and the file is complete when it returns;
  - the run ends.

  `canvas.cancel_recording()` ends it without saving. `canvas.recording()` is whether a recording is
  running, and starting a new one finishes the one in progress first.
- **It is written to a separate file first**, the file's name with `.partial` added, which replaces
  the file only when the recording finishes. So a file already there survives a cancelled recording,
  and a crash leaves a `.partial` file rather than a broken GIF.
- **It keeps to the run's clock:** it captures a frame `fps` times a second of the run's time (at
  most 50). On a display faster than that, some frames are skipped, and a frame that took long to
  draw is shown for longer in the GIF, so the GIF plays at the speed the program ran.
- **`transparent=True` leaves the background out**, as `save_image`'s does: clears and
  `background()` calls are dropped, and each frame replaces the last rather than drawing over it. A
  GIF's pixels can only be fully transparent or fully opaque, so a pixel less than half opaque is
  left out and the rest are drawn fully opaque. Smoothed edges therefore come out hard, though in
  their own colour, with no fringe. With the autoclear off, a transparent recording starts from
  nothing rather than the screen, whose picture has the background in it.
- **Only what changed is stored:** each frame after the first holds only the rectangle that changed
  since the one before. A frame where nothing changed isn't stored at all; the one before is shown
  for longer instead. So a mostly still scene makes a small file. A transparent recording stores
  every frame whole.
- **A palette per frame:** a GIF frame holds at most 256 colours. A frame with no more than that is
  stored exactly; one with more is reduced to the 256 that best represent it. `dither=True` hides
  the bands that reduction leaves in smooth gradients by scattering pixels of nearby colours, at the
  cost of a grainy look. The recording is made as each frame is shown, so recording a scene that is
  slow to draw slows it down further.
- `start_recording` raises an error straight away for a path it can't write or that doesn't end in
  `.gif`, for `seconds` and `frames` given together, for a value that isn't positive, and on an
  offscreen canvas.
