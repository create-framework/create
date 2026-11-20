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
    *,
    player: Optional[Int] = None,
)
```

A UI drawn in `theme`, the light theme unless given. Any gamepad moves its focus unless `player` names one, as each player's menu in a split-screen game would.

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

### `wants_keyboard`

```mojo
def wants_keyboard(self) -> Bool
```

Whether the keyboard is the UI's this frame. It is while a widget that takes typing has focus, and while a widget has focus from the keyboard, Tab say, rather than from a click or a gamepad, since the keys then act on it: Enter and Space press a button, the arrows move a slider. It is also in the frame a key moved or took away focus, such as Escape leaving a text field. A game checks it before reading keys itself, so typing a name with W in it doesn't move the player.

```mojo
# In `update`, before or after the UI's `with` block:
if context.keyboard.pressed(Key.ESCAPE) and not self.ui.wants_keyboard():
    context.quit()
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
