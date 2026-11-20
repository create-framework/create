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

## Special methods

### `__enter__`

```mojo
def __enter__(self) -> Self
```

### `__exit__`

```mojo
def __exit__(self) raises
```
