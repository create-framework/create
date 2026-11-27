# Dropdown

```mojo
struct Dropdown
```

A field showing the chosen one of its options, which opens a list of them all when clicked, drawn over everything else. Use it to choose one of many options, such as a screen resolution, where a `ChoiceGroup` would take too much room.

```mojo
# In `create`, building the `resolution` field:
var resolution = Dropdown(
    ["1280 × 720", "1920 × 1080", "2560 × 1440"],
    Rectangle((0, 0), 220, 40),
)

# In `update`: drawn last, so its list is drawn over the rest.
self.resolution.update(context, canvas)
canvas.draw(self.resolution)
if self.resolution.changed():
    self.apply(self.resolution.selected)
```

A click on the field opens the list; a click on an item chooses it and
closes the list, and a click anywhere else closes it without choosing.
The list opens below the field, or above it where that leaves more
room, and shows at most `max_items` at once: the mouse wheel scrolls
the rest into view.

In a `UI`, it works without a mouse too. While it has focus, Enter,
Space or a gamepad's south button opens its list; then the up and down
arrows or the gamepad's push move the mark, Enter, Space or the south
button choose the marked item, and Escape or the east button close the
list without choosing, keeping focus on it. Tab closes it and moves
on.

In a `UI`, its list is drawn after every other widget and outside any
scroll area's window, and while it is open, a click anywhere reaches
only the dropdown. On its own, draw it after everything else, and keep
a click that closes it from reaching what is beneath.

Each part is a shape drawn in a style of its own: `field` is the
field, a rectangle with the chosen option's text; `list` is the open
list, a rectangle; and `item` is each item's text, the chosen one in
the accent colour.

Implements `Clickable`, `Copyable`, `Deinitable`, `Drawable`, `Hoverable`, `Movable`, `Widget`.

## Fields

- `options: List[String]`: The options' text, in the order they are listed.
- `rect: Rectangle`: Where its field is.
- `selected: Int`: Which option is chosen, counted from 0. Set it to choose one from the program; outside the options, the field is empty.
- `max_items: Int`: The most items the open list shows at once.
- `field: Style`: The field, a rectangle with the chosen option's text.
- `list: Style`: The open list, a rectangle.
- `item: Style`: Each item's text, the chosen one in the accent colour.
- `enabled: Bool`: Whether it reacts to the mouse. A disabled dropdown is faded and closed.

## Constructors

```mojo
@staticmethod
def __init__(
    out self,
    var options: List[String],
    rect: Rectangle = Rectangle(Point(SIMD(0), SIMD(0)), SIMD(0), SIMD(0), corner_radius=OptionalNumber(SIMD(0)), rotation=OptionalNumber(SIMD(0))),
    *,
    selected: Int = Int(0),
    max_items: Int = Int(6),
    field: Style = Style(fill=OptionalColor(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=OptionalColor(None), stroke_thickness=OptionalNumber(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=OptionalNumber(None), text_color=OptionalColor(None), font=Optional(None), font_size=OptionalNumber(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=OptionalColor(None), opacity=OptionalNumber(None), blend_mode=Optional(None), shadow=OptionalColor(None), shadow_offset=Optional(None), shadow_blur=OptionalNumber(None), shadow_spread=OptionalNumber(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
    list: Style = Style(fill=OptionalColor(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=OptionalColor(None), stroke_thickness=OptionalNumber(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=OptionalNumber(None), text_color=OptionalColor(None), font=Optional(None), font_size=OptionalNumber(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=OptionalColor(None), opacity=OptionalNumber(None), blend_mode=Optional(None), shadow=OptionalColor(None), shadow_offset=Optional(None), shadow_blur=OptionalNumber(None), shadow_spread=OptionalNumber(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
    item: Style = Style(fill=OptionalColor(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=OptionalColor(None), stroke_thickness=OptionalNumber(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=OptionalNumber(None), text_color=OptionalColor(None), font=Optional(None), font_size=OptionalNumber(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=OptionalColor(None), opacity=OptionalNumber(None), blend_mode=Optional(None), shadow=OptionalColor(None), shadow_offset=Optional(None), shadow_blur=OptionalNumber(None), shadow_spread=OptionalNumber(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
    enabled: Bool = True,
)
```

## Methods

### `update`

```mojo
def update(mut self, mut context: Context, mut canvas: Canvas) raises
```

Read what the mouse did to it this frame, opening, choosing and closing, and work out its look: call it before drawing it.

It is drawn in the canvas's colours,
`canvas.colors()`.

### `is_open`

```mojo
def is_open(self) -> Bool
```

Whether its list is open.

### `selected_text`

```mojo
def selected_text(self) -> String
```

The chosen option's text, or an empty string when none is.

### `changed`

```mojo
def changed(self) -> Bool
```

Whether its last `update` chose another option.

### `hovered`

```mojo
def hovered(self) -> Bool
```

Whether the pointer is over its field, or its list while open, as of its last `update`.

### `pressed`

```mojo
def pressed(self) -> Bool
```

Whether the left button went down over its field, or its list while open, this frame.

### `down`

```mojo
def down(self) -> Bool
```

Whether it is held: pressed on it, and the button not let go since, wherever the pointer has moved.

### `released`

```mojo
def released(self) -> Bool
```

Whether it was clicked this frame: let go over its field or its open list after being pressed on it, or, in a `UI`, pressed with Enter, Space or a gamepad's south button while it has focus.

### `draw_to`

```mojo
def draw_to(self, mut canvas: Canvas)
```
