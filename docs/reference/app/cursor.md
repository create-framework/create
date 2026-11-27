# Cursor

```mojo
struct Cursor
```

The mouse cursor over the window: `context.cursor`'s value.

Each is the platform's own system cursor, so it looks native on every
desktop. `ARROW` is the default. `HIDDEN` hides the cursor over the
window, like Processing's `noCursor()`; any other value shows it again.
The resize cursors are named by the line they run along, read left to
right with y up: `RESIZE_DIAGONAL_RISING` is `/`,
`RESIZE_DIAGONAL_FALLING` is `\`.

Implements `Copyable`, `Deinitable`, `Equatable`, `ImplicitlyCopyable`, `Movable`, `Writable`.

## Constants

- `ARROW = Cursor(Int(0))`: The ordinary pointer.
- `CROSSHAIR = Cursor(Int(1))`: Precise aiming or drawing: Processing's `CROSS`.
- `HAND = Cursor(Int(2))`: Something clickable, like a link.
- `TEXT = Cursor(Int(3))`: Text that can be edited or selected: an I-beam.
- `WAIT = Cursor(Int(4))`: Busy, not taking input.
- `PROGRESS = Cursor(Int(5))`: Busy, but still taking input: usually an arrow with a spinner.
- `MOVE = Cursor(Int(6))`: Something that can be dragged in any direction.
- `NOT_ALLOWED = Cursor(Int(7))`: An action that can't be done here.
- `RESIZE_HORIZONTAL = Cursor(Int(8))`
- `RESIZE_VERTICAL = Cursor(Int(9))`
- `RESIZE_DIAGONAL_RISING = Cursor(Int(10))`
- `RESIZE_DIAGONAL_FALLING = Cursor(Int(11))`
- `HIDDEN = Cursor(Int(12))`: No cursor over the window: Processing's `noCursor()`.

## Fields

- `value: Int`

## Constructors

```mojo
@staticmethod
def __init__(out self, value: Int)
```

## Methods

### `from_name`

```mojo
@staticmethod
def from_name(name: String) -> Optional[Self]
```

The cursor whose constant is `name`, case folded: `"hand"`, `"crosshair"`, `"hidden"`. `None` for an unknown name: for a binding read from a file, where a misspelled constant would have failed to compile.

## Special methods

### `__eq__`

```mojo
def __eq__(self, other: Self) -> Bool
```

### `__ne__`

```mojo
def __ne__(self, other: Self) -> Bool
```
