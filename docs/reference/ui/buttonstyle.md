# ButtonStyle

```mojo
struct ButtonStyle
```

How one button looks, where it differs from its variant. Every field left unset is worked out from the theme when the button is drawn.

```mojo
# In `update`, inside `with self.ui.screen(context, canvas) as ui:`:
var square = ButtonStyle(corner_radius=4)
if ui.button("Stop", Rectangle((0, 0), 120, 40), style=square):
    ...
```

Implements `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `Writable`.

## Fields

- `container_color: Optional[Color]`: The fill behind the text.
- `content_color: Optional[Color]`: The text's colour, which the hovered and pressed states tint the button with too.
- `outline_color: Optional[Color]`: The border's colour; a border is drawn when this or `outline_thickness` is given, or for an `OUTLINED` button.
- `outline_thickness: Optional[Float64]`
- `corner_radius: Optional[Float64]`: Half the height unless given, so the ends are round.
- `text_style: Optional[TypeStyle]`: The theme's `label` text unless given.
- `focus_ring: Optional[FocusRing]`: The ring shown while it has focus from the keyboard: the theme's unless given.

## Constructors

```mojo
@staticmethod
def __init__(
    out self,
    *,
    container_color: Optional[Color] = None,
    content_color: Optional[Color] = None,
    outline_color: Optional[Color] = None,
    outline_thickness: _OptionalFloat64 = None,
    corner_radius: _OptionalFloat64 = None,
    text_style: Optional[TypeStyle] = None,
    focus_ring: Optional[FocusRing] = None,
)
```
