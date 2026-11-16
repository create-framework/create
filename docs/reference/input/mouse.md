# Mouse

```mojo
struct Mouse
```

The mouse's state for one frame, read as `context.mouse`.

Buttons follow the vocabulary every device shares: *down* is held right
now, *pressed*/*released* are the edges, true only in the frame the
button went down or came up. Each takes `MouseButton.LEFT` unless told
otherwise, so `context.mouse.pressed()` is a click.

`position` is in screen coordinates — origin at the centre, y up, so
negative left of and below it — and camera-independent, since the loop
reads a frame's events before the `Canvas` (and any `Camera` it sets)
exists. Convert with `camera.to_world`, or `canvas.to_local` for the
frame a shape is drawn in. `position` and `press_position` are
`Point2D`s because they are locations; `wheel` is a `Vector2D` because
a scroll is a displacement.

It is the loop's own `Mouse`, not a copy: held buttons persist in it
from frame to frame, and only the edges and the wheel clear. So read it
and don't write it.

Implements `Copyable`, `Deinitable`, `Movable`, `Writable`.

## Fields

- `position: Point2D`: Where the pointer is, in screen space.
- `button: MouseButton`: The most recent button pressed (`MouseButton.NONE` before any). Kept until the next press.
- `movement: Vector2D`: How far the pointer moved this frame, in screen units, y up: zero on a frame it stayed still. It keeps counting where `position` stops — at the screen's edge, and while `context.lock_mouse(True)` holds the pointer — so it is what a first-person camera or an endless drag turns by.
- `wheel: Vector2D`: This frame's scroll, zero on a frame without any.
- `press_position: Point2D`: Where the most recent press happened, in screen space. Captured from the press itself, so a move later in the same frame doesn't overwrite where a click started, and kept until the next press, so a drag is `position - press_position` for as long as the button is down.

## Constructors

```mojo
@staticmethod
def __init__(out self)
```

## Methods

### `down`

```mojo
def down(self, button: MouseButton = MouseButton.LEFT) -> Bool
```

Whether `button` is held right now.

### `pressed`

```mojo
def pressed(self, button: MouseButton = MouseButton.LEFT) -> Bool
```

Whether `button` went down this frame: true once per click. `press_position` is where it happened.

### `released`

```mojo
def released(self, button: MouseButton = MouseButton.LEFT) -> Bool
```

Whether `button` came up this frame: true once.
