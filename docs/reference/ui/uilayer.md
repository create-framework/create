# UILayer

```mojo
struct UILayer[ui_origin: MutOrigin, context_origin: MutOrigin, canvas_origin: MutOrigin]
```

The handle a `with self.ui.screen(context, canvas) as ui:` block gets: every widget is a method on it.

It points at the `UI`, the context and the canvas, so a widget needs none
of them passed, and the block can still use them, and the program's other
fields, directly. A helper takes it as `ui: UILayer`, its parameters left
to be inferred. Everything drawn through it is drawn when the block ends,
in the order it was called.

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
    style: ButtonStyle = ButtonStyle(container_color=Optional(None), content_color=Optional(None), outline_color=Optional(None), outline_thickness=_OptionalFloat64(None), corner_radius=_OptionalFloat64(None), text_style=Optional(None)),
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
    style: SliderStyle = SliderStyle(active_track_color=Optional(None), inactive_track_color=Optional(None), handle_color=Optional(None), handle_outline_color=Optional(None), handle_shadow=False, track_thickness=_OptionalFloat64(None), handle_radius=_OptionalFloat64(None)),
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
    style: CheckboxStyle = CheckboxStyle(box_color=Optional(None), check_color=Optional(None), outline_color=Optional(None), label_color=Optional(None), text_style=Optional(None)),
    id: _WidgetKey = None,
) raises -> Bool
```

A box against the left edge of `rect`, ticked while `checked` is `True`, with `label` beside it. A click anywhere in `rect` switches `checked`. Returns whether it changed `checked` this frame.

```mojo
# In `update`, inside `with self.ui.screen(context, canvas) as ui:`:
if ui.checkbox("Sound", self.sound_on, Rectangle((0, 0), 200, 32)):
    self.save_settings()
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
