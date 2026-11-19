# The canvas

Everything a program shows, it draws on the canvas it is handed each frame. This page explains how
shapes reach the screen: drawing them, drawing your own types, the background each frame starts
from, moving and turning what you draw with transforms, smoothing edges and clipping. How shapes
look (their colours, strokes, gradients, shadows and text) is explained in [Style](style.md).

## Shapes

`canvas.draw(shape)` draws any shape or curve (`Rectangle`, `Circle`, `Ellipse`, `Capsule`,
`Triangle`, `Sector`, `Polygon`, `Line`, `Arc`, `Bezier` or `Spline`) in the current style and
transform. The named methods build a shape from numbers and draw it, so `canvas.rectangle(position,
width, height)` is `canvas.draw(Rectangle(position, width, height))`:

```mojo
from create import *


@fieldwise_init
struct Shapes(Program):
    var sun: Circle

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> Shapes:
        return Shapes(Circle((150, 120), 40))

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        canvas.background(Color(200, 230, 255))
        canvas.fill(Color.YELLOW)
        canvas.draw(self.sun)  # a shape value
        canvas.fill(Color.GREEN)
        canvas.rectangle((0, -150), 640, 120)  # built from numbers
        canvas.line((-200, -90), (-200, 40))


def main() raises:
    run[Shapes]("Shapes")
```

A shape value is drawn with `draw`; there is no `canvas.rectangle(r)`. Every call that draws
something, such as `canvas.circle`, `canvas.draw` or `canvas.text`, is a **render call**: it uses
the style and transform current when it is made, and later changes don't reach back to it. The
shapes themselves are described in [Shapes](../geometry/shapes.md) and
[Curves](../geometry/curves.md), and the tests for whether they touch in
[Collisions](../geometry/collisions.md).

## Your own types

A program's own type is drawn the same way, by conforming to `Drawable` and drawing its parts:

```mojo
# From examples/drawables:
@fieldwise_init
struct Button(Copyable, Drawable, Movable):
    var plate: Rectangle
    var icon: Circle

    def draw_to[T: DrawTarget](self, mut target: T):
        target.draw(self.plate)
        target.draw(self.icon)
```

`canvas.draw(button)` then draws both parts. Style comes from the canvas, not the parts, so set the
fill before drawing it. See [examples/drawables](../../../examples/drawables/main.mojo).

`Drawable` is what `canvas.draw` takes: every shape, or a program's own type that draws its parts.
`DrawTarget` is what `draw_to` draws into, which is the canvas. To keep drawables of different types
in one list, use `Variant` (see [Multiple scenes](../basics/programs.md#multiple-scenes)).

## The background

Every frame starts cleared to light grey, `Color(200)`. A shape drawn in the default style is a thin
black outline (see [Style](style.md#defaults)), so it shows up on the grey. `canvas.background()`
paints the frame another colour. It paints over everything drawn before it in the frame, so call it
before anything else you draw:

- A translucent `background()` blends over that grey, not over the last frame, so fading trails need
  the autoclear off (below). An opaque one costs nothing extra: it replaces the clear.
- `canvas.autoclear(False)` switches the clear off, so ink accumulates from frame to frame, as in a
  painting program. It applies to the whole frame it is called in, wherever in `update` it is
  called, and lasts until changed, so set it once in `create`. Resizing the window starts the
  drawing over from transparent, and on the GPU backend so does changing `canvas.antialiasing`.

**Starting over.** `canvas.clear()` discards everything drawn so far, back to how the canvas
started: an [offscreen canvas](../media/images.md#drawing-into-an-image) becomes transparent again,
and the frame's canvas returns to the clear it started from (or, with the autoclear off, to the last
frame's pixels). Style, transform and settings are untouched. To paint over what is there instead,
use `background()`.

## Settings that outlive the frame

Style, transform, camera and clip reset every frame. A few canvas settings are carried from frame to
frame instead and last until changed, so set them once in `create`. Everything that lasts, and for
how long, is listed in [What lasts how long](../basics/programs.md#what-lasts-how-long). The canvas
settings are:

- `autoclear`, above.
- `letterbox_color`, the bars outside the design under `FIT` (see
  [Coordinates](../basics/coordinates.md#design-size-and-autoscale)), black by default.
- `antialiasing`, below.

Each applies to the whole frame it is set in, not only to what is drawn after it, and reads back
with no arguments (`canvas.antialiasing()`).

## Transforms and guards

`canvas.translate(delta)`, `canvas.rotate(angle)` and `canvas.scale(s)` move, turn and scale
everything drawn after them, each applying inside the ones before it, as in Processing. Like the
style, what they set lasts until the end of the frame. `with canvas.transform():` keeps the
transform as it is for a block, and puts it back when the block ends, so a transform set inside it
applies only to the block. `canvas.style(...)`, `canvas.overlay()` and `canvas.clip(...)` work the
same way; each returns a **guard**, the object the `with` block holds:

```mojo
# In `update`:
with canvas.transform():
    canvas.translate(Vector(100, 0))
    canvas.rotate(context.time.elapsed)
    canvas.rectangle((0, 0), 60, 60)  # spins about (100, 0)
canvas.rectangle((0, 0), 60, 60)  # upright again
```

`with canvas.transform(t):` does the same, and also applies the `Transform` `t` for the block. What
a transform is, the order the calls apply in and how transforms combine are explained in
[Transforms](../math/transforms.md). Blocks nest, each one's transform applying inside the one
around it.

Calling the style setters or the transform calls directly in `update` is fine, since both reset
every frame. A helper function that changes either should wrap its drawing in `with canvas.style():`
or `with canvas.transform():` (no arguments), so its changes don't leak into what its caller draws
next. On an offscreen canvas, which has no frames, they last until a guard around them ends, or for
as long as the canvas is kept.

## Antialiasing

A screen is a grid of square pixels, so a slanted or curved edge drawn with whole pixels looks like
a staircase. **Antialiasing** smooths the staircase away, by colouring the pixels along an edge
partway between the shape and what is behind it. `run(..., antialiasing=Antialiasing.MEDIUM)` is the
starting level; `OFF`, `LOW` and `HIGH` are the others. `canvas.antialiasing(level)` changes it,
starting with the whole of the frame it is called in.

It is one setting for both backends. A pixel along an edge is coloured by how much of it the shape
covers, which is found by testing several points inside the pixel. The CPU tests a grid of them
(`LOW` 2x2, `MEDIUM` 4x4, `HIGH` 8x8). The GPU uses the graphics card's own multisampling, with as
many points as the level asks for, or fewer if that is all the driver allows.

It smooths shapes and the edge of a rotated or sheared image. Text and an image's own pixels are
smooth already, and a clip's edge is smoothed like a shape's (see [Clipping](#clipping)). A shape's
fill and stroke are blended onto the frame together, as one, so no seam shows between them. Two
separate shapes that meet inside a pixel are blended one after the other, each covering only part of
it, so a faint seam can show where they meet.

`run_headless` defaults to `MEDIUM` too, so a test that checks the exact colour of a pixel on an
edge should pass `antialiasing=Antialiasing.OFF`.

## Clipping

Clipping limits drawing to a region, as painting through a stencil does: inside `with
canvas.clip(region):`, only what falls inside `region` is drawn. `invert=True` keeps only what is
outside it instead, for fog or a spotlight:

```mojo
# In `update`: darkness everywhere but a circle round the mouse.
with canvas.clip(Circle(context.mouse.position, 120), invert=True):
    canvas.background(Color(0, 0, 0, 220))
```

`region` can be any `Region`: a `Rectangle`, `Circle`, `Ellipse`, `Capsule`, `Triangle`, `Sector` or
`Polygon`, the same types `contains` and `overlaps` take. It is rounded by its own `corner_radius`,
as when it is drawn. Lines and curves can't be clips (that doesn't compile). A clip only works as a
`with` block, so it can't accidentally stay on. See
[examples/clipping](../../../examples/clipping/main.mojo).

- **The clip is placed when the block starts**, like a render call, by the transform and camera
  current then. A `transform` or `overlay` inside the block moves what is drawn, not the clip.
- **A clip inside another** draws only where both allow. When the inner block ends, the outer clip
  applies again.
- **Everything is clipped**: shapes, images, text, shadows and `background()`, which then paints
  only the clipped area. The letterbox is not.
- **Edges** are smoothed at the frame's antialiasing level, like a shape's, so the two backends
  agree inside a clip and may differ slightly along its rim. With `Antialiasing.OFF` a clip is
  hard-edged. Where the edges of nested clips pass through the same pixel, their smoothing combines:
  a pixel half inside each of two clips is drawn at a quarter strength.

A clip is always a region: a gradient or an image's alpha can't be used as a soft mask.
