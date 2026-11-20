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

### `wants_mouse`

```mojo
def wants_mouse(self) -> Bool
```

Whether the mouse is the UI's this frame: the pointer is over a widget, or a widget is held. A game checks it before using the mouse itself, so a click on a button doesn't also fire a weapon.

```mojo
# In `update`, before or after the UI's `with` block:
if context.mouse.pressed() and not self.ui.wants_mouse():
    self.fire()
```

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

### `world`

```mojo
def world(
    mut self,
    mut context: Context,
    mut canvas: Canvas,
) -> UILayer[origin_of(self), origin_of(context), origin_of(canvas)]
```

Open a layer drawn in the space that is current when the block opens, the camera and any transform included: for a button above a chest, a health bar over an enemy, or a label that turns with a ship.

Its widgets move and zoom with the camera, and the pointer is taken
into the same space to find what is under it. They are drawn when the
block ends, beneath whatever is drawn after it, so where the block
sits decides what covers what.

```mojo
# In `update`, with `ui: UI`, `camera: Camera` and `chest: Point`
# fields:
canvas.camera(self.camera)
with self.ui.world(context, canvas) as ui:
    if ui.button("Open", Rectangle(self.chest + Vector(0, 40), 80, 32)):
        self.open_chest()
```
