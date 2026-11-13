# Drawing

How shapes reach the screen: drawing them, drawing your own types, the background each frame
starts from, transforms, antialiasing and clipping. How they look (colours, strokes, gradients,
shadows, text) is [Style](style.md).

## Shapes

`canvas.draw(shape)` draws any shape or curve — `Rectangle`, `Circle`, `Ellipse`, `Capsule`,
`Triangle`, `Sector`, `Polygon`, `Line`, `Arc`, `Bezier`, `Spline` — in the current style and
transform. The named methods build a shape from numbers and draw it, so
`canvas.rectangle(p, w, h)` is `canvas.draw(Rectangle(p, w, h))`:

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

A shape value is drawn with `draw`; there is no `canvas.rectangle(r)`. The shapes themselves, and
the collision tests between them, are [Geometry](geometry.md).

## Your own types

A program's own type is drawn the same way, by conforming to `Drawable` and drawing its parts:

```mojo
# A fragment of examples/drawables.
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
`DrawTarget` is where it draws: `Canvas`, through one `_`-named primitive per kind, which are the
library's own, and the provided `draw`. Both, and the shape traits, live in `geometry`, so a shape
never imports `render`. Dispatch is static (one instantiation per type), so a list of different
drawables still needs `Variant`.

## The background

Every frame opens with a clear to gray 200, so the style's defaults (a black stroke, see
[Style](style.md#defaults)) are visible on it. `canvas.background()` is the only way to choose the
colour, and belongs first in `update`:

- An opaque `canvas.background()` replaces that clear rather than painting a second time; a
  translucent one blends over it.
- `canvas.autoclear(False)` switches the clear off, so ink accumulates from frame to frame, as in
  a painting program. It applies to the whole current frame: off takes the frame's opening clear
  back out, on puts it back, and an opaque `background()` already drawn stays. It lasts until
  changed, so set it once in `create`. Accumulating works on the CPU backend only, since the GPU
  swaps buffers.

## Settings that outlive the frame

Style, transform, camera and clip reset every frame. A few canvas settings are carried from frame
to frame instead (on the internal `_PersistentCanvasState`) and last until changed, so set them
once in `create`:

- `autoclear`, above.
- `letterbox_color`, the bars outside the design under `FIT` (see
  [Coordinates](coordinates.md#design-size-and-autoscale)), black by default.
- `antialiasing`, below.

Each is frame-wide: it applies to the whole frame it is set in, since nothing is rasterised until
the frame is presented, and reads back with no arguments (`canvas.antialiasing()`).

## Transforms and guards

`canvas.transform(m)` moves, turns or scales everything drawn after it by a matrix from `math`
(`translate`, `rotate`, `scale`). Like `canvas.style(...)`, `canvas.overlay()` and
`canvas.clip(...)`, it returns a guard that, used in a `with` block, unwinds when the block ends:

```mojo
# A fragment of an `update`.
with canvas.transform(translate(100, 0) @ rotate(context.time.elapsed)):
    canvas.rectangle((0, 0), 60, 60)  # spins about (100, 0)
canvas.rectangle((0, 0), 60, 60)  # upright again
```

Bare style setters straight from `update` are fine, since style, transform and camera reset every
frame. A *helper* that sets style wraps it in `with canvas.style():`, with no arguments, so it
can't leak into whatever its caller draws next.

## Antialiasing

Antialiasing smooths the edges of shapes. `run(..., antialiasing=Antialiasing.MEDIUM)` is the
starting level; `OFF`, `LOW` and `HIGH` are the others, and `canvas.antialiasing(level)` changes
it for the whole frame it is called in (both backends rasterise when the frame is presented) and
every later one.

It is one setting for both backends, each reaching it its own way: the GPU draws into an
offscreen multisampled framebuffer and resolves it into the window or headless target (capped at
the driver's maximum); the CPU samples each shape on a finer grid (`LOW` 2x2, `MEDIUM` 4x4,
`HIGH` 8x8 per pixel).

It smooths shapes and the edge of a rotated or sheared image; text and an image's own pixels are
smooth already, and a clip's edge is antialiased like a shape's (see [Clipping](#clipping)). A
shape's fill and stroke composite together, so no seam shows between them; two separate shapes
meeting inside a pixel can show a faint one.

`run_headless` defaults to `MEDIUM` too, so a test asserting an edge pixel's exact colour passes
`antialiasing=Antialiasing.OFF`.

## Clipping

`with canvas.clip(region):` renders only inside `region` for the block, and `invert=True` keeps
only what is outside it, for fog or a spotlight:

```mojo
# A fragment of an `update`: darkness everywhere but a circle round the mouse.
with canvas.clip(Circle(context.mouse.position, 120), invert=True):
    canvas.background(Color(0, 0, 0, 220))
```

`region` is any `Region` — a `Rectangle`, `Circle`, `Ellipse`, `Capsule`, `Triangle`, `Sector` or
`Polygon`, the region types of `contains` and `overlaps` — rounded by its own `corner_radius` as
when drawn. A curve is rejected at compile time. A clip is guard-only: there is no bare clip to
forget to undo. See [examples/clipping](../examples/clipping/main.mojo).

- **Frozen at the call**, like a render call: the clip is placed by the transform and camera
  current then. A `transform` or `overlay` inside the block moves what is drawn, not the clip.
- **Nested clips intersect.** On exit the enclosing clip is current again.
- **Everything is clipped**: shapes, images, text, shadows, and `background()`, which then paints
  only the clipped area (and never replaces the autoclear). The letterbox is not.
- **Edges** are antialiased at the frame's level, like a shape's: on the CPU a clip keeps exactly
  the coverage a fill of the same shape paints, on the GPU its stencil is multisampled. So the two
  backends agree inside a clip and may differ slightly along its rim. With `Antialiasing.OFF` a
  clip is hard-edged. Nested clips multiply their edges' coverage.

Soft masks (a gradient or an image's alpha) are not implemented yet.
