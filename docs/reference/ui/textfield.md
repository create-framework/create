# TextField

```mojo
struct TextField
```

A field to type a line of text into.

A click gives it focus and places the caret under the pointer; while it
has focus, typing and the editing keys change its text, Enter submits
it, and a click elsewhere or Escape takes its focus away. It switches
`context.text_input` on while it has focus and off when it loses it.

```mojo
# In `create`, building the `name` field:
var name = TextField(Rectangle((0, 0), 320, 40), placeholder="Your name")

# In `update`:
self.name.update(context, canvas)
canvas.draw(self.name)
if self.name.submitted():
    self.start_game(self.name.text())
```

`text()` is what has been typed, and `set_text` replaces it. The editing
methods (`insert`, `delete_backward`, `select_all`, `copy`, `paste` and
the rest) edit it as the keys do, so a program can drive it from
buttons of its own; `changed()` reports their edits at the next
`update`, as it does typing.

Each part is drawn in a style of its own: `container` is the field, a
rectangle, and `focused_container` is layered over it while it has
focus (by default its outline turns `primary` and twice as thick);
`text_style` is the typed text and `placeholder_style` the placeholder,
which takes what it leaves unset from `text_style`; `caret` is a line,
so its stroke is the caret's colour and width; and `selection` is the
rectangle behind selected text.

Implements `Clickable`, `Copyable`, `Deinitable`, `Drawable`, `Hoverable`, `Movable`, `Widget`.

## Fields

- `rect: Rectangle`: Where it is, and how big.
- `placeholder: String`: Shown in a fainter colour while the field is empty.
- `padding: Float64`: The gap between the field's sides and its text.
- `container: Style`
- `focused_container: Style`
- `text_style: Style`
- `placeholder_style: Style`
- `caret: Style`
- `selection: Style`
- `enabled: Bool`: Whether it reacts to the mouse and keyboard. A disabled field is faded, and loses focus.

## Constructors

```mojo
@staticmethod
def __init__(
    out self,
    rect: Rectangle = Rectangle(Point(SIMD(0), SIMD(0)), SIMD(0), SIMD(0), corner_radius=_OptionalFloat64(SIMD(0)), rotation=_OptionalFloat64(SIMD(0))),
    text: String = "",
    *,
    placeholder: String = "",
    max_length: Optional[Int] = None,
    padding: _OptionalFloat64 = None,
    container: Style = Style(fill=Optional(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=Optional(None), stroke_thickness=_OptionalFloat64(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=_OptionalFloat64(None), text_color=Optional(None), font=Optional(None), font_size=_OptionalFloat64(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=Optional(None), opacity=_OptionalFloat64(None), blend_mode=Optional(None), shadow=Optional(None), shadow_offset=Optional(None), shadow_blur=_OptionalFloat64(None), shadow_spread=_OptionalFloat64(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
    focused_container: Style = Style(fill=Optional(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=Optional(None), stroke_thickness=_OptionalFloat64(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=_OptionalFloat64(None), text_color=Optional(None), font=Optional(None), font_size=_OptionalFloat64(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=Optional(None), opacity=_OptionalFloat64(None), blend_mode=Optional(None), shadow=Optional(None), shadow_offset=Optional(None), shadow_blur=_OptionalFloat64(None), shadow_spread=_OptionalFloat64(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
    text_style: Style = Style(fill=Optional(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=Optional(None), stroke_thickness=_OptionalFloat64(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=_OptionalFloat64(None), text_color=Optional(None), font=Optional(None), font_size=_OptionalFloat64(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=Optional(None), opacity=_OptionalFloat64(None), blend_mode=Optional(None), shadow=Optional(None), shadow_offset=Optional(None), shadow_blur=_OptionalFloat64(None), shadow_spread=_OptionalFloat64(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
    placeholder_style: Style = Style(fill=Optional(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=Optional(None), stroke_thickness=_OptionalFloat64(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=_OptionalFloat64(None), text_color=Optional(None), font=Optional(None), font_size=_OptionalFloat64(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=Optional(None), opacity=_OptionalFloat64(None), blend_mode=Optional(None), shadow=Optional(None), shadow_offset=Optional(None), shadow_blur=_OptionalFloat64(None), shadow_spread=_OptionalFloat64(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
    caret: Style = Style(fill=Optional(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=Optional(None), stroke_thickness=_OptionalFloat64(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=_OptionalFloat64(None), text_color=Optional(None), font=Optional(None), font_size=_OptionalFloat64(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=Optional(None), opacity=_OptionalFloat64(None), blend_mode=Optional(None), shadow=Optional(None), shadow_offset=Optional(None), shadow_blur=_OptionalFloat64(None), shadow_spread=_OptionalFloat64(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
    selection: Style = Style(fill=Optional(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=Optional(None), stroke_thickness=_OptionalFloat64(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=_OptionalFloat64(None), text_color=Optional(None), font=Optional(None), font_size=_OptionalFloat64(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=Optional(None), opacity=_OptionalFloat64(None), blend_mode=Optional(None), shadow=Optional(None), shadow_offset=Optional(None), shadow_blur=_OptionalFloat64(None), shadow_spread=_OptionalFloat64(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
    enabled: Bool = True,
)
```

## Methods

### `update`

```mojo
def update(mut self, mut context: Context, mut canvas: Canvas) raises
```

Read what the mouse and keyboard did to it this frame, taking focus on a click and typing while it has it, and work out its look: call it before drawing it.

### `text`

```mojo
def text(self) -> String
```

What has been typed.

### `set_text`

```mojo
def set_text(mut self, text: String)
```

Replace what has been typed with `text`, the caret kept inside it. Not reported by `changed()`: the program made the change.

### `max_length`

```mojo
def max_length(self) -> Optional[Int]
```

The most characters typing and pasting can bring it to; `None` for no limit.

```mojo
def max_length(mut self, length: Optional[Int])
```

### `focused`

```mojo
def focused(self) -> Bool
```

Whether it has focus, so typing reaches it.

### `focus`

```mojo
def focus(mut self, focused: Bool = True)
```

Give it focus, or take it away, as a click on it or elsewhere would. It switches `context.text_input` at its next `update`.

### `changed`

```mojo
def changed(self) -> Bool
```

Whether its text changed between its last two `update`s, by typing or through the editing methods.

### `submitted`

```mojo
def submitted(self) -> Bool
```

Whether Enter was pressed in it at its last `update`.

### `hovered`

```mojo
def hovered(self) -> Bool
```

### `pressed`

```mojo
def pressed(self) -> Bool
```

### `down`

```mojo
def down(self) -> Bool
```

### `released`

```mojo
def released(self) -> Bool
```

### `before_caret`

```mojo
def before_caret(self) -> String
```

The text left of the caret: what to measure to place it.

### `after_caret`

```mojo
def after_caret(self) -> String
```

The text right of the caret.

### `selected_text`

```mojo
def selected_text(self) -> String
```

The selected text, empty when nothing is.

### `before_selection`

```mojo
def before_selection(self) -> String
```

The text left of the selection: what to measure to place its highlight, and where typing lands. The same as `before_caret` when nothing is selected.

### `insert`

```mojo
def insert(mut self, typed: String)
```

Put `typed` in place of the selection, or at the caret.

### `delete_backward`

```mojo
def delete_backward(mut self)
```

Delete the selection, or the character left of the caret.

### `delete_forward`

```mojo
def delete_forward(mut self)
```

Delete the selection, or the character right of the caret.

### `move_left`

```mojo
def move_left(mut self, *, select: Bool = False)
```

### `move_right`

```mojo
def move_right(mut self, *, select: Bool = False)
```

### `move_word_left`

```mojo
def move_word_left(mut self, *, select: Bool = False)
```

### `move_word_right`

```mojo
def move_word_right(mut self, *, select: Bool = False)
```

### `move_to_start`

```mojo
def move_to_start(mut self, *, select: Bool = False)
```

### `move_to_end`

```mojo
def move_to_end(mut self, *, select: Bool = False)
```

### `select_all`

```mojo
def select_all(mut self)
```

### `cut`

```mojo
def cut(mut self, mut context: Context)
```

Put the selection on the clipboard and delete it.

### `paste`

```mojo
def paste(mut self, context: Context)
```

Insert the clipboard's text, as if typed.

### `draw_to`

```mojo
def draw_to(self, mut canvas: Canvas)
```
