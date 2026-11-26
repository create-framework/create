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
`Panel` places a column or row inside it in its inside, and a `ScrollArea`
shows part of a column taller than itself. A panel with no size fits
the column or row inside it. Where widgets overlap, only the
topmost under the pointer reacts to it, and a `Panel` covers what is
beneath it.

`ui.visible(handle, False)` hides a widget and everything inside it until
it is shown again, and `ui.remove(handle)` takes them out of the tree for
good.

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

Add `widget` at the top level, drawn above everything added before it. It is a `Button`, `Checkbox`, `Switch`, `ChoiceGroup`, `Tabs`, `Label`, `Panel`, `Slider`, `NumberField`, `TextField`, `Picture`, `ProgressBar`, `Column`, `Row`, `Space` or `ScrollArea`; anything else doesn't compile.

```mojo
def add[W: Copyable, P: Copyable](
    mut self,
    var widget: W,
    parent: WidgetHandle[P],
    *,
    grow: OptionalNumber = None,
    width: OptionalNumber = None,
    height: OptionalNumber = None,
    align: Optional[Align] = None,
) -> WidgetHandle[W]
```

Add `widget` inside `parent`: drawn after it and after what was added inside it before, and in the look of what it sits on. Only a `Panel`, `Column`, `Row` or `ScrollArea` can be a parent; anything else doesn't compile.

In a column or row, `width` and `height` set the size it starts
from, in place of the one it prefers, so two buttons given the same
`width` are as wide as each other:

```mojo
# In `create`: two buttons of one width, side by side.
var buttons = ui.add(Row(), column)
var ok = ui.add(Button("OK"), buttons, width=120)
var cancel = ui.add(Button("Cancel"), buttons, width=120)
```

The room a column or row has left over, once each widget has the
size it starts from, goes to the widgets added with a `grow`, in
proportion to it. A `width` of 0 with a `grow` gives exact shares:
`grow=1` and `grow=3` take a quarter and three quarters. `align`
sets where it sits across the column or row, in place of the
column's or row's own `align`, and a widget given a `width` in a
column, or a `height` in a row, is centred across it unless aligned.
A negative `grow`, `width` or
`height` stops the program.

### `get`

```mojo
def get[W: Copyable](self, handle: WidgetHandle[W]) -> W
```

A copy of the widget `handle` names, to read: as many can be read in one expression as you like, as in `Vector(ui.get(x).value, ui.get(y).value)`. Changing the copy changes nothing in the `UI`; change a widget through `ui[handle]`.

### `remove`

```mojo
def remove[W: Copyable](mut self, handle: WidgetHandle[W])
```

Take the widget `handle` names out of the tree, and everything inside it, for good: they are no longer laid out, updated or drawn, and the focus leaves them. Their handles name nothing afterwards, so drop them; to take a widget away for a while, hide it with `visible` instead.

```mojo
# In `update`, with `ui: UI` and `items: List[WidgetHandle[Button]]`
# fields: the item clicked is used up.
for i in range(len(self.items)):
    if self.ui[self.items[i]].released():
        self.ui.remove(self.items.pop(i))
        break
```

### `visible`

```mojo
def visible[W: Copyable](self, handle: WidgetHandle[W]) -> Bool
```

Whether the tree shows the widget `handle` names, apart from what it is inside: `True` unless set.

```mojo
def visible[W: Copyable](mut self, handle: WidgetHandle[W], visible: Bool)
```

Show the widget `handle` names, and everything inside it, or hide them: a hidden part of the tree isn't drawn, takes no room in a column or row, reacts to nothing, takes no focus and lets go of focus it has. Its widgets keep their fields, so showing it again brings it back as it was.

```mojo
# In `update`: the advanced settings show while their box is ticked.
var ticked = self.ui[self.advanced].checked
self.ui.visible(self.advanced_settings, ticked)
```

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

### `spacing`

```mojo
def spacing(self) -> Float64
```

The gap a `Column` or `Row` leaves between its widgets unless given one, and half the inset of a panel's inside: 8 unless set.

```mojo
def spacing(mut self, spacing: Float64)
```

### `control_height`

```mojo
def control_height(self) -> Float64
```

How tall a button, checkbox, slider or text field is when the `UI` sizes it: 40 unless set.

```mojo
def control_height(mut self, height: Float64)
```

### `focus_ring`

```mojo
def focus_ring(self) -> FocusRing
```

How the ring round a widget focused from the keyboard, a gamepad or code is drawn.

```mojo
def focus_ring(mut self, ring: FocusRing)
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
    button: Optional[Style] = None,
    label: Optional[Style] = None,
    panel: Optional[Style] = None,
    slider_track: Optional[Style] = None,
    slider_active_track: Optional[Style] = None,
    slider_handle: Optional[Style] = None,
    slider_handle_outline: Optional[Style] = None,
    checkbox_box: Optional[Style] = None,
    checkbox_checked_box: Optional[Style] = None,
    checkbox_tick: Optional[Style] = None,
    checkbox_text_style: Optional[Style] = None,
    text_field_container: Optional[Style] = None,
    text_field_focused_container: Optional[Style] = None,
    text_field_text_style: Optional[Style] = None,
    text_field_placeholder_style: Optional[Style] = None,
    text_field_caret: Optional[Style] = None,
    text_field_selection: Optional[Style] = None,
    scroll_area_track: Optional[Style] = None,
    scroll_area_thumb: Optional[Style] = None,
    progress_bar_track: Optional[Style] = None,
    progress_bar_indicator: Optional[Style] = None,
    switch_track: Optional[Style] = None,
    switch_on_track: Optional[Style] = None,
    switch_handle: Optional[Style] = None,
    switch_text_style: Optional[Style] = None,
    choice_group_circle: Optional[Style] = None,
    choice_group_selected_circle: Optional[Style] = None,
    choice_group_dot: Optional[Style] = None,
    choice_group_text_style: Optional[Style] = None,
    tabs_tab: Optional[Style] = None,
    tabs_selected_tab: Optional[Style] = None,
    tabs_indicator: Optional[Style] = None,
    number_field_container: Optional[Style] = None,
    number_field_text_style: Optional[Style] = None,
    number_field_buttons: Optional[Style] = None,
)
```

Style every widget of a kind in it: each widget's own style sits over these, and these over the widget's defaults, field by field.

Each keyword given replaces what an earlier call set for that kind,
and a kind left out keeps it, so the styles can be set a few at a
time. `Style()` clears a kind's style:

```mojo
# In `create`, building the `ui` field:
ui.style(button=Style(corner_radius=4))
ui.style(slider_handle=Style(stroke=Color.ORANGE))  # buttons kept
ui.style(button=Style())  # the buttons' defaults again
```

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

Let the widget `handle` names, and everything inside it, react, or not: the widgets, labels and pictures in a disabled part of the tree are drawn faded, take no focus, and let go of focus they have; a panel keeps its colour. Each widget's own `enabled` is kept, so enabling the part again restores it.

### `draw_to`

```mojo
def draw_to(self, mut canvas: Canvas)
```

### `scroll_to`

```mojo
def scroll_to[W: Copyable](mut self, handle: WidgetHandle[W])
```

Scroll each scroll area the widget `handle` names is in by the least that shows all of it, as moving focus onto it with Tab would. It takes effect at the tree's next `update`.

```mojo
# In `update`: show the level just unlocked.
if self.unlocked:
    self.ui.scroll_to(self.levels[self.next_level])
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

The widget `handle` names, to read or change: `ui[play].text = "Go"`, or `if ui[play].released():`.

It is the widget itself, inside the `UI`, so while one is in use no
other can be: `Vector(ui[x].value, ui[y].value)` doesn't compile in a
method that changes the `UI`. Read each into a variable first, or
read with `get`, which hands back a copy.
