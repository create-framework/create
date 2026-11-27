# ChoiceGroup

```mojo
struct ChoiceGroup
```

A few options, one under the other, of which one is chosen: each a circle with its text, the chosen one's circle with a dot in it. Other toolkits call these radio buttons.

```mojo
# In `create`, building the `difficulty` field:
var difficulty = ChoiceGroup(
    ["Easy", "Normal", "Hard"], Rectangle((0, 0), 200, 120), selected=1
)

# In `update`:
self.difficulty.update(context, canvas)
canvas.draw(self.difficulty)
if self.difficulty.changed():
    self.start_level(self.difficulty.selected)
```

A click on an option chooses it. In a `UI`, the up and down arrows and
a gamepad's push move the choice while it has focus. Each option takes
an equal share of its rectangle's height, the first at the top. A
`Dropdown` suits a longer list, and a column of `Checkbox`es suits
choosing several.

Each part is a shape drawn in a style of its own: `circle` is each
option's circle, an outline unless its style fills it;
`selected_circle` is the chosen option's, taking what it leaves unset
from `circle`; `dot` is a point in the chosen circle, so its stroke is
its colour and its `stroke_thickness` its diameter; and `text_style` is
the options' text.

Implements `Clickable`, `Copyable`, `Deinitable`, `Drawable`, `Hoverable`, `Movable`, `Widget`.

## Fields

- `options: List[String]`: The options' text, the first at the top.
- `rect: Rectangle`: Where it is: the options share its height, their circles against its left edge.
- `selected: Int`: Which option is chosen, counted from 0 at the top. Set it to choose one from the program; outside the options, none is.
- `circle: Style`
- `selected_circle: Style`
- `dot: Style`
- `text_style: Style`
- `enabled: Bool`: Whether it reacts to the mouse. A disabled group is faded.

## Constructors

```mojo
@staticmethod
def __init__(
    out self,
    var options: List[String],
    rect: Rectangle = Rectangle(Point(SIMD(0), SIMD(0)), SIMD(0), SIMD(0), corner_radius=OptionalNumber(SIMD(0)), rotation=OptionalNumber(SIMD(0))),
    *,
    selected: Int = Int(0),
    circle: Style = Style(fill=OptionalColor(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=OptionalColor(None), stroke_thickness=OptionalNumber(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=OptionalNumber(None), text_color=OptionalColor(None), font=Optional(None), font_size=OptionalNumber(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=OptionalColor(None), opacity=OptionalNumber(None), blend_mode=Optional(None), shadow=OptionalColor(None), shadow_offset=Optional(None), shadow_blur=OptionalNumber(None), shadow_spread=OptionalNumber(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
    selected_circle: Style = Style(fill=OptionalColor(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=OptionalColor(None), stroke_thickness=OptionalNumber(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=OptionalNumber(None), text_color=OptionalColor(None), font=Optional(None), font_size=OptionalNumber(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=OptionalColor(None), opacity=OptionalNumber(None), blend_mode=Optional(None), shadow=OptionalColor(None), shadow_offset=Optional(None), shadow_blur=OptionalNumber(None), shadow_spread=OptionalNumber(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
    dot: Style = Style(fill=OptionalColor(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=OptionalColor(None), stroke_thickness=OptionalNumber(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=OptionalNumber(None), text_color=OptionalColor(None), font=Optional(None), font_size=OptionalNumber(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=OptionalColor(None), opacity=OptionalNumber(None), blend_mode=Optional(None), shadow=OptionalColor(None), shadow_offset=Optional(None), shadow_blur=OptionalNumber(None), shadow_spread=OptionalNumber(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
    text_style: Style = Style(fill=OptionalColor(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=OptionalColor(None), stroke_thickness=OptionalNumber(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=OptionalNumber(None), text_color=OptionalColor(None), font=Optional(None), font_size=OptionalNumber(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=OptionalColor(None), opacity=OptionalNumber(None), blend_mode=Optional(None), shadow=OptionalColor(None), shadow_offset=Optional(None), shadow_blur=OptionalNumber(None), shadow_spread=OptionalNumber(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
    enabled: Bool = True,
)
```

## Methods

### `update`

```mojo
def update(mut self, mut context: Context, mut canvas: Canvas) raises
```

Read what the mouse did to it this frame, choosing the option clicked, and work out its look: call it before drawing it.

It is drawn in the canvas's colours,
`canvas.colors()`.

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

### `pressed`

```mojo
def pressed(self) -> Bool
```

### `down`

```mojo
def down(self) -> Bool
```

### `released`

```mojo
def released(self) -> Bool
```

### `draw_to`

```mojo
def draw_to(self, mut canvas: Canvas)
```
