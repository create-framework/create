# CheckboxStyle

```mojo
struct CheckboxStyle
```

How one checkbox looks, where it differs from the theme. Every field left unset is worked out from the theme when the checkbox is drawn.

Implements `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `Writable`.

## Fields

- `box_color: Optional[Color]`: The fill of a ticked box: `primary`.
- `check_color: Optional[Color]`: The tick: `on_primary`.
- `outline_color: Optional[Color]`: The border of an empty box: `on_surface_variant`.
- `label_color: Optional[Color]`: The label's text: `on_surface`.
- `text_style: Optional[Style]`: The theme's `body` text unless given.
- `focus_ring: Optional[FocusRing]`: The ring shown while it has focus from the keyboard: the theme's unless given.

## Constructors

```mojo
@staticmethod
def __init__(
    out self,
    *,
    box_color: Optional[Color] = None,
    check_color: Optional[Color] = None,
    outline_color: Optional[Color] = None,
    label_color: Optional[Color] = None,
    text_style: Optional[Style] = None,
    focus_ring: Optional[FocusRing] = None,
)
```
