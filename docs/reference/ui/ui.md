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
def __init__(out self)
```

## Methods

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
