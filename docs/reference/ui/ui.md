# UI

```mojo
struct UI
```

The state of a program's widgets, kept from frame to frame under each widget's ID.

Keep one as a field, and open a layer on it every frame to draw widgets
with:

```mojo
# In `update`, with a `ui: UI` field:
with self.ui.screen(context, canvas) as ui:
    ui.draw(Circle((0, 0), 20), Style(fill=Color.ORANGE))
```

Implements `Deinitable`, `Movable`.

## Constructors

```mojo
@staticmethod
def __init__(
    out self,
    theme: Theme = Theme.light(primary=Optional(None), on_primary=Optional(None), secondary=Optional(None), on_secondary=Optional(None), tertiary=Optional(None), on_tertiary=Optional(None), error=Optional(None), on_error=Optional(None), surface=Optional(None), on_surface=Optional(None)),
)
```

A UI drawn in `theme`, the light theme unless given.

## Methods

### `theme`

```mojo
def theme(self) -> Theme
```

The theme the widgets are drawn in.

```mojo
def theme(mut self, theme: Theme)
```

Draw the widgets in `theme` from now on.

### `screen`

```mojo
def screen(
    mut self,
    mut context: Context,
    mut canvas: Canvas,
) -> UILayer[origin_of(self), origin_of(context), origin_of(canvas)]
```

Open a layer drawn in screen space, on top of everything drawn before its block ends, whatever the camera and transform.

```mojo
# In `update`, with a `ui: UI` field:
with self.ui.screen(context, canvas) as ui:
    ...
```
