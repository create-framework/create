# Keyboard

```mojo
struct Keyboard
```

The keyboard's state for one frame, read as `context.keyboard`.

Every device answers the same three questions about its buttons:
*down* is held right now, true every frame it stays held; *pressed* and
*released* are the edges, true only in the frame the key went down or
came up. Unlike Processing, where `keyPressed` means held, *pressed* is
only ever the edge. Keys add *typed*: pressed, or auto-repeated while
held — what an editing key like Backspace acts on.

`text` is what those keys wrote, as characters rather than keys: shift,
the keyboard layout and any IME already applied. A text field appends
`text` and handles Backspace and the arrows through `typed`, as a
`text_field` does.

It is the loop's own `Keyboard`, not a copy: held keys persist in it
from frame to frame, and only the edges and `text` clear. So read it
and don't write it.

Implements `Copyable`, `Deinitable`, `Movable`, `Writable`.

## Fields

- `key: Key`: The most recent key pressed (`Key.NONE` before any). Kept until the next press; auto-repeat of a held key does not count as one.
- `text: String`: The text typed this frame, UTF-8: empty on most frames, several characters when typing outpaces the frame rate.

## Constructors

```mojo
@staticmethod
def __init__(out self)
```

## Methods

### `down`

```mojo
def down(self, key: Key) -> Bool
```

Whether `key` is held right now: true every frame it stays down.

### `pressed`

```mojo
def pressed(self, key: Key) -> Bool
```

Whether `key` went down this frame: true once per press.

### `released`

```mojo
def released(self, key: Key) -> Bool
```

Whether `key` came up this frame: true once per release.

### `typed`

```mojo
def typed(self, key: Key) -> Bool
```

Whether `key` went down or auto-repeated this frame: true once per press, then at the system's repeat rate while held.
