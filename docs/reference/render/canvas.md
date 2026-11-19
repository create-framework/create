# Canvas

```mojo
struct Canvas
```

One frame: the geometry and the rendering API.

This is the object a program is handed to render a frame with. `width`/`height`
are the screen extent and `left`/`right`/`bottom`/`top` its edges — use
those rather than width arithmetic, since the origin is centred and two of
them are negative. `scale` is the autoscale factor. Screen space is camera-independent: these don't know a
`Camera` exists, since a program sets one on the canvas's transform, not on
the geometry it reports.

A `mut` parameter because the program renders on it, and the recording it
appends to is the frame's whole output. What it does *not* carry is a
setting, the clock or input: everything that outlives a frame is in
`Context`, handed to `update` beside it. A `Canvas` that carried a dial would be offering to
change something it is not around to see the effect of.

The canvas the loop hands to `create` and `update` is built fresh each
frame and dropped before the frame is presented. The machinery that must
survive the frame goes in and out through `_PersistentCanvasState`.

`Canvas(width, height)` builds an *offscreen* canvas instead: a program's
own, drawn into with the same calls and read back with `color_at` and
`snapshot`, which may be kept as a field across frames. It starts
transparent, and has no frames to present: each read replays what has
been drawn since the last one onto its own pixels, so drawing after a
read lands on what is already there.

**It takes no parameters, and holds no `Surface`.** It used to need one
origin parameter for the framebuffer it borrowed, which constrained the
whole API: a second parameter would have broken every
`Program.update` signature at once, and pointing an existing `Canvas` at a
new framebuffer could not compile at all. Both
limits are gone because a `Canvas` no longer touches pixels — it records,
and the backend replays onto a `Surface` the canvas never sees. Don't
reintroduce a `Surface` field or a parameter to hold one.

Its extent comes from the `Viewport` rather than from a framebuffer. The
two can disagree for one frame after a resize, which is harmless here: the
extent is only used for coordinate arithmetic, and the replay clips against
the real surface it is handed.

A render call touches no pixels: it appends a `RenderCommand` to the backend's
recording, and the backend replays the whole frame afterwards. So a
`Canvas` is a recorder, and the geometry it records is *local* — the shape
as the program asked for it, paired with the current transform — never
device pixels. A style is resolved at record time, so a later `fill()`
cannot reach back and change what an earlier command paints.

Every pixel write blends source-over, so a fill, stroke, image, glyph or
`background` with `a < 255` composites with what is already there —
unless `blend_mode` picks another way to combine them.

Implements `Deinitable`, `DrawTarget`, `Movable`.

## Constructors

```mojo
@staticmethod
def __init__(
    out self,
    width: Float64,
    height: Float64,
    *,
    pixel_scale: Float64 = 1,
    antialiasing: Antialiasing = Antialiasing.MEDIUM,
) raises
```

An offscreen canvas of `width` by `height` screen units, with `pixel_scale` pixels to the unit — `pixel_scale=canvas.pixel_scale()` matches the window's density.

Screen space as on the frame canvas: origin centred, y up. Always
rasterised on the CPU, whatever backend the program runs on; what
comes out of it is an `Image`, which any canvas can draw.

```mojo
@staticmethod
def __init__(
    out self,
    width: Int,
    height: Int,
    *,
    pixel_scale: Float64 = 1,
    antialiasing: Antialiasing = Antialiasing.MEDIUM,
) raises
```

## Methods

### `width`

```mojo
def width(self) -> Float64
```

The width in screen units, `right() - left()`: the design width under `Autoscale.FIT`, more under `EXTEND` as the window grows — by a fraction of a unit too, as the window's pixels divide out — the window's pixels under `OFF`. Rebuilt every frame.

### `height`

```mojo
def height(self) -> Float64
```

The height in screen units, `top() - bottom()`; see `width`.

### `bounds`

```mojo
def bounds(self) -> Rectangle
```

The screen as a rectangle in screen space, `left()` to `right()` and `bottom()` to `top()`: centred on the origin, `width()` by `height()`. What `snapshot` and `clip` take, and what `contains` asks whether something is on the screen.

### `pixel_scale`

```mojo
def pixel_scale(self) -> Float64
```

Window pixels per screen unit: what font size, stroke thickness and image size are scaled by.

### `left`

```mojo
def left(self) -> Float64
```

Screen x of the left edge — negative, since the origin is centred.

### `right`

```mojo
def right(self) -> Float64
```

### `bottom`

```mojo
def bottom(self) -> Float64
```

Screen y of the bottom edge — negative, since y grows upward.

### `top`

```mojo
def top(self) -> Float64
```

### `translate`

```mojo
def translate(mut self, delta: Vector)
```

Move everything drawn after this, until the end of the frame, by `delta`, as Processing's `translate` does.

It applies inside whatever transform is already current, so a
`rotate` after it turns about the point it moved to. Wrap the
drawing in `with canvas.transform():` to undo it when the block
ends.

```mojo
with canvas.transform():
    canvas.translate(Vector(100, 0))
    canvas.rotate(PI / 4)
    canvas.rectangle((0, 0), 40, 40)  # turned about (100, 0)
```

### `rotate`

```mojo
def rotate(mut self, angle: Float64)
```

Turn everything drawn after this, until the end of the frame, counter-clockwise by `angle` radians about the current origin, as Processing's `rotate` does. See `translate`.

### `scale`

```mojo
def scale(mut self, s: Float64)
```

Make everything drawn after this, until the end of the frame, `s` times as big about the current origin, as Processing's `scale` does. See `translate`.

```mojo
def scale(mut self, sx: Float64, sy: Float64)
```

Stretch everything drawn after this, until the end of the frame, by `sx` across and `sy` up and down about the current origin. A negative value mirrors. See `translate`.

### `transform`

```mojo
def transform(mut self) -> TransformGuard[origin_of(self)]
```

Keep the current transform for a `with` block, and restore it when the block ends, as Processing's `pushMatrix` and `popMatrix` do.

`translate`, `rotate` and `scale` inside the block are undone at its
end, so a helper that draws with them doesn't change what its
caller draws next.

```mojo
with canvas.transform():
    canvas.translate(Vector(self.position))
    canvas.rotate(self.angle)
    canvas.rectangle((0, 0), 40, 40)
```

```mojo
def transform(mut self, t: Transform) -> TransformGuard[origin_of(self)]
```

Apply `t` to everything drawn inside a `with` block, on top of the current transform, and restore the current transform when the block ends.

```mojo
with canvas.transform(Transform(translation=Vector(50, 50))):
    canvas.rectangle((0, 0), 100, 100)
```

The block restores the transform on exit, including on an early
return or a raise.

```mojo
def transform(
    mut self,
    m: Matrix[Int(3), Int(3)],
) raises -> TransformGuard[origin_of(self)]
```

Apply `m` to everything rendered inside a `with` block.

```mojo
with canvas.transform(translate(50.0, 50.0)):
    canvas.rectangle((0, 0), 100, 100)
```

The matrix pops on exit, including on an early return or a raise.
Raises if `m` isn't affine, as `Transform(m)` does.

### `style`

```mojo
def style(
    mut self,
    *,
    fill: Optional[Color] = None,
    fill_gradient: Optional[Gradient] = None,
    fill_enabled: Optional[Bool] = None,
    stroke: Optional[Color] = None,
    stroke_thickness: _OptionalFloat64 = None,
    stroke_enabled: Optional[Bool] = None,
    stroke_alignment: Optional[StrokeAlign] = None,
    stroke_cap: Optional[StrokeCap] = None,
    stroke_dash: Optional[StrokeDash] = None,
    corner_radius: _OptionalFloat64 = None,
    text_color: Optional[Color] = None,
    font: Optional[Font] = None,
    font_size: _OptionalFloat64 = None,
    font_weight: Optional[FontWeight] = None,
    font_italic: Optional[Bool] = None,
    text_alignment: Optional[Align] = None,
    tint: Optional[Color] = None,
    opacity: _OptionalFloat64 = None,
    blend_mode: Optional[BlendMode] = None,
    shadow: Optional[Color] = None,
    shadow_offset: Optional[Vector] = None,
    shadow_blur: _OptionalFloat64 = None,
    shadow_spread: _OptionalFloat64 = None,
    shadow_inset: Optional[Bool] = None,
    shadow_follows_transform: Optional[Bool] = None,
    shadow_enabled: Optional[Bool] = None,
) -> StyleGuard[origin_of(self)]
```

Scope style changes to a `with` block, restoring the previous style on exit.

Each keyword applied goes through the setter of the same name, so it
behaves exactly like calling that setter; the rest of the style is kept.
`fill_gradient` goes through `fill`'s `Gradient` overload; given
beside `fill`, the gradient paints. With no keywords it only scopes: for helpers that set style before
rendering, where without it a callee's `stroke_enabled(False)`
silently applies to whatever the caller renders next.

```mojo
with canvas.style(fill=Color.RED, stroke_enabled=False):
    canvas.circle(position, 10)
```

```mojo
def style(mut self, style: Style) -> StyleGuard[origin_of(self)]
```

Render with `style` for a `with` block, then restore the previous one.

Replaces the whole style: a field `style` doesn't set is at its
`Style()` default inside the block, not whatever was set before.
Applied as soon as this is called, like `transform(m)`, so outside a
`with` it holds for the rest of the frame.

```mojo
with canvas.style(self.label_style):
    canvas.text("Score", (0, canvas.top() - 20))
```

### `to_screen`

```mojo
def to_screen(self, local: Point) -> Point
```

A point in the current transform's frame, in screen space: through the transform, then the camera (none inside `overlay`). Where something drawn at `local` lands on screen.

For its position in world space, ask the camera:
`camera.to_world(canvas.to_screen(local))`.

### `clip`

```mojo
def clip[R: Region](
    mut self,
    region: R,
    invert: Bool = False,
) -> ClipGuard[origin_of(self)]
```

Render only inside `region` for a `with` block — or, with `invert`, only outside it. `region` is any `Region`: a `Rectangle`, `Circle`, `Triangle`, `Sector` or `Polygon`, rounded by its own `corner_radius`; a polygon's inside is by the nonzero rule.

```mojo
with canvas.clip(Rectangle((0, 0), 200, 120)):
    canvas.image(self.photo, (0, 0))
```

`region` is placed by the transform and camera current here, and
stays there for the block: a `transform` or `overlay` inside it moves
what is rendered, not the clip. A clip inside another keeps only what
both keep. Every render call is clipped, its shadow and `background()`
included; the letterbox is not. The clip's edge is the edge
`canvas.draw(region)` would have.

Closes on exit, including on an early return or a raise.

### `to_local`

```mojo
def to_local(self, screen: Point) -> Point
```

A screen-space point — `context.mouse.position`, say — in the current transform's frame: back through the camera (none inside `overlay`), then the transform. So `canvas.to_local(context.mouse.position)` picks in the frame a shape is drawn in, with or without a camera.

### `camera`

```mojo
def camera(mut self, camera: Camera)
```

Set the active camera. Applies to every render call and every nested `transform()` from here on, until changed again or `canvas.overlay()` suspends it — and resets to identity next frame, like the rest of the transform state.

```mojo
canvas.camera(self.camera)
canvas.image(self.player.position, ...)  # world-space coordinates
with canvas.overlay():
    canvas.text("Score: " + str(self.score), (0, canvas.top() - 20))
```

### `overlay`

```mojo
def overlay(mut self) -> OverlayGuard[origin_of(self)]
```

Suspend the camera and any active transform for a `with` block, so what's rendered inside lands in screen space regardless of where the camera looks — for a HUD or other UI that must stay put.

Pops back to whatever camera and transform were active on exit,
including on an early return or a raise.

### `fill`

```mojo
def fill(mut self, color: Optional[Color] = None)
```

Paint the inside of shapes, switching the fill on. A `color` replaces any gradient; left unset, the current fill is kept, colour or gradient, so `fill()` alone brings back the last fill. The fill is *off* by default, in white, so `fill()` on a fresh frame paints shapes white.

Holds until changed or until the frame ends — every frame starts from
the `Style` defaults, so nothing set here leaks into the next one.

```mojo
def fill(mut self, gradient: Gradient)
```

Paint the inside of shapes with `gradient`, switching the fill on. It spans each shape's own bounding box, so it moves and turns with the shape; see `Gradient`. Only fills take one: strokes, text and shadows keep their colours.

Holds until a `fill(color)` replaces it or the frame ends. The fill
color is kept meanwhile, so `fill(color)` alone brings a solid back.

### `stroke`

```mojo
def stroke(mut self, color: Optional[Color] = None, thickness: _OptionalFloat64 = None)
```

Stroke shapes, switching the stroke on if `stroke_enabled(False)` had turned it off. `color`/`thickness` left unset keep their current values. Worth knowing stroke is *on* by default, in black, 1 unit thick — a `rectangle` rendered without `stroke_enabled(False)` gets one nobody asked for.

Thickness is in world units, scaled by autoscale like every other
coordinate, and never rendered thinner than one pixel; a fractional
one (`thickness=1.5`) rounds to whole pixels once scaled.

### `fill_enabled`

```mojo
def fill_enabled(mut self, enabled: Bool)
```

Switch the fill off or back on. The fill color and any gradient are kept while off, so `fill_enabled(True)` brings back the same fill; `fill(...)` switches it on too.

### `stroke_enabled`

```mojo
def stroke_enabled(mut self, enabled: Bool)
```

Switch the stroke off or back on. Color and thickness are kept while off, so `stroke_enabled(True)` brings back the same stroke; `stroke(...)` switches it on too.

### `stroke_alignment`

```mojo
def stroke_alignment(mut self, alignment: StrokeAlign)
```

Place the stroke of every region inside its edge (`StrokeAlign.INSIDE`, the default), centred on it (`CENTER`) or around it (`OUTSIDE`). The fill meets the stroke's inner edge. Lines and curves have no inside and are always stroked centred, so it changes nothing there. Doesn't switch the stroke on.

### `stroke_cap`

```mojo
def stroke_cap(mut self, cap: StrokeCap)
```

Finish the open ends of lines and curves with `cap`: `StrokeCap.BUTT` (the default) flush with the end point, `ROUND` a half disc, `SQUARE` pushed out by half the thickness. A region's stroke and a closed curve have no ends, so it changes nothing there unless the stroke is dashed, when it finishes every dash. Doesn't switch the stroke on.

### `stroke_dash`

```mojo
def stroke_dash(mut self, dash: StrokeDash)
```

Break every stroke into dashes: `StrokeDash.DASHED` or `DOTTED`, scaled to the stroke's thickness, or exact lengths in world units such as `StrokeDash(12, 6)`. `StrokeDash.SOLID` (the default) draws it unbroken again. Each dash's ends take `stroke_cap`, a region's too; see `StrokeDash` for where a pattern starts. Doesn't switch the stroke on.

### `corner_radius`

```mojo
def corner_radius(mut self, radius: Float64)
```

Round the shapes built from numbers by `rectangle`, `triangle`, `polygon` and `sector`, in world units, unless a call names its own `corner_radius`. A shape value carries its own radius, so `draw(shape)` and `clip(shape)` ignore this one: what is drawn from a shape is what its `contains` tests. Clamped per shape as the shape describes.

```mojo
def corner_radius(mut self, radius: Int)
```

### `clear`

```mojo
def clear(mut self)
```

Discard everything drawn so far, back to how the canvas started.

An offscreen canvas is transparent again. The frame canvas starts
the frame over: opened with the clear to grey 200 while the
autoclear is on, or from the last frame's pixels while it is off.
Style, transform, camera and settings are untouched — this undoes
drawing, not state — and inside a `clip` block the clip still
applies to what is drawn next. To paint over what is there instead,
use `background()`.

### `background`

```mojo
def background(mut self, color: Color)
```

Paint the whole framebuffer — the usual first call in `update`.

A translucent color blends instead of clearing, which is how motion
trails are rendered: `canvas.background(Color(0x11, 0x11, 0x11, 24))`
fades the previous frame a little further each time. Trails need
`canvas.autoclear(False)` set in `create`, or the frame's own clear wipes
what they were fading.

An opaque color replaces the autoclear rather than
stacking on it, so opening `update` with this costs one clear, not two.

```mojo
def background(mut self, gradient: Gradient)
```

Paint the whole framebuffer with `gradient` — a sky, a vignette.

It spans the screen, `left()` to `right()` and `bottom()` to
`top()`, whatever the camera is doing; under `EXTEND` that is the
whole window. Where `FIT` leaves letterbox bars, the bars are painted
over it as usual.

Like a colour, it replaces the autoclear if every stop
is opaque, and blends over what is there otherwise.

### `save_image`

```mojo
def save_image(
    mut self,
    path: String,
    pixel_scale: Float64 = 1,
    transparent: Bool = False,
) raises
```

Save this frame as a PNG at the design size, times `pixel_scale`.

Window-independent by construction: the size of the file is the space
the program renders in, never the size of the window, and the letterbox
bars are absent because they belong to a window this image is not of.
The same call under either backend produces the same image — the
capture is rasterised on the CPU from the recorded commands, so the
GPU path needs no readback. That is what makes this the export to use
for artwork, posters and golden-image tests; use `save_screenshot` for
what the user actually saw.

`transparent` drops the frame's `background`, leaving alpha 0 wherever
nothing was rendered. `pixel_scale` multiplies the output resolution, so
`pixel_scale=2.0` gives a 2x export of the identical layout.

Deferred, not immediate: the file is written when the frame is
presented, so it holds the whole frame however early in `update` this
was called. A failure to write raises there, from `present`, rather
than here.

An offscreen canvas has no frame to present, so it writes at once,
what it has drawn so far. Its pixels are already rasterised, so a
`pixel_scale` other than its own resamples them, and `transparent` keeps
their alpha rather than dropping a `background` it has painted.

A relative `path` is resolved against the directory of the calling
source file, not the working directory, as `Image.load`'s is.

### `color_at`

```mojo
def color_at(mut self, position: Point) raises -> Color
```

The colour at `position` in what this frame has drawn so far.

`position` is in screen space, whatever the camera or transform —
a read is of the screen, not the scene — so
`canvas.color_at(context.mouse.position)` picks under the mouse as it is.
Outside the screen it is `Color.TRANSPARENT`.

Reads what is drawn *so far*: a render call after this one does not
change what it returned. The pixels are those `save_image` would
write at scale 1, on either backend, without the letterbox. Reading
replays the frame on the CPU once, and again only after something
more is drawn, so many reads in a row cost one replay.

With `canvas.autoclear(False)`, a read starts from the last frame's
pixels, as the frame did — from the second frame that reads on; the
first sees only what it drew itself. That needs the CPU backend,
which is also the only one that accumulates.

On an offscreen canvas a read replays what was drawn since the last
one onto the canvas's own pixels, at its own `scale`.

### `snapshot`

```mojo
def snapshot(mut self, pixel_scale: Float64 = 1) raises -> Image
```

What this frame has drawn so far, as an `Image` of the whole screen: `width * pixel_scale` by `height * pixel_scale` pixels.

Drawn back with `canvas.image(shot, (0, 0), canvas.width(),
canvas.height())` it lines up with the frame exactly — a feedback
effect is a snapshot kept as a field and drawn under the next frame.
`pixel_scale=canvas.pixel_scale()` gives the window's own resolution instead.
Everything `color_at` says about what is read applies.

```mojo
def snapshot(mut self, region: Rectangle, pixel_scale: Float64 = 1) raises -> Image
```

What this frame has drawn so far inside `region`, as an `Image` of `region.w * pixel_scale` by `region.h * pixel_scale` pixels.

`region` is in screen space, like `color_at`'s position, so it is always
upright, and a turned one raises; outside the screen the image is
transparent.

On an offscreen canvas `pixel_scale=canvas.pixel_scale()` reads its pixels as they
are; any other value resamples them, nearest pixel.

### `save_screenshot`

```mojo
def save_screenshot(mut self, path: String) raises
```

Save this frame as a PNG at the framebuffer's own resolution.

The complement of `save_image`: this answers what the user *saw*, so
it is the size of the drawable, letterbox bars included, rendered by
whichever rasteriser actually drew the frame. That makes it
deliberately machine-dependent — window size, HiDPI scaling and any
driver antialiasing are all in it, and two machines will not produce
the same file. Right for a bug report or for sharing a running sketch;
use `save_image` for anything that has to be reproducible.

Deferred and raising in the same way as `save_image`: the file is
written when the frame is presented, and a failure raises from there.

An offscreen canvas writes at once: its own pixels, at its own
density, alpha kept — it has no window to have been seen in.

A relative `path` is resolved against the directory of the calling
source file, as `save_image`'s is.

### `start_recording`

```mojo
def start_recording(
    mut self,
    path: String,
    *,
    seconds: _OptionalFloat64 = None,
    frames: Optional[Int] = None,
    fps: Float64 = 30,
    pixel_scale: Float64 = 1,
    dither: Bool = False,
    transparent: Bool = False,
) raises
```

Record the frames from this one on as an animated GIF at `path`.

Each frame is what `save_image` would save: the design size times
`pixel_scale`, no letterbox, replayed on the CPU, so either backend and
every machine records the same pixels, and a headless run records
deterministically. Recording starts with the frame this is called
in, captured whole however early in `update` it was called, and runs
until `seconds` of the run's time or `frames` frames, until
`stop_recording`, or until the run ends, which finishes the file;
`cancel_recording` ends it without one. A new `start_recording`
finishes the recording in progress first.

Until it finishes, the frames stream to `path` with `.partial`
added, which then replaces `path` in one step: a file already at
`path` is untouched until then, and stays if the recording is
cancelled.

The run's clock is sampled `fps` times a second, so the GIF plays at
the program's own speed whatever the display's rate: a window faster
than `fps` skips frames, and a slow frame stays on screen longer. A
GIF times frames in hundredths of a second, and many players slow
anything faster than 50 fps, so `fps` is at most 50.

Each frame gets a palette of its own: exact if it has 256 colours or
fewer, the nearest 256 otherwise. `dither` mixes neighbouring pixels
so smooth gradients don't band, at the cost of a grainier file. Only
what changed is stored: a frame after the first holds the rectangle
that changed, and an unchanged frame lengthens the one before.

`transparent` leaves the background out, as `save_image`'s does:
the frame's clears and `background` calls are dropped, and a pixel
under half alpha is transparent. A GIF pixel is either transparent
or opaque, so an antialiased edge comes out hard, though in its own
colour, with no fringe. Each frame replaces the last rather than
drawing over it, so nothing earlier shows through its holes. With
the autoclear off, it starts from nothing rather than the picture on
screen, which has the background in it.

Capturing and encoding run as each frame is presented, so a long
recording of a heavy scene slows it down.

With the autoclear off, the recording keeps what earlier frames
left, as the screen does: every frame is replayed into it, captured
or not, so ink drawn between two captured frames is kept, at the
cost of a CPU replay of every frame while it records. It starts from
the picture already on screen: its first frame is the window's own,
sampled to the recording's size, so that one frame, unlike the rest,
depends on the window and the backend. Whatever
starts the screen's picture over starts the recording's over too:
resizing the window, and on the GPU changing the antialiasing.

Raises at once for a path not ending in `.gif`, `seconds` and
`frames` both given, a value that isn't positive, `fps` above 50, a
file that can't be opened, or an offscreen canvas, which has no
frames to record.

A relative `path` is resolved against the directory of the calling
source file, as `save_image`'s is.

### `stop_recording`

```mojo
def stop_recording(mut self) raises
```

Finish the recording in progress now and save it: the file is complete when this returns, and the frame it is called in is not in it. `cancel_recording` ends one without saving. Nothing happens when nothing is being recorded.

### `cancel_recording`

```mojo
def cancel_recording(mut self) raises
```

End the recording in progress without saving it: no file appears at its path, and a file already there is left as it was. Nothing happens when nothing is being recorded.

### `recording`

```mojo
def recording(self) -> Bool
```

Whether a recording started by `start_recording` is in progress.

### `rectangle`

```mojo
def rectangle(
    mut self,
    position: Point,
    width: Float64,
    height: Float64,
    *,
    corner_radius: _OptionalFloat64 = None,
    rotation: _OptionalFloat64 = SIMD(0),
)
```

Draw the `width` by `height` rectangle centred on `position`, its corners rounded by `corner_radius`, or by the style's when not given (clamped to half the shorter side), and turned about its centre by `rotation` radians counter-clockwise, as `Rectangle` describes it.

```mojo
def rectangle(
    mut self,
    position: Point,
    width: Int,
    height: Int,
    *,
    corner_radius: _OptionalFloat64 = None,
    rotation: _OptionalFloat64 = SIMD(0),
)
```

### `circle`

```mojo
def circle(mut self, position: Point, radius: Float64)
def circle(mut self, position: Point, radius: Int)
```

### `ellipse`

```mojo
def ellipse(mut self, position: Point, width: Float64, height: Float64)
```

Draw the axis-aligned ellipse centred on `position`, `width` wide and `height` high: an `Ellipse`, filling the rectangle `rectangle(position, width, height)` would draw. Turn one with `transform`.

The stroke is inset, as a circle's is, and as thick all round: the
fill stops where it starts, and a translucent ellipse composites
once. It is drawn as a polygon, flattened as finely as a circle of
its larger radius, so filled it costs what a circle does and
stroked what a stroked `polygon` of its outline does, about three
times a circle's. It casts no inset shadow; a blurred drop shadow
costs what a `bezier`'s does. With `width == height` it covers what
`circle(position, width / 2)` does, to within its flattening.

```mojo
def ellipse(mut self, position: Point, width: Int, height: Int)
```

### `capsule`

```mojo
def capsule(mut self, start: Point, end: Point, radius: Float64)
```

Draw the capsule round the segment from `start` to `end`: every point within `radius` of it, a `Capsule`, its ends half discs.

The stroke is inset, as a circle's is: the fill stops where it
starts, and a translucent capsule composites once. Unlike a
round-capped `line`, it has a fill and a stroke of its own. It is
drawn as a polygon, each end flattened as finely as a circle of
`radius`, so filled it costs what a circle does and stroked what a
stroked `polygon` of its outline does. It casts no inset shadow; a
blurred drop shadow costs what a `bezier`'s does. A zero `radius` draws
nothing.

```mojo
def capsule(mut self, start: Point, end: Point, radius: Int)
```

### `sector`

```mojo
def sector(
    mut self,
    position: Point,
    radius: Float64,
    start_angle: Float64,
    sweep_angle: Float64,
    *,
    corner_radius: _OptionalFloat64 = None,
)
```

Draw the pie slice of the circle around `position` with `radius`, from `start_angle` round by `sweep_angle`: a `Sector`, its tip at `position`.

Angles are radians, counter-clockwise from the +x axis (y is up); a
negative sweep runs clockwise, and a full turn or more is the whole
disc. The stroke is inset, as a circle's is: the fill stops where it
starts, and a translucent sector composites once. It casts no inset
shadow; a blurred drop shadow costs what a `bezier`'s does. A zero
radius or sweep draws nothing.

`corner_radius`, or the style's when not given, rounds the tip and
both ends of the arc, as `Sector` describes. A rounded sector is drawn as a polygon, so it costs what
a stroked `polygon` of its flattened outline does.

```mojo
def sector(
    mut self,
    position: Point,
    radius: Int,
    start_angle: Float64,
    sweep_angle: Float64,
    *,
    corner_radius: _OptionalFloat64 = None,
)
```

### `polygon`

```mojo
def polygon(mut self, *vertices: Point, *, corner_radius: _OptionalFloat64 = None)
```

Draw the polygon through `vertices`, closed back to the first.

Filled by the nonzero rule, so a self-crossing polygon fills every
area its edges wind round, whichever way they run. The stroke is
inset along the outside, as a sector's is, and centred on an edge
running through the inside — a pentagram's inner pentagon — so every
edge is stroked as thick; a translucent polygon composites once. It
casts no inset shadow; a blurred drop shadow costs what a `bezier`'s
does. Fewer than three vertices draw nothing.

`corner_radius`, or the style's when not given, rounds every corner,
as `Polygon` describes; each
rounded corner adds vertices, and so cost. A `Polygon` value is drawn
with `draw`.

```mojo
def polygon(mut self, var vertices: List[Point], corner_radius: _OptionalFloat64 = None)
```

Draw the polygon through `vertices`, a list built at run time: otherwise as the variadic `polygon`, and like `spline`'s `points`.

### `line`

```mojo
def line(mut self, start: Point, end: Point)
```

Stroke the line from `start` to `end` in the stroke colour and thickness, its ends finished as `stroke_cap` says. A line has no interior, so `fill` never applies; a line of no length is a dot under `StrokeCap.ROUND` or `SQUARE` and nothing under `BUTT`.

### `bezier`

```mojo
def bezier(mut self, start: Point, control1: Point, control2: Point, end: Point)
```

Stroke the cubic Bézier from `start` to `end`, shaped by the two controls, in the stroke colour and thickness.

A curve, like a line, has no interior: `fill` never applies, and with
the stroke off nothing is drawn. The curve is flattened at replay,
in device pixels, so it stays smooth under any camera zoom; its ends
are finished as `stroke_cap` says, like a line's, unless `end` is
`start`: then the curve closes on a mitred joint and has none. Joints
are mitred and caps share the end's edge, so a translucent stroke
composites once, except at a sharp cusp, where it may overlap slightly.

A blurred shadow is blurred afresh every frame (it cannot be cached
like an image's), and on the GPU costs one extra draw call.

### `spline`

```mojo
def spline(
    mut self,
    var points: List[Point],
    alpha: Float64 = 0.5,
    closed: Bool = False,
)
```

Stroke a smooth curve through every one of `points`, in order, in the stroke colour and thickness: a `Spline`, which is Catmull-Rom.

`alpha` sets how the spacing of the points shapes the curve: 0 can
loop or cusp where points bunch up, 0.5 (centripetal) never does,
1 hugs the points more loosely still. With `closed`, the curve runs
on from the last point back to the first, and that joint is mitred
like the rest.

Drawn as one stroke, like `bezier`: no fill, nothing with the stroke
off, ends as `stroke_cap` says when open, and a translucent stroke
composites once. A blurred shadow costs what a `bezier`'s does. Fewer
than two distinct
points draw nothing.

### `arc`

```mojo
def arc(
    mut self,
    position: Point,
    radius: Float64,
    start_angle: Float64,
    sweep_angle: Float64,
)
```

Stroke the arc of the circle around `position` with radius `radius`, from `start_angle` round by `sweep_angle`, in the stroke colour and thickness: an `Arc`.

Angles are radians, counter-clockwise from the +x axis (y is up); a
negative sweep runs clockwise, and a full turn or more is the whole
circle, closed on a mitred joint.

Drawn as one stroke, like `bezier`: no fill, nothing with the stroke
off, ends as `stroke_cap` says short of a whole turn, and a translucent
stroke composites once. A blurred shadow costs what a `bezier`'s does.
A zero radius or sweep
draws nothing.

```mojo
def arc(
    mut self,
    position: Point,
    radius: Int,
    start_angle: Float64,
    sweep_angle: Float64,
)
```

### `triangle`

```mojo
def triangle(
    mut self,
    a: Point,
    b: Point,
    c: Point,
    *,
    corner_radius: _OptionalFloat64 = None,
)
```

Draw the triangle through `a`, `b` and `c`, its corners rounded by `corner_radius`, or by the style's when not given, as `Triangle` describes it.

### `image`

```mojo
def image(mut self, image: Image, position: Point)
```

Render `image` at its own pixel size.

The same command as the sized overload: at a pixel scale of 1 the two
agree exactly, and the one-image-pixel-per-framebuffer-pixel shortcut
they used to differ by now lives inside `blit_image`, where the replay
can take it without the record site having to know.

```mojo
def image(mut self, image: Image, position: Point, width: Float64, height: Float64)
```

```mojo
def image(mut self, animator: Animator, position: Point)
```

Render the animator's current frame, centred at `position`.

```mojo
def image(
    mut self,
    animator: Animator,
    position: Point,
    width: Float64,
    height: Float64,
)
def image(mut self, image: Image, position: Point, width: Int, height: Int)
def image(mut self, animator: Animator, position: Point, width: Int, height: Int)
```

### `text_color`

```mojo
def text_color(mut self, color: Color)
```

Paint glyphs in `color`. Separate from `fill`, so a shape colour and a label colour do not have to be set in turn; a fully transparent one skips the text entirely.

### `font_size`

```mojo
def font_size(mut self, size: Float64)
```

Text height in world units, scaled by autoscale like a coordinate. Glyphs are rasterised at whole pixel sizes, so a fractional size rounds once scaled.

```mojo
def font_size(mut self, size: Int)
```

### `font_weight`

```mojo
def font_weight(mut self, weight: FontWeight)
```

Stroke weight of the face, a `FontWeight`. The packaged Noto faces are variable, so this interpolates rather than swapping files.

### `font_italic`

```mojo
def font_italic(mut self, enabled: Bool)
```

Draw text in the face's italic: the font's `italic_path` file where it has one (the packaged Noto Sans does), otherwise its own italic axis, otherwise its upright glyphs slanted.

### `tint`

```mojo
def tint(mut self, color: Color)
```

Multiply whatever is rendered next by `color`, channel by channel.

Reaches fill, gradient, stroke, text, image and shadow alike, never
`background`. `Color.WHITE` (the default) leaves it untouched; a
colour recolours and darkens, and its alpha fades like `opacity`,
which it stacks with. Tints a whole look at once, where `fill`,
`stroke` and `text_color` each set one part:

```mojo
with canvas.style(tint=Color(255, 90, 90)):
    self.player.draw(canvas)
```

Resolved at record time, like every other style setting.

### `opacity`

```mojo
def opacity(mut self, value: Float64)
```

Fade whatever is rendered next: fill, gradient, stroke, text, image and shadow alike, never `background`. `1.0` (the default) leaves it untouched; `0.0` renders nothing visible. Each shape composites once, so a translucent one is evenly translucent, stroke and fill included. Resolved at record time, like every other style setting — it cannot reach back and fade what was already rendered.

### `blend_mode`

```mojo
def blend_mode(mut self, mode: BlendMode)
```

Combine whatever is rendered next with what is already there by `mode` — `BlendMode.ADD` for glows, `MULTIPLY` for shadows — instead of painting over it. `BlendMode.NORMAL` (the default) paints over.

Applies to shapes, text and images, never to `background`.

### `shadow`

```mojo
def shadow(
    mut self,
    color: Optional[Color] = None,
    offset: Optional[Vector] = None,
    blur: _OptionalFloat64 = None,
    spread: _OptionalFloat64 = None,
    inset: Optional[Bool] = None,
)
```

Cast a shadow behind what is rendered next, switching shadows on. Parts left unset keep their current values, so `shadow()` alone brings back the last shadow, and `shadow(blur=12)` changes only the blur; a fresh frame starts at a translucent black, an offset of `(4, -4)` (down and right, since y is up), a blur of 8 and no spread.

Works like CSS `drop-shadow`: the shadow is the shape's whole
silhouette, fill and stroke together, cast once — a translucent
fill shows its own shadow through it. Lines cast their stroke, text
its glyphs and images their alpha. `blur` is the CSS blur radius,
twice the Gaussian's standard deviation; `spread` grows the
silhouette before blurring. Both are world units, scaled like a
coordinate.

`inset=True` paints the shadow inside the shape instead, over its
fill and within its stroke, as if the shape were a hole cut in a
surface: the band shows on the side the offset points away from.
Only rectangles, circles and triangles take an inset shadow; lines,
text and images cast none while it is set.

The offset is fixed to the screen, so a rotated shape's shadow still
falls the same way; see `shadow_follows_transform`. The shadow
combines with what is beneath it by the style's `blend_mode`, like
the shape itself.

```mojo
canvas.shadow(Color(0, 0, 0, 96), offset=Vector(6, -6), blur=12)
canvas.rectangle((0, 0), 120, 80)
```

### `shadow_enabled`

```mojo
def shadow_enabled(mut self, enabled: Bool)
```

Switch shadows off or back on. Colour, offset, blur, spread and inset are kept while off, so `shadow_enabled(True)` brings back the same shadow; `shadow(color)` switches it on too. Off by default.

### `shadow_follows_transform`

```mojo
def shadow_follows_transform(mut self, follows: Bool)
```

Whether the shadow's offset turns with the transform.

`False` (the default) keeps it fixed to the screen, as a light
overhead would: a rotating shape's shadow always falls the same way.
Camera zoom and autoscale still scale it, so it stays in proportion.
`True` applies the offset in the shape's own frame, before the
transform, so it rotates and shears with the shape, as a CSS
shadow does under a CSS transform.

### `text_alignment`

```mojo
def text_alignment(mut self, align: Align)
```

Anchor the next text at one of the nine points of its box.

One argument covers both axes: `Align.CENTER` (the default) centres
the text on the position, like every other shape, and
`Align.TOP_LEFT` hangs it below and to the right of it. The one-word constants name an edge's
midpoint — `Align.TOP` is top-centre. These are edges of the text box,
not typographic baselines.

### `antialiasing`

```mojo
def antialiasing(self) -> Antialiasing
```

How smooth shape edges are: `run`'s `antialiasing` unless set.

```mojo
def antialiasing(mut self, level: Antialiasing)
```

Smooth shape edges at `level` — `OFF` for hard pixels.

A frame-wide setting: both backends rasterise the frame when it is
presented, so the level covers every shape in this frame, including
those drawn before the call, and lasts until changed. `run`'s
`antialiasing` argument is the starting level; set it here, in
`create` or any frame, to change it. See `Antialiasing`.

### `autoclear`

```mojo
def autoclear(self) -> Bool
```

Whether frames open with the clear to grey 200. On unless set.

```mojo
def autoclear(mut self, enabled: Bool)
```

Switch the clear each frame opens with off or back on.

On by default, clearing to grey 200 so the default style is visible
on a program that never calls `background()`. Off lets ink
accumulate across frames, on either backend.

A frame-wide setting: it applies to this whole frame, wherever in it
it is called — off takes this frame's opening clear back out, on puts
it back — and lasts until changed, so set it once in `create`. An
opaque `background()` already drawn this frame stays either way.

No effect on an offscreen canvas, which has no frames to open and
starts transparent; it is only read back.

### `letterbox_color`

```mojo
def letterbox_color(self) -> Color
```

The colour of the bars outside the design area. Black unless set.

```mojo
def letterbox_color(mut self, color: Color)
```

Colour the bars outside the design area under `Autoscale.FIT`.

A frame-wide setting: the bars are painted after the frame is drawn,
so this frame's bars take it wherever in the frame it is called, and
it lasts until changed — set it once in `create`. Not part of a
style. No effect on an offscreen canvas, which has no window to bar.

### `font`

```mojo
def font(mut self, font: Font)
```

Draw the next text in `font`, a face from `Font.load`.

Part of the style, like `fill`: it holds for the rest of the frame,
or for a `with canvas.style(font=...)` block, and each `text` call
keeps the face it was drawn with. The next frame starts in the
packaged Noto Sans again, so a font for the whole program is a
field set at the top of `update`, or kept in a `Style`.

### `text_width`

```mojo
def text_width(self, text: String) raises -> Float64
```

How wide `text(text, ...)` would render under the current font, size and weight, in the units the next render call is positioned in: the width of its widest line.

Exact for any prefix of a line too, since glyphs sit advance to
advance with no kerning, so a caret after a line's first few
characters goes at the line's left edge plus the width of those
characters. With the default `Align.CENTER`, that left edge is
`position.x - text_width(line) / 2`.

Raises only if the default font has to be loaded and cannot be.

```mojo
def text_width(self, text: String, *, width: Float64) raises -> Float64
```

How wide `text(text, ..., width)` would render: the width of its widest line once wrapped at `width`, at most `width` unless a single glyph is wider.

Raises only if the default font has to be loaded and cannot be.

### `text_height`

```mojo
def text_height(self, text: String) raises -> Float64
```

How tall `text(text, ...)` would render under the current font and size, in the units the next render call is positioned in: from the font's ascent above the first line to its descent below the last, the box `text_alignment` anchors. Each line break adds the font's line height.

Raises only if the default font has to be loaded and cannot be.

```mojo
def text_height(self, text: String, *, width: Float64) raises -> Float64
```

How tall `text(text, ..., width)` would render: its height once wrapped at `width`, every line it wraps onto counted.

Raises only if the default font has to be loaded and cannot be.

### `text`

```mojo
def text(mut self, text: String, position: Point)
```

Draw `text` at `position` in the current text style, anchored by `text_alignment`.

A newline starts a new line, the font's line height below; each line
is aligned on its own, and the alignment's top and bottom are those
of the whole block (see `text_height`).

```mojo
def text(mut self, text: String, position: Point, width: Float64)
```

Draw `text` at `position` as `text(text, position)` does, wrapped onto as many lines as keep each at most `width` units wide.

A line breaks at its last space that fits, the spaces dropped; a word
wider than `width` alone breaks between its letters. Newlines still
break, and each line is aligned on its own, so `text_alignment` both
anchors the block and aligns its lines: `Align.TOP_LEFT` sets ragged
right text hanging from `position`. Measure the block with
`text_width(text, width=...)` and `text_height(text, width=...)`.
