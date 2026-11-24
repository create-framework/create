# StateLayers

```mojo
struct StateLayers
```

How strongly a widget shows its state.

A hovered, pressed or dragged widget moves its OKLCH lightness
by that step towards its text colour: 0.09 is a clear but quiet change,
and the same step looks like the same change on any colour. A disabled
widget instead fades, its content to `disabled_content` of its opacity
and its fill to `disabled_container`. Focus has no step: it shows as
the `FocusRing`.

Implements `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `Writable`.

## Fields

- `hovered: Float64`
- `pressed: Float64`
- `dragged: Float64`
- `disabled_content: Float64`
- `disabled_container: Float64`

## Constructors

```mojo
@staticmethod
def __init__(out self)
```
