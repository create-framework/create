# PanelStyle

```mojo
struct PanelStyle
```

How one panel looks, where it differs from the theme. Every field left unset is worked out from the theme when the panel is drawn.

Implements `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `Writable`.

## Fields

- `color: Optional[Color]`: The panel's surface: `surface_container`.
- `content_color: Optional[Color]`: The colour of text on it: the `on_` partner of `color` when it is one of the scheme's roles, otherwise black or white, whichever reads better.
- `outline_color: Optional[Color]`: A border, none unless given.
- `outline_thickness: Optional[Float64]`: 1 unless given, when there is a border.
- `corner_radius: Optional[Float64]`: The theme's large corner radius unless given.
- `shadow: Bool`: Whether it casts a soft shadow, lifting it off what is beneath.

## Constructors

```mojo
@staticmethod
def __init__(
    out self,
    *,
    color: Optional[Color] = None,
    content_color: Optional[Color] = None,
    outline_color: Optional[Color] = None,
    outline_thickness: _OptionalFloat64 = None,
    corner_radius: _OptionalFloat64 = None,
    shadow: Bool = False,
)
```
