# TextFieldStyle

```mojo
struct TextFieldStyle
```

How one text field looks, where it differs from the theme. Every field left unset is worked out from the theme when the text field is drawn.

A field drawn by the program itself keeps only what it wants: with
`container_color=Color.TRANSPARENT` and `outline_thickness=0` it draws
nothing but the text, caret and selection.

Implements `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `Writable`.

## Fields

- `container_color: Optional[Color]`: The fill behind the text: `surface_container_highest`.
- `outline_color: Optional[Color]`: The border while unfocused: `outline`.
- `focused_outline_color: Optional[Color]`: The border while focused: `primary`, and twice as thick.
- `outline_thickness: Optional[Float64]`: 1 unless given; 0 for no border.
- `text_color: Optional[Color]`: The typed text: `on_surface`.
- `placeholder_color: Optional[Color]`: The placeholder, shown while the field is empty: `on_surface_variant`.
- `caret_color: Optional[Color]`: The caret: `primary`.
- `selection_color: Optional[Color]`: The highlight behind selected text: `primary`, faded.
- `corner_radius: Optional[Float64]`: The theme's small corner radius unless given.
- `padding: Optional[Float64]`: The gap between the field's edges and its text: 12 unless given.
- `text_style: Optional[Style]`: The theme's `body` text unless given.

## Constructors

```mojo
@staticmethod
def __init__(
    out self,
    *,
    container_color: Optional[Color] = None,
    outline_color: Optional[Color] = None,
    focused_outline_color: Optional[Color] = None,
    outline_thickness: _OptionalFloat64 = None,
    text_color: Optional[Color] = None,
    placeholder_color: Optional[Color] = None,
    caret_color: Optional[Color] = None,
    selection_color: Optional[Color] = None,
    corner_radius: _OptionalFloat64 = None,
    padding: _OptionalFloat64 = None,
    text_style: Optional[Style] = None,
)
```
