# MouseButton

```mojo
struct MouseButton
```

A mouse button, for `Mouse.down`/`pressed`/`released`.

Matches SDL's own button numbering, not named after it: `BACK`/`FORWARD`
are the side thumb buttons (SDL's X1/X2), named for what a mouse driver
or browser calls them, not SDL's internal label, since nobody looks at
their mouse and thinks "that's my X1 button."

A wrapped button number rather than a bare `Int`, like `Key`, so a stray
number cannot be passed where a button is expected: the numbering is not
what anyone guesses (`RIGHT` is 3, not 2). `MouseButton(n)` names a
button past `FORWARD` on a mouse that has one.

`NONE` is no button, what `Mouse.button` reads before any press;
it is never down.

Implements `Copyable`, `Deinitable`, `Equatable`, `ImplicitlyCopyable`, `Movable`, `Writable`.

## Constants

- `NONE = MouseButton(Int(0))`
- `LEFT = MouseButton(Int(1))`
- `MIDDLE = MouseButton(Int(2))`
- `RIGHT = MouseButton(Int(3))`
- `BACK = MouseButton(Int(4))`
- `FORWARD = MouseButton(Int(5))`

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

The button whose constant is `name`, case folded: `"left"`, `"right"`, `"back"`. `None` for an unknown name: for a binding read from a file, where a misspelled constant would have failed to compile.

## Special methods

### `__eq__`

```mojo
def __eq__(self, other: Self) -> Bool
```

### `__ne__`

```mojo
def __ne__(self, other: Self) -> Bool
```
