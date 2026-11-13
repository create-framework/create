# Input

The keyboard, the mouse and the gamepads are devices on the `Context`: `context.keyboard`,
`context.mouse` and `context.gamepad(player)`. The loop fills them in before each `update`, and a
program reads them there; there are no event callbacks.

## Down, pressed and released

Every device answers the same three questions about a key or button:

- **`down(button)`**: is it held right now? True every frame it is held.
- **`pressed(button)`**: did it go down this frame? True only in that frame.
- **`released(button)`**: did it come up this frame? True only in that frame.

```mojo
from create import *


@fieldwise_init
struct Mover(Program):
    var position: Point2D
    var size: Float64

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> Mover:
        return Mover((0, 0), 40)

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        canvas.background(Color.WHITE)
        var step = 200 * context.time.delta
        if context.keyboard.down(Key.RIGHT):  # held: moves every frame
            self.position = self.position + Vector2D(step, 0)
        if context.keyboard.down(Key.LEFT):
            self.position = self.position - Vector2D(step, 0)
        if context.keyboard.pressed(Key.SPACE):  # an edge: once per press
            self.size = 80 if self.size == 40 else 40
        if context.mouse.pressed():  # the left button by default
            self.position = context.mouse.position
        canvas.fill(Color.PURPLE)
        canvas.rectangle(self.position, self.size, self.size)


def main() raises:
    run[Mover]("Mover")
```

- The mouse's methods default to `MouseButton.LEFT`.
- Unlike Processing's `mousePressed`, *pressed* never means held.
- When the window loses focus, everything held is released, each with its *released* edge, since
  what is let go while it is away is never reported to it. A disconnecting pad releases its
  buttons the same way.
- The most recent press is `keyboard.key`, `mouse.button` and `pad.button`, each
  `Key.NONE`/`MouseButton.NONE`/`GamepadButton.NONE` before any. Like every enum they are typed,
  so a bare number never passes for a key, a button or a `FontWeight`.

## The keyboard

A `Key` names a key **by position**, not by label: each constant names where a key sits on a US
layout, so `Key.W` is the key above `S` (AZERTY's Z), and WASD lands under the same fingers on
every layout. Characters never come from a `Key`; they are `context.keyboard.text` (below).

- `CTRL`, `SHIFT`, `ALT` and `SUPER` match either side.
- `Key.from_name` reads a binding from a file (`"page_up"`, `"a"`, `"/"`), as do
  `MouseButton.from_name`, `GamepadButton.from_name` and `Cursor.from_name`, each by its
  constants' names, case folded.

## Typing text

Text entry has its own two readings, both reset every frame:

- **`context.keyboard.text`** is this frame's typed characters, UTF-8, with shift, layout and IME
  applied. Append it; don't rebuild it from keys.
- **`keyboard.typed(key)`** is true when a key is pressed or auto-repeated while held, for editing
  keys (Backspace, the arrows).

Taking text is on by default, and it also opens an IME's composition window and a handheld's
on-screen keyboard. So a game played on letter keys switches it off with
`context.text_input(False)` (keys read the same; only `text` goes quiet), and on again while a
text field is in use.

**`EditableText`** does the editing for a text field:

```mojo
# A fragment: `name` is an `EditableText` field.
self.name.update(context)
canvas.text(self.name.text, (0, 0))
var caret_x = canvas.text_width(self.name.before_caret())
```

- `field.update(context)` each frame replays the frame's typing in the order it came (so text and
  keys typed within one frame land where they were typed), and keeps `text`, a caret and a
  selection, whole characters at a time.
- Shift extends the selection, and a word modifier (Option on macOS, Ctrl elsewhere) moves and
  deletes by words.
- The command shortcuts (Cmd on macOS, Ctrl elsewhere; by the key's label, not its position)
  select all, copy, cut and paste, through `context.clipboard()`/`context.clipboard(text)`, the
  system clipboard.
- `max_length=` caps what typing and pasting add.
- `canvas.text_width(field.before_caret())` places the caret, and `before_selection()` and
  `selected_text()` the selection's highlight.

`EditableText` lives in `core`, beside the `Context` it reads. See
[examples/typing](../examples/typing/main.mojo).

## The mouse

`context.mouse` holds:

- `position` and `press_position`, `Point2D`s in screen space (see
  [Coordinates](coordinates.md#screen-world-and-local-space)).
- `wheel`, this frame's scroll, added up.
- `movement`, how far the pointer moved this frame, y up, in screen units.

`movement` keeps counting where `position` stops: at the screen's edge, and while
`context.lock_mouse(True)` hides the pointer and holds it in the window, for a first-person
camera. Unlock it for a menu. `context.cursor(...)` sets the pointer's look (see
[Coordinates](coordinates.md#the-runs-settings)).

## Gamepads

`context.gamepad(i)` is a copy of player `i`'s pad (default 0):

```mojo
# A fragment of an `update`.
var pad = context.gamepad()
self.position = self.position + pad.left_stick * 300 * context.time.delta
if pad.pressed(GamepadButton.SOUTH):  # Xbox A, PlayStation Cross
    context.rumble(0.2)
```

- A pad takes the lowest free slot as it connects and keeps it until it disconnects. An empty slot
  reads `connected` False and all zero, so no check is needed first.
- Sticks (`left_stick`, `right_stick`) are `Vector2D`s, **y up**, inside the unit circle, with a
  rescaled radial dead zone (`Gamepad.STICK_DEAD_ZONE`, 0.2) so a resting stick reads exactly
  zero. Triggers (`left_trigger`, `right_trigger`) run from 0 to 1.
- Face buttons are positional: `GamepadButton.SOUTH` is Xbox A and PlayStation Cross.
- Each trigger is also a button, `GamepadButton.LEFT_TRIGGER`/`RIGHT_TRIGGER`, down from
  `Gamepad.TRIGGER_PRESS` (0.5) and up again below `TRIGGER_RELEASE` (0.4), so
  `pad.pressed(GamepadButton.RIGHT_TRIGGER)` fires once per pull.
- `connected_this_frame` and `disconnected_this_frame` are the edges of `connected`, and `name`
  survives the frame a pad leaves in.
- `context.rumble(seconds, low_frequency=, high_frequency=, player=)` shakes a pad (both motors
  full by default; a new rumble replaces the running one). It is an output, so it lives on
  `Context`, not on the `Gamepad` copy.

See [examples/gamepad](../examples/gamepad/main.mojo).
