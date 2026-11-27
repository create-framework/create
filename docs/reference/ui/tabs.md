# Tabs

```mojo
struct Tabs
```

A row of tabs, one of them selected, for switching between pages of a menu: the selected one's text in the accent colour, with a line beneath it.

```mojo
# In `create`, building the `ui` field: a page for each tab.
var tabs = ui.add(Tabs(["General", "Audio"]), column)
var general = ui.add(Column(), column)
var audio = ui.add(Column(), column)
ui.visible(audio, False)

# In `update`: show the selected tab's page.
if self.ui[self.tabs].changed():
    var selected = self.ui[self.tabs].selected
    self.ui.visible(self.general, selected == 0)
    self.ui.visible(self.audio, selected == 1)
```

A click on a tab selects it. In a `UI`, the left and right arrows and
a gamepad's push move the selection while it has focus. The tabs share
its width equally, the first at the left.

Each part is a shape drawn in a style of its own: `tab` is each tab, a
rectangle with its text, with no fill or outline unless its style
gives one; `selected_tab` is the selected one, taking what it leaves
unset from `tab`; `indicator` is the line beneath the selected tab, so
its stroke is its colour and thickness; and `divider` is a faint line
beneath them all, which the indicator sits on.

Implements `Clickable`, `Copyable`, `Deinitable`, `Drawable`, `Hoverable`, `Movable`, `Widget`.

## Fields

- `options: List[String]`: The tabs' text, the first at the left.
- `rect: Rectangle`: Where it is: the tabs share its width.
- `selected: Int`: Which tab is selected, counted from 0 at the left. Set it to select one from the program; outside the tabs, none is.
- `tab: Style`: Each tab, a rectangle with its text: no fill or outline unless given one.
- `selected_tab: Style`: The selected tab, taking what it leaves unset from `tab`.
- `indicator: Style`: The line beneath the selected tab: its stroke is its colour and thickness.
- `divider: Style`: The faint line beneath all the tabs, which the indicator sits on.
- `enabled: Bool`: Whether it reacts to the mouse. Disabled tabs are faded.

## Constructors

```mojo
@staticmethod
def __init__(
    out self,
    var options: List[String],
    rect: Rectangle = Rectangle(Point(SIMD(0), SIMD(0)), SIMD(0), SIMD(0), corner_radius=OptionalNumber(SIMD(0)), rotation=OptionalNumber(SIMD(0))),
    *,
    selected: Int = Int(0),
    tab: Style = Style(fill=OptionalColor(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=OptionalColor(None), stroke_thickness=OptionalNumber(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=OptionalNumber(None), text_color=OptionalColor(None), font=Optional(None), font_size=OptionalNumber(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=OptionalColor(None), opacity=OptionalNumber(None), blend_mode=Optional(None), shadow=OptionalColor(None), shadow_offset=Optional(None), shadow_blur=OptionalNumber(None), shadow_spread=OptionalNumber(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
    selected_tab: Style = Style(fill=OptionalColor(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=OptionalColor(None), stroke_thickness=OptionalNumber(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=OptionalNumber(None), text_color=OptionalColor(None), font=Optional(None), font_size=OptionalNumber(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=OptionalColor(None), opacity=OptionalNumber(None), blend_mode=Optional(None), shadow=OptionalColor(None), shadow_offset=Optional(None), shadow_blur=OptionalNumber(None), shadow_spread=OptionalNumber(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
    indicator: Style = Style(fill=OptionalColor(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=OptionalColor(None), stroke_thickness=OptionalNumber(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=OptionalNumber(None), text_color=OptionalColor(None), font=Optional(None), font_size=OptionalNumber(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=OptionalColor(None), opacity=OptionalNumber(None), blend_mode=Optional(None), shadow=OptionalColor(None), shadow_offset=Optional(None), shadow_blur=OptionalNumber(None), shadow_spread=OptionalNumber(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
    divider: Style = Style(fill=OptionalColor(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=OptionalColor(None), stroke_thickness=OptionalNumber(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=OptionalNumber(None), text_color=OptionalColor(None), font=Optional(None), font_size=OptionalNumber(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=OptionalColor(None), opacity=OptionalNumber(None), blend_mode=Optional(None), shadow=OptionalColor(None), shadow_offset=Optional(None), shadow_blur=OptionalNumber(None), shadow_spread=OptionalNumber(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
    enabled: Bool = True,
)
```

## Methods

### `update`

```mojo
def update(mut self, mut context: Context, mut canvas: Canvas) raises
```

Read what the mouse did to it this frame, selecting the tab clicked, and work out its look: call it before drawing it.

It is drawn in the canvas's colours,
`canvas.colors()`.

### `selected_text`

```mojo
def selected_text(self) -> String
```

The selected tab's text, or an empty string when none is.

### `changed`

```mojo
def changed(self) -> Bool
```

Whether its last `update` selected another tab.

### `hovered`

```mojo
def hovered(self) -> Bool
```

Whether the pointer is over it, as of its last `update`.

### `pressed`

```mojo
def pressed(self) -> Bool
```

Whether the left button went down over it this frame.

### `down`

```mojo
def down(self) -> Bool
```

Whether it is held: pressed on it, and the button not let go since, wherever the pointer has moved.

### `released`

```mojo
def released(self) -> Bool
```

Whether it was clicked this frame: let go over it, after being pressed on it.

### `draw_to`

```mojo
def draw_to(self, mut canvas: Canvas)
```
