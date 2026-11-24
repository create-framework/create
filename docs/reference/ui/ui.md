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
def __init__(out self, *, player: Optional[Int] = None)
```

A UI whose focus any gamepad moves, unless `player` names one, as each player's menu in a split-screen game would.

## Methods

### `corner_radius`

```mojo
def corner_radius(self) -> Float64
```

How round the widgets' corners are: a panel's radius, 16 unless set. Smaller parts are rounded in proportion: a text field's by a quarter of it, a checkbox's box by an eighth.

```mojo
def corner_radius(mut self, radius: Float64)
```

Round the widgets' corners by `radius` from now on; 0 squares them.

### `spacing`

```mojo
def spacing(self) -> Float64
```

The gap between the widgets in a `ui.column` or `ui.row`, 8 unless set. A panel is inset by twice it, and `ui.space()` leaves twice it empty.

```mojo
def spacing(mut self, spacing: Float64)
```

Space the widgets by `spacing` from now on.

### `control_height`

```mojo
def control_height(self) -> Float64
```

How tall a button, slider, checkbox or text field is in a `ui.column`, and how tall a `ui.row` is, unless told otherwise: 40 unless set.

```mojo
def control_height(mut self, height: Float64)
```

Make the controls `height` tall from now on.

### `state_layers`

```mojo
def state_layers(self) -> StateLayers
```

How strongly a widget shows that it is hovered, focused, pressed, dragged or disabled.

```mojo
def state_layers(mut self, layers: StateLayers)
```

Show the widgets' states as `layers` says from now on.

### `focus_ring`

```mojo
def focus_ring(self) -> FocusRing
```

The ring drawn around a widget focused from the keyboard, a gamepad or `take_focus`.

```mojo
def focus_ring(mut self, ring: FocusRing)
```

Draw the focus ring as `ring` from now on.

### `wants_mouse`

```mojo
def wants_mouse(self, context: Context) -> Bool
```

Whether the mouse is the UI's this frame: the pointer is over a widget, or a widget is held. A game checks it before using the mouse itself, so a click on a button doesn't also fire a weapon. A UI that opened no layer this frame or last, such as a menu that has closed, never wants it.

```mojo
# In `update`, before or after the UI's `with` block:
if context.mouse.pressed() and not self.ui.wants_mouse(context):
    self.fire()
```

### `wants_keyboard`

```mojo
def wants_keyboard(self, context: Context) -> Bool
```

Whether the keyboard is the UI's this frame. It is while a widget that takes typing has focus, and while a widget has focus from the keyboard, such as from Tab, rather than from a click or a gamepad, since the keys then act on it: Enter and Space press a button, the arrows move a slider. It is also in the frame a key moved or took away focus, such as Escape leaving a text field. A game checks it before reading keys itself, so typing a name with W in it doesn't move the player. A UI that opened no layer this frame or last never wants it.

```mojo
# In `update`, before or after the UI's `with` block:
if (
    context.keyboard.pressed(Key.ESCAPE)
    and not self.ui.wants_keyboard(context)
):
    context.quit()
```

### `screen`

```mojo
def screen(
    mut self,
    mut context: Context,
    mut canvas: Canvas,
    colors: ColorScheme = ColorScheme.light(primary=Optional(None), on_primary=Optional(None), secondary=Optional(None), on_secondary=Optional(None), tertiary=Optional(None), on_tertiary=Optional(None), error=Optional(None), on_error=Optional(None), surface=Optional(None), on_surface=Optional(None)),
) raises -> UILayer[origin_of(self), origin_of(context), origin_of(canvas)]
```

Open a layer drawn in screen space, on top of everything drawn before its block ends, whatever the camera and transform. Its widgets are drawn in `colors`, the light scheme unless given.

```mojo
# In `update`, with `ui: UI` and `colors: ColorScheme` fields:
canvas.background(self.colors.background)
with self.ui.screen(context, canvas, self.colors) as ui:
    ...
```

### `world`

```mojo
def world(
    mut self,
    mut context: Context,
    mut canvas: Canvas,
    colors: ColorScheme = ColorScheme.light(primary=Optional(None), on_primary=Optional(None), secondary=Optional(None), on_secondary=Optional(None), tertiary=Optional(None), on_tertiary=Optional(None), error=Optional(None), on_error=Optional(None), surface=Optional(None), on_surface=Optional(None)),
) raises -> UILayer[origin_of(self), origin_of(context), origin_of(canvas)]
```

Open a layer drawn in the space that is current when the block opens, the camera and any transform included: for a button above a chest, a health bar over an enemy, or a label that turns with a ship.

Its widgets move and zoom with the camera, and the pointer is taken
into the same space to find what is under it. They are drawn when the
block ends, beneath whatever is drawn after it, so where the block
sits decides what covers what. Its widgets are drawn in `colors`, the
light scheme unless given.

```mojo
# In `update`, with `ui: UI`, `camera: Camera` and `chest: Point`
# fields:
canvas.camera(self.camera)
with self.ui.world(context, canvas) as ui:
    if ui.button("Open", Rectangle(self.chest + Vector(0, 40), 80, 32)):
        self.open_chest()
```
