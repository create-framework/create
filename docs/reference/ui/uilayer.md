# UILayer

```mojo
struct UILayer[ui_origin: MutOrigin, context_origin: MutOrigin, canvas_origin: MutOrigin]
```

The handle a `with self.ui.screen(context, canvas) as ui:` or `ui.world` block gets: every widget is a method on it.

It points at the `UI`, the context and the canvas, so a widget needs none
of them passed, and the block can still use them, and the program's other
fields, directly. A helper takes it as `ui: UILayer`, its parameters left
to be inferred. Everything drawn through it is drawn when the block ends,
in the order it was called.

Every widget that reacts to the pointer takes the same three keywords:

- `take_focus=True` gives it focus in the frame it is passed, as a click
  would; if several widgets ask in one frame, the last one called gets
  it.
- `disabled=True` draws it faded and stops it reacting, as a
  `ui.disabled` block around it would.
- `id=` adds a key to its ID, as a `ui.id` block around it would.

Implements `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`.

## Methods

### `draw`

```mojo
def draw[D: Drawable](self, shape: D, style: Style) raises
```

Draw `shape` in `style`, in order with the layer's widgets: above what was drawn through the layer before it, and below what comes after. A plain `canvas` call inside the block draws at once, beneath the whole layer.

```mojo
# In `update`, inside `with self.ui.screen(context, canvas) as ui:`:
ui.draw(Circle((0, 0), 20), Style(fill=Color.ORANGE))
```

### `theme`

```mojo
def theme(self) -> Theme
```

The theme the widgets are drawn in, for a program's own widget to match them.

```mojo
def theme(self, theme: Theme) raises -> ThemeGuard[ui_origin]
```

Draw the widgets inside a `with` block in `theme`, such as one panel in the dark theme on a light screen.

```mojo
# In `update`, inside `with self.ui.screen(context, canvas) as ui:`:
with ui.theme(Theme.dark()):
    if ui.button("Night mode", Rectangle((0, 0), 160, 48)):
        ...
```

### `style`

```mojo
def style(
    self,
    *,
    button: ButtonStyle = ButtonStyle(container_color=Optional(None), content_color=Optional(None), outline_color=Optional(None), outline_thickness=_OptionalFloat64(None), corner_radius=_OptionalFloat64(None), text_style=Optional(None), focus_ring=Optional(None)),
    label: LabelStyle = LabelStyle(color=Optional(None), text_style=Optional(None)),
    slider: SliderStyle = SliderStyle(active_track_color=Optional(None), inactive_track_color=Optional(None), handle_color=Optional(None), handle_outline_color=Optional(None), handle_shadow=False, track_thickness=_OptionalFloat64(None), handle_radius=_OptionalFloat64(None), focus_ring=Optional(None)),
    checkbox: CheckboxStyle = CheckboxStyle(box_color=Optional(None), check_color=Optional(None), outline_color=Optional(None), label_color=Optional(None), text_style=Optional(None), focus_ring=Optional(None)),
    text_field: TextFieldStyle = TextFieldStyle(container_color=Optional(None), outline_color=Optional(None), focused_outline_color=Optional(None), outline_thickness=_OptionalFloat64(None), text_color=Optional(None), placeholder_color=Optional(None), caret_color=Optional(None), selection_color=Optional(None), corner_radius=_OptionalFloat64(None), padding=_OptionalFloat64(None), text_style=Optional(None)),
) raises -> WidgetStyleGuard[ui_origin]
```

Style every widget of a kind inside a `with` block. The styles given sit under each call's own style and over any block outside this one, field by field: a field a call sets wins, and a field nothing sets comes from the theme.

```mojo
# In `update`, inside `with self.ui.screen(context, canvas) as ui:`:
with ui.style(button=ButtonStyle(corner_radius=4)):
    _ = ui.button("Square", Rectangle((0, 0), 120, 40))
    _ = ui.button("Round", Rectangle((0, -50), 120, 40),
                  style=ButtonStyle(corner_radius=20))
```

### `content_color`

```mojo
def content_color(self) -> Color
```

The colour for text here: the innermost panel's content colour, or the theme's `on_surface`. A program's own widget draws its text in it to match the built-in ones.

### `panel`

```mojo
def panel(
    self,
    rect: Rectangle,
    *,
    style: PanelStyle = PanelStyle(color=Optional(None), content_color=Optional(None), outline_color=Optional(None), outline_thickness=_OptionalFloat64(None), corner_radius=_OptionalFloat64(None), shadow=False),
    id: _WidgetKey = None,
) raises -> PanelGuard[ui_origin]
```

A surface filling `rect`, drawn beneath everything called inside its `with` block. Text on it takes its content colour, so a label on a dark panel turns light without being told, and it covers what is beneath it from the pointer. It doesn't place what is inside it.

```mojo
# In `update`, inside `with self.ui.screen(context, canvas) as ui:`:
with ui.panel(Rectangle((0, 0), 320, 120)):
    ui.label("Volume", Rectangle((0, 30), 280, 24))
    _ = ui.slider(self.volume, 0, 1, Rectangle((0, -15), 280, 32))
```

### `id`

```mojo
def id[K: Hashable](self, key: K) raises -> IDGuard[ui_origin]
```

Add `key` to the ID of every widget inside a `with` block, so a widget keeps its state when the items around it are reordered or removed.

```mojo
# In `update`, inside `with self.ui.screen(context, canvas) as ui:`:
for player in self.players:
    with ui.id(player.name):
        ...
```

### `button`

```mojo
def button(
    self,
    text: String,
    rect: Rectangle,
    *,
    variant: ButtonVariant = ButtonVariant.FILLED,
    style: ButtonStyle = ButtonStyle(container_color=Optional(None), content_color=Optional(None), outline_color=Optional(None), outline_thickness=_OptionalFloat64(None), corner_radius=_OptionalFloat64(None), text_style=Optional(None), focus_ring=Optional(None)),
    take_focus: Bool = False,
    disabled: Bool = False,
    id: _WidgetKey = None,
) raises -> Bool
```

A button showing `text`, filling `rect`. Returns whether it was clicked this frame: pressed and released with the pointer over it.

```mojo
# In `update`, inside `with self.ui.screen(context, canvas) as ui:`:
if ui.button("Play", Rectangle((0, 0), 160, 48)):
    self.start()
```

### `label`

```mojo
def label(
    self,
    text: String,
    rect: Rectangle,
    *,
    alignment: Align = Align.CENTER,
    style: LabelStyle = LabelStyle(color=Optional(None), text_style=Optional(None)),
) raises
```

Text placed in `rect`, by `alignment`: in its centre unless given, against its left edge with `Align.LEFT`, and so on. It reacts to nothing, so the pointer passes through it to what is beneath.

```mojo
# In `update`, inside `with self.ui.screen(context, canvas) as ui:`:
ui.label("Volume", Rectangle((0, 40), 240, 24), alignment=Align.LEFT)
```

### `image`

```mojo
def image(self, image: Image, rect: Rectangle) raises
```

`image` stretched to fill `rect`. Like a label, it reacts to nothing.

### `slider`

```mojo
def slider(
    self,
    mut value: Float64,
    min: Float64,
    max: Float64,
    rect: Rectangle,
    *,
    step: _OptionalFloat64 = None,
    style: SliderStyle = SliderStyle(active_track_color=Optional(None), inactive_track_color=Optional(None), handle_color=Optional(None), handle_outline_color=Optional(None), handle_shadow=False, track_thickness=_OptionalFloat64(None), handle_radius=_OptionalFloat64(None), focus_ring=Optional(None)),
    take_focus: Bool = False,
    disabled: Bool = False,
    id: _WidgetKey = None,
) raises -> Bool
```

A slider across `rect` that sets `value` between `min` and `max`. Returns whether it changed `value` this frame.

Pressing anywhere in `rect` moves the handle there, and dragging
moves it on, even once the pointer leaves `rect`. `step` rounds the
value to multiples of it from `min`. A `value` outside `min` to
`max` is drawn at the nearer end, and left as it is until dragged.

```mojo
# In `update`, inside `with self.ui.screen(context, canvas) as ui:`:
if ui.slider(self.volume, 0, 1, Rectangle((0, 0), 240, 32)):
    self.audio.volume(self.volume)
```

### `checkbox`

```mojo
def checkbox(
    self,
    label: String,
    mut checked: Bool,
    rect: Rectangle,
    *,
    style: CheckboxStyle = CheckboxStyle(box_color=Optional(None), check_color=Optional(None), outline_color=Optional(None), label_color=Optional(None), text_style=Optional(None), focus_ring=Optional(None)),
    take_focus: Bool = False,
    disabled: Bool = False,
    id: _WidgetKey = None,
) raises -> Bool
```

A box against the left edge of `rect`, ticked while `checked` is `True`, with `label` beside it. A click anywhere in `rect` switches `checked`. Returns whether it changed `checked` this frame.

```mojo
# In `update`, inside `with self.ui.screen(context, canvas) as ui:`:
if ui.checkbox("Sound", self.sound_on, Rectangle((0, 0), 200, 32)):
    self.save_settings()
```

### `text_field`

```mojo
def text_field[text_origin: MutOrigin](
    self,
    ref[ui_origin] text: String,
    rect: Rectangle,
    *,
    placeholder: String = "",
    max_length: Optional[Int] = None,
    style: TextFieldStyle = TextFieldStyle(container_color=Optional(None), outline_color=Optional(None), focused_outline_color=Optional(None), outline_thickness=_OptionalFloat64(None), text_color=Optional(None), placeholder_color=Optional(None), caret_color=Optional(None), selection_color=Optional(None), corner_radius=_OptionalFloat64(None), padding=_OptionalFloat64(None), text_style=Optional(None)),
    take_focus: Bool = False,
    disabled: Bool = False,
    id: _WidgetKey = None,
) raises -> TextFieldResult[ui_origin, context_origin, text_origin]
```

A field for typing into `text`, filling `rect`. Clicking it gives it focus and places the caret; while it has focus, typing and the editing keys change `text`, and Enter submits it.

Returns a `TextFieldResult`: whether the text changed, as a `Bool`,
`submitted` for Enter, and the caret and selection. `placeholder` is
shown in a fainter colour while `text` is empty, and `max_length`
caps how many characters typing and pasting can bring it to.

```mojo
# In `update`, inside `with self.ui.screen(context, canvas) as ui:`,
# with a `name: String` field:
var field = ui.text_field(
    self.name, Rectangle((0, 0), 320, 40), placeholder="Your name"
)
if field.submitted:
    self.start_game(self.name)
```

### `disabled`

```mojo
def disabled(self, condition: Bool = True) raises -> DisabledGuard[ui_origin]
```

Disable every widget inside a `with` block while `condition` is true: they are drawn faded, don't react to the pointer, and return `False`. With `condition` false, the block's widgets work as usual, so a section can be switched on and off without an `if` around each widget.

```mojo
# In `update`, inside `with self.ui.screen(context, canvas) as ui:`:
with ui.disabled(not self.online):
    if ui.button("Find a game", Rectangle((0, 0), 200, 48)):
        ...
```

## Special methods

### `__enter__`

```mojo
def __enter__(self) -> Self
```

### `__exit__`

```mojo
def __exit__(self) raises
```
