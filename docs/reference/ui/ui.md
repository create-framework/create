# UI

```mojo
struct UI
```

Widgets kept together: added once, then updated and drawn each frame in one call each.

```mojo
# In `create`, building the `ui` field and keeping a handle:
var ui = UI()
var card = ui.add(Panel())  # fitted round its column
var list = ui.add(Column(), card)
_ = ui.add(Label("Ready?"), list)
var play = ui.add(Button("Play"), list)

# In `update`:
self.ui.update(context, canvas)
with canvas.overlay():  # on the screen; leave it out to draw in the world
    canvas.draw(self.ui)
if self.ui[self.play].released():
    self.start()
```

A widget added inside another is drawn after it, so on top of it, and
takes the look of what it sits on: text on a panel takes the panel's
content colour.

A widget added with no `rect` of its own is sized by the tree every
frame, to the size it prefers, unless what it is in places it: a
`Column` stacks what is inside it, a `Row` sets it side by side, and a
`Panel` places a column or row inside it in its inside. A panel with no
size fits the column or row inside it. Where widgets overlap, only the topmost under the
pointer reacts to it, and a `Panel` covers what is beneath it.

`update` hit-tests through `canvas.to_local`, so call it in the same
transform and camera the tree is drawn in.

Implements `Deinitable`, `Drawable`, `Movable`.

## Constructors

```mojo
@staticmethod
def __init__(out self, *, player: Optional[Int] = None)
```

A tree whose focus any gamepad moves, unless `player` names one, as each player's menu in a split-screen game would.

## Methods

### `add`

```mojo
def add[W: Copyable](mut self, var widget: W) -> WidgetHandle[W]
```

Add `widget` at the top level, drawn above everything added before it.

```mojo
def add[W: Copyable, P: Copyable](
    mut self,
    var widget: W,
    parent: WidgetHandle[P],
) -> WidgetHandle[W]
```

Add `widget` inside `parent`: drawn after it and after what was added inside it before, and in the look of what it sits on.

### `colors`

```mojo
def colors(self) -> ColorScheme
```

The colours its widgets are drawn in: the light ones unless set.

```mojo
def colors(mut self, colors: ColorScheme)
```

### `corner_radius`

```mojo
def corner_radius(self) -> Float64
```

How round its widgets are: at the default, 16, a button is a pill.

```mojo
def corner_radius(mut self, radius: Float64)
```

### `state_layers`

```mojo
def state_layers(self) -> StateLayers
```

How far a hovered, pressed or dragged widget's colour steps.

```mojo
def state_layers(mut self, layers: StateLayers)
```

### `style`

```mojo
def style(
    mut self,
    *,
    button: Style = Style(fill=Optional(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=Optional(None), stroke_thickness=_OptionalFloat64(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=_OptionalFloat64(None), text_color=Optional(None), font=Optional(None), font_size=_OptionalFloat64(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=Optional(None), opacity=_OptionalFloat64(None), blend_mode=Optional(None), shadow=Optional(None), shadow_offset=Optional(None), shadow_blur=_OptionalFloat64(None), shadow_spread=_OptionalFloat64(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
    label: Style = Style(fill=Optional(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=Optional(None), stroke_thickness=_OptionalFloat64(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=_OptionalFloat64(None), text_color=Optional(None), font=Optional(None), font_size=_OptionalFloat64(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=Optional(None), opacity=_OptionalFloat64(None), blend_mode=Optional(None), shadow=Optional(None), shadow_offset=Optional(None), shadow_blur=_OptionalFloat64(None), shadow_spread=_OptionalFloat64(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
    panel: Style = Style(fill=Optional(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=Optional(None), stroke_thickness=_OptionalFloat64(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=_OptionalFloat64(None), text_color=Optional(None), font=Optional(None), font_size=_OptionalFloat64(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=Optional(None), opacity=_OptionalFloat64(None), blend_mode=Optional(None), shadow=Optional(None), shadow_offset=Optional(None), shadow_blur=_OptionalFloat64(None), shadow_spread=_OptionalFloat64(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
    slider_track: Style = Style(fill=Optional(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=Optional(None), stroke_thickness=_OptionalFloat64(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=_OptionalFloat64(None), text_color=Optional(None), font=Optional(None), font_size=_OptionalFloat64(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=Optional(None), opacity=_OptionalFloat64(None), blend_mode=Optional(None), shadow=Optional(None), shadow_offset=Optional(None), shadow_blur=_OptionalFloat64(None), shadow_spread=_OptionalFloat64(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
    slider_active_track: Style = Style(fill=Optional(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=Optional(None), stroke_thickness=_OptionalFloat64(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=_OptionalFloat64(None), text_color=Optional(None), font=Optional(None), font_size=_OptionalFloat64(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=Optional(None), opacity=_OptionalFloat64(None), blend_mode=Optional(None), shadow=Optional(None), shadow_offset=Optional(None), shadow_blur=_OptionalFloat64(None), shadow_spread=_OptionalFloat64(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
    slider_handle: Style = Style(fill=Optional(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=Optional(None), stroke_thickness=_OptionalFloat64(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=_OptionalFloat64(None), text_color=Optional(None), font=Optional(None), font_size=_OptionalFloat64(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=Optional(None), opacity=_OptionalFloat64(None), blend_mode=Optional(None), shadow=Optional(None), shadow_offset=Optional(None), shadow_blur=_OptionalFloat64(None), shadow_spread=_OptionalFloat64(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
    slider_handle_outline: Style = Style(fill=Optional(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=Optional(None), stroke_thickness=_OptionalFloat64(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=_OptionalFloat64(None), text_color=Optional(None), font=Optional(None), font_size=_OptionalFloat64(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=Optional(None), opacity=_OptionalFloat64(None), blend_mode=Optional(None), shadow=Optional(None), shadow_offset=Optional(None), shadow_blur=_OptionalFloat64(None), shadow_spread=_OptionalFloat64(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
    checkbox_box: Style = Style(fill=Optional(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=Optional(None), stroke_thickness=_OptionalFloat64(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=_OptionalFloat64(None), text_color=Optional(None), font=Optional(None), font_size=_OptionalFloat64(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=Optional(None), opacity=_OptionalFloat64(None), blend_mode=Optional(None), shadow=Optional(None), shadow_offset=Optional(None), shadow_blur=_OptionalFloat64(None), shadow_spread=_OptionalFloat64(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
    checkbox_checked_box: Style = Style(fill=Optional(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=Optional(None), stroke_thickness=_OptionalFloat64(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=_OptionalFloat64(None), text_color=Optional(None), font=Optional(None), font_size=_OptionalFloat64(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=Optional(None), opacity=_OptionalFloat64(None), blend_mode=Optional(None), shadow=Optional(None), shadow_offset=Optional(None), shadow_blur=_OptionalFloat64(None), shadow_spread=_OptionalFloat64(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
    checkbox_tick: Style = Style(fill=Optional(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=Optional(None), stroke_thickness=_OptionalFloat64(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=_OptionalFloat64(None), text_color=Optional(None), font=Optional(None), font_size=_OptionalFloat64(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=Optional(None), opacity=_OptionalFloat64(None), blend_mode=Optional(None), shadow=Optional(None), shadow_offset=Optional(None), shadow_blur=_OptionalFloat64(None), shadow_spread=_OptionalFloat64(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
    checkbox_text_style: Style = Style(fill=Optional(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=Optional(None), stroke_thickness=_OptionalFloat64(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=_OptionalFloat64(None), text_color=Optional(None), font=Optional(None), font_size=_OptionalFloat64(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=Optional(None), opacity=_OptionalFloat64(None), blend_mode=Optional(None), shadow=Optional(None), shadow_offset=Optional(None), shadow_blur=_OptionalFloat64(None), shadow_spread=_OptionalFloat64(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
    text_field_container: Style = Style(fill=Optional(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=Optional(None), stroke_thickness=_OptionalFloat64(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=_OptionalFloat64(None), text_color=Optional(None), font=Optional(None), font_size=_OptionalFloat64(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=Optional(None), opacity=_OptionalFloat64(None), blend_mode=Optional(None), shadow=Optional(None), shadow_offset=Optional(None), shadow_blur=_OptionalFloat64(None), shadow_spread=_OptionalFloat64(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
    text_field_focused_container: Style = Style(fill=Optional(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=Optional(None), stroke_thickness=_OptionalFloat64(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=_OptionalFloat64(None), text_color=Optional(None), font=Optional(None), font_size=_OptionalFloat64(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=Optional(None), opacity=_OptionalFloat64(None), blend_mode=Optional(None), shadow=Optional(None), shadow_offset=Optional(None), shadow_blur=_OptionalFloat64(None), shadow_spread=_OptionalFloat64(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
    text_field_text_style: Style = Style(fill=Optional(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=Optional(None), stroke_thickness=_OptionalFloat64(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=_OptionalFloat64(None), text_color=Optional(None), font=Optional(None), font_size=_OptionalFloat64(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=Optional(None), opacity=_OptionalFloat64(None), blend_mode=Optional(None), shadow=Optional(None), shadow_offset=Optional(None), shadow_blur=_OptionalFloat64(None), shadow_spread=_OptionalFloat64(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
    text_field_placeholder_style: Style = Style(fill=Optional(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=Optional(None), stroke_thickness=_OptionalFloat64(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=_OptionalFloat64(None), text_color=Optional(None), font=Optional(None), font_size=_OptionalFloat64(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=Optional(None), opacity=_OptionalFloat64(None), blend_mode=Optional(None), shadow=Optional(None), shadow_offset=Optional(None), shadow_blur=_OptionalFloat64(None), shadow_spread=_OptionalFloat64(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
    text_field_caret: Style = Style(fill=Optional(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=Optional(None), stroke_thickness=_OptionalFloat64(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=_OptionalFloat64(None), text_color=Optional(None), font=Optional(None), font_size=_OptionalFloat64(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=Optional(None), opacity=_OptionalFloat64(None), blend_mode=Optional(None), shadow=Optional(None), shadow_offset=Optional(None), shadow_blur=_OptionalFloat64(None), shadow_spread=_OptionalFloat64(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
    text_field_selection: Style = Style(fill=Optional(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=Optional(None), stroke_thickness=_OptionalFloat64(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=_OptionalFloat64(None), text_color=Optional(None), font=Optional(None), font_size=_OptionalFloat64(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=Optional(None), opacity=_OptionalFloat64(None), blend_mode=Optional(None), shadow=Optional(None), shadow_offset=Optional(None), shadow_blur=_OptionalFloat64(None), shadow_spread=_OptionalFloat64(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
)
```

Style every widget of a kind in it: each widget's own style sits over these, and these over the widget's defaults, field by field. Replaces what an earlier call set.

### `update`

```mojo
def update(mut self, mut context: Context, mut canvas: Canvas) raises
```

Update every widget, a parent before what is inside it, in the shared look: only the topmost widget under the pointer reacts to it. Call it before drawing the tree, in the same transform.

### `wants_mouse`

```mojo
def wants_mouse(self, context: Context) -> Bool
```

Whether the mouse is the tree's this frame: the pointer is over one of its widgets, or one is held. A game checks it before using the mouse itself, so a click on a button doesn't also fire a weapon. It reads the tree's last `update`, and a tree not updated this frame or last, such as a menu that has closed, never wants it.

```mojo
# In `update`, after the tree's `update`:
if context.mouse.pressed() and not self.ui.wants_mouse(context):
    self.fire()
```

### `wants_keyboard`

```mojo
def wants_keyboard(self, context: Context) -> Bool
```

Whether the keyboard is the tree's this frame: a text field has focus, or a widget has focus from the keyboard or code, so keys act on it; and in the frame a key moved or took away focus, such as Escape leaving a text field. A game checks it before reading keys itself, so typing a name with W in it doesn't move the player. A tree not updated this frame or last never wants it.

```mojo
# In `update`, after the tree's `update`:
if (
    context.keyboard.pressed(Key.ESCAPE)
    and not self.ui.wants_keyboard(context)
):
    context.quit()
```

### `enabled`

```mojo
def enabled[W: Copyable](self, handle: WidgetHandle[W]) -> Bool
```

Whether the tree lets the widget `handle` names react, apart from its own `enabled`: `True` unless set.

```mojo
def enabled[W: Copyable](mut self, handle: WidgetHandle[W], enabled: Bool)
```

Let the widget `handle` names, and everything inside it, react, or not: a disabled part of the tree is drawn faded, takes no focus, and lets go of focus it has. Each widget's own `enabled` is kept, so enabling the part again restores it.

### `draw_to`

```mojo
def draw_to(self, mut canvas: Canvas)
```

### `focus`

```mojo
def focus[W: Copyable](mut self, handle: WidgetHandle[W])
```

Give the widget `handle` names focus, with its ring showing, as Tab would: a dialog gives its first field focus as it opens. A widget that can't take focus, such as a label, takes nothing.

### `clear_focus`

```mojo
def clear_focus(mut self)
```

Take focus away from whatever has it, as Escape does.

### `has_focus`

```mojo
def has_focus[W: Copyable](self, handle: WidgetHandle[W]) -> Bool
```

Whether the widget `handle` names has focus.

## Special methods

### `__getitem__`

```mojo
def __getitem__[W: Copyable](
    ref self,
    handle: WidgetHandle[W],
) -> ref[self._nodes["element"].widget["value"]] W
```

The widget `handle` names, to read or change.
