# Mouse

`context.mouse` tells a program where the pointer is, how it moved, which buttons are held and how
far the wheel turned. This page explains each of those, how to find what is under the pointer and
how to change the pointer's look. What every device has in common (`down`, `pressed` and `released`)
is in [Input](input.md#down-pressed-and-released).

## Buttons

`context.mouse.down()`, `pressed()` and `released()` ask about the left button unless you name
another: `MouseButton.RIGHT`, `MIDDLE` (pressing the wheel in), or `BACK` and `FORWARD`, the side
buttons some mice have.

```mojo
# In `update`:
if context.mouse.pressed():  # the left button went down this frame
    self.selected = self.hovered
if context.mouse.down(MouseButton.RIGHT):  # the right button is held
    self.camera.position = self.camera.position - context.mouse.movement
```

`context.mouse.button` is the most recently pressed button, or `MouseButton.NONE` before any.

## Position and movement

`context.mouse` holds:

- `position`: where the pointer is, as a `Point2D`.
- `press_position`: where the most recent press happened, also a `Point2D`. It is handy for
  dragging, where what matters is how far the pointer has moved since the button went down.
- `movement`: how far the pointer moved this frame, as a `Vector2D`, with y increasing upwards like
  everything else.
- `wheel`: how far the wheel scrolled this frame, as a `Vector2D`. Most wheels only scroll up and
  down, in `wheel.y`; touchpads and tilting wheels also scroll sideways, in `wheel.x`.

The positions are in screen space, in the same units as everything else, measured from the centre of
the screen with y increasing upwards (see [Coordinates](../basics/coordinates.md)), and they don't
move with the camera.

## What is under the pointer

`context.mouse.position` is in screen space, but what you draw may be moved by a camera or a
transform. To find what is under the pointer, turn its position into the space the thing was drawn
in:

- `camera.to_world(context.mouse.position)` is the point in the world under the pointer, when a
  `Camera` is set.
- `canvas.to_local(context.mouse.position)`, called inside a `canvas.transform` block, is the point
  in that block's own coordinates, with the camera and the transform both taken into account.

Then ask the shape whether it holds the point, with `contains`:

```mojo
# In `update`, with a `camera: Camera` field and a `button: Rectangle` in the world:
var pointer = self.camera.to_world(context.mouse.position)
if self.button.contains(pointer) and context.mouse.pressed():
    self.start_game()
```

How the spaces relate is explained in
[Coordinates](../basics/coordinates.md#screen-world-and-local-space).

## Locking the mouse

At the edge of the screen, `position` has to stop, but `movement` keeps counting.
`context.lock_mouse(True)` puts this to use for a first-person camera: it hides the pointer and
holds it inside the window, so the player can keep turning in one direction for as long as they
like, with `movement` saying how far. Unlock it with `context.lock_mouse(False)` when a menu needs
the pointer back.

## The cursor

`context.cursor(...)` sets how the pointer looks, like Processing's `cursor()`. Each `Cursor` is the
system's own cursor for that purpose, so it looks right on every platform:

| Cursor | Use |
|---|---|
| `ARROW` | The usual pointer (the default) |
| `CROSSHAIR` | Precise picking, such as a colour picker or a drawing tool |
| `HAND` | Something that can be clicked, such as a link or a button |
| `TEXT` | Text that can be selected or typed into |
| `WAIT`, `PROGRESS` | Busy, or busy but still usable |
| `MOVE` | Something that can be dragged in any direction |
| `NOT_ALLOWED` | Something that can't be used right now |
| `RESIZE_HORIZONTAL`, `RESIZE_VERTICAL` | Resizing sideways, or up and down |
| `RESIZE_DIAGONAL_RISING`, `RESIZE_DIAGONAL_FALLING` | Resizing diagonally: rising like `/`, falling like `\` |
| `HIDDEN` | No pointer at all, like Processing's `noCursor()` |

Setting any cursor other than `HIDDEN` shows the pointer again. The cursor is only sent to the
window when it changes, so it costs nothing to set it every frame from a hover test:

```mojo
# In `update`:
context.cursor(Cursor.HAND if self.button.contains(pointer) else Cursor.ARROW)
```

Cursors made from an image are not supported.
