# Coordinates, camera and autoscale

Where things land on the screen: Create's coordinate system, the three spaces a position can be
in, the camera, and how the size a program is written for maps onto a real window.

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

`canvas.width()` and `canvas.height()` are `Float64` units: under `EXTEND` (below) the window's
pixels divide out to a fraction. `canvas.bounds()` is the screen as a `Rectangle`, for
`snapshot`, `clip` or `contains`.

**Every shape is positioned by its centre**, `Rectangle.position` included, as the rectangle above
shows. Glyphs and images are not flipped by the y-up axis, but they turn, shear and mirror with
`canvas.transform` like every render call.

## Screen, world and local space

A position is always in one of three spaces:

| Space | What it is |
|---|---|
| Screen space | Origin-centred, y-up, camera-independent. `canvas.left()`…`top()`, `context.mouse.position` and `canvas.color_at` live here, and it is what `canvas.to_local` takes and `to_screen` gives |
| World space | What render calls use once a `Camera` is set; identical to screen space without one. Only the camera converts into it: `camera.to_world`/`to_screen` |
| Local space | The current transform's frame, where a render call's coordinates are read. `canvas.to_local(screen)`/`to_screen(local)` convert through the transform and the camera together |

## The camera

A `Camera` has a `position` (the world point at the centre of the screen) and a `zoom`.
`canvas.camera(camera)` maps world space onto screen space for every later render call and nested
transform, and is reset every frame. `canvas.overlay()` suspends it for HUD content:

```mojo
# A fragment of an `update` whose program keeps a `camera: Camera` field.
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
`context.design_size(w, h)`): the space the program is authored in, not a window size. Fullscreen
and maximized windows scale the design onto the display. How it lands on a window of another size
is the **autoscale** mode, `run(..., autoscale=)` or `context.autoscale(mode)` later:

| Mode | Effect |
|---|---|
| `FIT` (default) | Scales the design uniformly to fit, centred; the leftover is letterbox bars. `canvas.width()`/`height()` never change |
| `EXTEND` | The same scale, no bars: the leftover becomes extra world, so the reported size grows with the window. Anchor layout to the edges |
| `OFF` | No scaling: coordinates are the window's own pixels |

Both `design_size` and `autoscale` decide frame 1's mapping only as `run` arguments, because the
viewport is derived before `create` runs. Font size, stroke thickness and image size scale with
the design, by `canvas.scale()`. See [examples/window](../examples/window/main.mojo).

## The run's settings

`Context`'s settings (its "dials") belong to the run, not the drawing: `design_size`,
`autoscale`, `title`, `window_mode`, `resizable`, `cursor`, `lock_mouse`, `text_input`,
`quit_on_escape`, `max_frame_rate`, `time_scale` and `time_paused` (see
[Slowing and pausing time](math.md#slowing-and-pausing-time)). Like the canvas setters, they are methods, each read back
with no arguments:

```mojo
# A fragment, inside `create`.
context.autoscale(Autoscale.EXTEND)
context.title("Level 1")
var mode = context.autoscale()  # Autoscale.EXTEND
```

`Context`'s only fields are the readings: `time`, `keyboard` and `mouse`. The gamepads are
`context.gamepad(player)`, a copy, since there can be several.

Every `run` argument but `backend` has a setter (a dial here, or `canvas.antialiasing`), and the
argument is only the starting value. Not every dial is a `run` argument: `cursor`,
`quit_on_escape`, `max_frame_rate`, `time_scale` and `time_paused` are set in `create`.

**The cursor.** `context.cursor(Cursor.CROSSHAIR)` is Processing's `cursor(CROSS)`, and
`Cursor.HIDDEN` its `noCursor()`; any other value shows the cursor again. Each `Cursor` is the
platform's own system cursor: `ARROW` (the default), `CROSSHAIR`, `HAND`, `TEXT`, `WAIT`,
`PROGRESS`, `MOVE`, `NOT_ALLOWED`, and four resize ones, `RESIZE_HORIZONTAL`, `RESIZE_VERTICAL`
and the diagonals named by slope, `RESIZE_DIAGONAL_RISING` (`/`) and `RESIZE_DIAGONAL_FALLING`.
A cursor is sent to the window only when it changes, so setting it every frame from a hover test
is free. Image cursors are not supported.

## When a change applies

A frame-wide setting applies to the frame it is set in: the canvas ones (see
[Drawing](drawing.md#settings-that-outlive-the-frame)), and `title`, `resizable`, `cursor`, `lock_mouse` and
`text_input`, which the windowed loops send before presenting.

What decides the frame's geometry waits for the next frame: `design_size`, `autoscale` and
`window_mode`, which is switched after presenting (some compositors report the new size a frame
later). A getter reports the value as set. So do `time_scale` and `time_paused`: the frame being
drawn keeps the `delta` it was given, and the next frame's clock tick reads them.

`max_frame_rate()`, `quit()` and `rumble()` are read after the frame body returns. Headless runs
ignore the window dials, like `rumble`.
