# Panel

```mojo
struct Panel
```

A surface filling a rectangle, for widgets to sit on: a rounded card in the light colours' `surface_container`, unless its `style` says otherwise. It reacts to nothing.

```mojo
# In `create`, building the `card` field:
var card = Panel(Rectangle((0, 0), 320, 200))

# In `update`: the card, then what sits on it.
self.card.update(context, canvas)
canvas.draw(self.card)
```

`content_color()` is the colour for text on it: its style's
`text_color`, or the partner of its fill, so text on a dark panel can be
drawn light.

Implements `Copyable`, `Deinitable`, `Drawable`, `Movable`, `Widget`.

## Fields

- `rect: Rectangle`: Where it is, and how big.
- `style: Style`: Its own style, over the default card.

## Constructors

```mojo
@staticmethod
def __init__(
    out self,
    rect: Rectangle,
    *,
    style: Style = Style(fill=Optional(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=Optional(None), stroke_thickness=_OptionalFloat64(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=_OptionalFloat64(None), text_color=Optional(None), font=Optional(None), font_size=_OptionalFloat64(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=Optional(None), opacity=_OptionalFloat64(None), blend_mode=Optional(None), shadow=Optional(None), shadow_offset=Optional(None), shadow_blur=_OptionalFloat64(None), shadow_spread=_OptionalFloat64(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
)
```

## Methods

### `update`

```mojo
def update(mut self, mut context: Context, canvas: Canvas) raises
```

Work out its look from its fields: call it before drawing it.

### `surface_color`

```mojo
def surface_color(self) -> Color
```

The colour the widgets on it sit on: its fill, or, with its fill switched off, what is beneath it.

### `content_color`

```mojo
def content_color(self) -> Color
```

The colour for text on it.

### `draw_to`

```mojo
def draw_to(self, mut canvas: Canvas)
```
