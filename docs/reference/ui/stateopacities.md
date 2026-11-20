# StateOpacities

```mojo
struct StateOpacities
```

How strongly a widget shows its state. A hovered, focused, pressed or dragged widget draws its content colour over itself at that opacity; a disabled one draws its content and its fill at the `disabled_` ones.

Implements `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `Writable`.

## Fields

- `hovered: Float64`
- `focused: Float64`
- `pressed: Float64`
- `dragged: Float64`
- `disabled_content: Float64`
- `disabled_container: Float64`

## Constructors

```mojo
@staticmethod
def __init__(out self)
```
