# Drawing

How shapes reach the screen: drawing them, drawing your own types, the background each frame
starts from, transforms, antialiasing and clipping. How they look (colours, strokes, gradients,
shadows, text) is [Style](style.md).

## Shapes

`canvas.draw(shape)` draws any shape or curve — `Rectangle`, `Circle`, `Ellipse`, `Capsule`,
`Triangle`, `Sector`, `Polygon`, `Line`, `Arc`, `Bezier`, `Spline` — in the current style and
transform. The named methods build a shape from numbers and draw it, so
`canvas.rectangle(position, width, height)` is `canvas.draw(Rectangle(position, width, height))`:

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
shapes themselves, and the collision tests between them, are [Geometry](geometry.md).

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

`canvas.draw(button)` then draws both parts. Style comes from the canvas, not the parts, so set
the fill before drawing it. See [examples/drawables](../examples/drawables/main.mojo).

`Drawable` is what `canvas.draw` takes: every shape, or a program's own type that draws its parts.
`DrawTarget` is what `draw_to` draws into, the canvas. To keep drawables of different types in one
list, use `Variant` (see [Multiple scenes](programs.md#multiple-scenes)).

## The background

Every frame starts cleared to light gray, `Color(200)`, so a shape drawn in the default style (a
thin black outline, see [Style](style.md#defaults)) shows up on it. `canvas.background()` paints the
frame another colour. It paints over everything drawn before it in the frame, so call it before
anything else you draw:

- A translucent `background()` blends over that gray, not over the last frame, so fading trails
  need the autoclear off (below). An opaque one costs nothing extra: it replaces the clear.
- `canvas.autoclear(False)` switches the clear off, so ink accumulates from frame to frame, as in
  a painting program. It applies to the whole frame it is called in, wherever in `update` it is
  called, and lasts until changed, so set it once in `create`. Resizing the window starts the
  drawing over from transparent, and on the GPU backend so does changing `canvas.antialiasing`.

## Settings that outlive the frame

Style, transform, camera and clip reset every frame. A few canvas settings are carried from frame
to frame instead and last until changed, so set them once in `create` (all that lasts, and how
long, is in [What lasts how long](programs.md#what-lasts-how-long)):

- `autoclear`, above.
- `letterbox_color`, the bars outside the design under `FIT` (see
  [Coordinates](coordinates.md#design-size-and-autoscale)), black by default.
- `antialiasing`, below.

Each applies to the whole frame it is set in, not only to what is drawn after it, and reads back
with no arguments (`canvas.antialiasing()`).

## Transforms and guards

`with canvas.transform(m):` moves, turns or scales everything drawn inside the block by a matrix
from `math` (`translate`, `rotate`, `scale`), and the block's end undoes it. It only works as a
`with` block, so a transform can't accidentally stay on. `canvas.style(...)`, `canvas.overlay()`
and `canvas.clip(...)` work the same way; each returns a **guard**, the object the `with` block
holds:

```mojo
# In `update`:
with canvas.transform(translate(100, 0) @ rotate(context.time.elapsed)):
    canvas.rectangle((0, 0), 60, 60)  # spins about (100, 0)
canvas.rectangle((0, 0), 60, 60)  # upright again
```

`a @ b` combines two matrices, and the one on the right applies first: above, the square is
turned about its own centre, then moved to `(100, 0)`. Blocks nest, each inside the last.

Calling style setters directly in `update` is fine, since style resets every frame. A helper
function that changes the style should wrap its drawing in `with canvas.style():` (no arguments),
so its changes don't leak into what its caller draws next.

## Antialiasing

Antialiasing smooths the edges of shapes. `run(..., antialiasing=Antialiasing.MEDIUM)` is the
starting level; `OFF`, `LOW` and `HIGH` are the others, and `canvas.antialiasing(level)` changes
it from the frame it is called in on, for the whole of that frame.

It is one setting for both backends: the GPU multisamples (capped at what the driver supports),
and the CPU samples each shape on a finer grid (`LOW` 2x2, `MEDIUM` 4x4, `HIGH` 8x8 per pixel).

It smooths shapes and the edge of a rotated or sheared image; text and an image's own pixels are
smooth already, and a clip's edge is antialiased like a shape's (see [Clipping](#clipping)). A
shape's fill and stroke composite together, so no seam shows between them; two separate shapes
meeting inside a pixel can show a faint seam.

`run_headless` defaults to `MEDIUM` too, so a test asserting an edge pixel's exact colour passes
`antialiasing=Antialiasing.OFF`.

## Clipping

`with canvas.clip(region):` draws only inside `region` for the block, and `invert=True` keeps
only what is outside it, for fog or a spotlight:

```mojo
# In `update`: darkness everywhere but a circle round the mouse.
with canvas.clip(Circle(context.mouse.position, 120), invert=True):
    canvas.background(Color(0, 0, 0, 220))
```

`region` is any `Region` — a `Rectangle`, `Circle`, `Ellipse`, `Capsule`, `Triangle`, `Sector` or
`Polygon`, the region types of `contains` and `overlaps` — rounded by its own `corner_radius` as
when drawn. Lines and curves can't be clips (that doesn't compile). A clip only works as a `with`
block, so it can't accidentally stay on. See [examples/clipping](../examples/clipping/main.mojo).

- **Placed when the block starts**, like a render call: by the transform and camera current
  then. A `transform` or `overlay` inside the block moves what is drawn, not the clip.
- **Nested clips intersect.** On exit the enclosing clip is current again.
- **Everything is clipped**: shapes, images, text, shadows, and `background()`, which then paints
  only the clipped area. The letterbox is not.
- **Edges** are antialiased at the frame's level, like a shape's, so the two backends agree inside
  a clip and may differ slightly along its rim. With `Antialiasing.OFF` a clip is
  hard-edged. Nested clips multiply their edges' coverage.

Soft masks (a gradient or an image's alpha) are not implemented yet.
