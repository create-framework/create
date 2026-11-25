# WindowMode

```mojo
struct WindowMode
```

How the window presents itself: `run`'s `mode`, and `context.window_mode`'s value.

`WINDOWED` is the default. Compare modes with `==`.

Implements `Copyable`, `Deinitable`, `Equatable`, `ImplicitlyCopyable`, `Movable`, `Writable`.

## Constants

- `WINDOWED = WindowMode(Int(0))`: An ordinary decorated window of the design size.
- `FULLSCREEN = WindowMode(Int(1))`: The whole display, with the design scaled onto it.
- `BORDERLESS = WindowMode(Int(2))`: A window of the design size with no title bar or border.
- `MAXIMIZED = WindowMode(Int(3))`: A decorated window filling the display's work area, with the design scaled onto it.

## Fields

- `value: Int`

## Constructors

```mojo
@staticmethod
def __init__(out self, value: Int)
```

## Special methods

### `__eq__`

```mojo
def __eq__(self, other: Self) -> Bool
```

### `__ne__`

```mojo
def __ne__(self, other: Self) -> Bool
```
