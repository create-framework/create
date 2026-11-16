# Coordinates, camera and autoscale

Where things land on the screen: Create's coordinate system, points and vectors, the three spaces
a position can be in, the camera, and how the size a program is written for maps onto a real
window.

## The screen

**These are not Processing's coordinates.** The origin is the centre of the screen and **y points
up**:

```text
               top()
                ▲ +y
                │
                │
left() ───────(0,0)──────▶ right()
                │       +x
                │
             bottom()
```

So `x ∈ [-w/2, w/2]` and `y ∈ [-h/2, h/2]`; `rotate` turns counter-clockwise; gravity is negative
`y`; and `canvas.left()` and `canvas.bottom()` are negative. Lay things out against the edge
methods (`left()`, `right()`, `bottom()`, `top()`) rather than by arithmetic on `width` and
`height`:

```mojo
from create import *


@fieldwise_init
struct Corners(Program):
    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> Corners:
        return Corners()

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        canvas.background(Color.WHITE)
        canvas.fill(Color.BLUE)
        canvas.circle((canvas.left() + 30, canvas.top() - 30), 20)  # top left
        canvas.circle((canvas.right() - 30, canvas.bottom() + 30), 20)  # bottom right
        canvas.rectangle((0, 0), 200, 100)  # centred on the origin


def main() raises:
    run[Corners]("Corners")
```

`canvas.width()` and `canvas.height()` are in units, not pixels, and are `Float64`: under `EXTEND`
(below) they can be fractional. `canvas.bounds()` is the screen as a `Rectangle`, for
`snapshot`, `clip` or `contains`.

**Every shape is positioned by its centre**, `Rectangle.position` included, as the rectangle above
shows. Text and images still appear the right way up although y points up; they turn, shear and
mirror only under `canvas.transform`, like everything else drawn.

## Points and vectors

Positions, movements and sizes each have their own kind of value:

- A **location** is a `Point2D`: `canvas.circle(position, radius)`, `context.mouse.position`.
- A **displacement** is a `Vector2D`: `translate(delta)`, a velocity.
- An **extent** is a scalar: `width`, `height`, `radius`.

```mojo
# In `create`, building the `position` and `velocity` fields:
var position = Point2D(0, 0)
var velocity = Vector2D.from_angle(PI / 4, 100)  # 100 units a second, up and to the right

# In `update`:
self.position = self.position + self.velocity * context.time.delta  # a point moved by a vector
var to_mouse = context.mouse.position - self.position  # point minus point is a vector
var speed = to_mouse.limit(300)  # at most 300 long
```

- Crossing between them is an explicit constructor, `Vector2D(p)` or `Point2D(v)`, never an
  implicit one.
- `Point2D` deliberately lacks `magnitude`, `normalize`, `dot`, scalar `*`, unary `-` and
  `Point2D + Point2D`: those mean nothing for a location.
- Only `Point2D` takes a bare tuple implicitly, so `(0, 0)` fills a `Point2D` parameter. A vector
  literal names its type: `p + Vector2D(1, 2)` moves `p`. But `p - (1, 2)` subtracts a *point*,
  giving the vector from `(1, 2)` to `p`; to move `p` back, write `p - Vector2D(1, 2)`.
- Named vectors are `comptime` constants: `Vector2D.ZERO`, `ONE`, `UP`, `DOWN`, `LEFT`, `RIGHT`
  (y is up, so `DOWN` is `(0, -1)`).
- Angles are radians counter-clockwise from +x: `Vector2D.from_angle(a, length)`, `v.angle()`,
  `v.rotate(a)`, with `v.with_length(l)` and `v.limit(max)` for speeds. Each returns a new
  vector, like `normalize`.

## Screen, world and local space

A position is always in one of three spaces:

| Space | What it is |
|---|---|
| Screen space | Origin-centred, y-up, camera-independent. `canvas.left()`…`top()`, `context.mouse.position` and `canvas.color_at` live here, and it is what `canvas.to_local` takes and `to_screen` gives |
| World space | What drawing calls use once a `Camera` is set; identical to screen space without one. Only the camera converts into it: `camera.to_world`/`to_screen` |
| Local space | The coordinates inside a `canvas.transform` block: what a drawing call's numbers mean there. `canvas.to_local(screen)`/`to_screen(local)` convert through the transform and the camera together |

## The camera

A `Camera` has a `position` (the world point at the centre of the screen) and a `zoom`.
`canvas.camera(camera)` maps world space onto screen space for every later render call and nested
transform. It is reset every frame, so call it every frame. `canvas.overlay()` suspends it for HUD
content:

```mojo
# In `update`, with a `camera: Camera` field:
canvas.camera(self.camera)
canvas.image(self.player.image, self.player.position)  # world space
with canvas.overlay():
    canvas.text("Score: " + String(self.score), (0, canvas.top() - 20))  # screen space
```

`context.mouse.position` is in screen space. To pick what is under the mouse,
`canvas.to_local(context.mouse.position)` gives the position in the frame a shape is drawn in,
camera and transform included, and `camera.to_world(context.mouse.position)` gives the world
position.

## Design size and autoscale

The **design size** is the `width` and `height` passed to `run` (or set later with
`context.design_size(width, height)`): the space the program is authored in, not a window size.
Fullscreen and maximized windows scale the design onto the display. How it lands on a window of
another size is the **autoscale** mode, `run(..., autoscale=)` or `context.autoscale(mode)` later:

| Mode | Effect |
|---|---|
| `FIT` (default) | Scales the design uniformly to fit, centred; the leftover is letterbox bars. `canvas.width()`/`height()` never change |
| `EXTEND` | The same scale, no bars: the leftover becomes extra world, so the reported size grows with the window. Anchor layout to the edges |
| `OFF` | No scaling: coordinates are the window's own pixels |

To affect the very first frame, pass them to `run`: set from `create`, they take effect from
frame 2. Everything scales with the design, font sizes, stroke thicknesses and images included:
one unit is `canvas.scale()` window pixels. See [examples/window](../../examples/window/main.mojo).
