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

## Special methods

### `__enter__`

```mojo
def __enter__(self) -> Self
```

### `__exit__`

```mojo
def __exit__(self) raises
```
