# FocusRing

```mojo
struct FocusRing
```

The ring drawn around a widget focused from the keyboard, a gamepad or `ui.focus`: its `thickness`, the `gap` between it and the widget, and its `color`, the scheme's `primary` unless given. It follows the widget's shape, its corners rounded by the widget's own radius grown by the gap.

Implements `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `Writable`.

## Fields

- `thickness: Float64`
- `gap: Float64`
- `color: Optional[Color]`

## Constructors

```mojo
@staticmethod
def __init__(out self)
```
