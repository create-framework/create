# Panel

```mojo
struct Panel
```

A surface filling a rectangle, for widgets to sit on: a rounded card in its colours' `surface_container`, unless its `style` says otherwise. It reacts to nothing.

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

In a `UI`, it places a column or row added inside it across its inside,
`padding` short of each edge.

Implements `Copyable`, `Deinitable`, `Drawable`, `Movable`, `Widget`.

## Fields

- `rect: Rectangle`: Where it is, and how big.
- `style: Style`: Its own style, over the default card.
- `padding: OptionalNumber`: How far inside its edges a `UI` places the column or row in it: twice the `UI`'s `spacing` when `None`.

## Constructors

```mojo
@staticmethod
def __init__(
    out self,
    rect: Rectangle = Rectangle(Point(Number(SIMD(0)), Number(SIMD(0))), Number(SIMD(0)), Number(SIMD(0)), corner_radius=OptionalNumber(SIMD(0)), rotation=OptionalNumber(SIMD(0))),
    *,
    style: Style = Style(fill=OptionalColor(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=OptionalColor(None), stroke_thickness=OptionalNumber(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=OptionalNumber(None), text_color=OptionalColor(None), font=Optional(None), font_size=OptionalNumber(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=OptionalColor(None), opacity=OptionalNumber(None), blend_mode=Optional(None), shadow=OptionalColor(None), shadow_offset=Optional(None), shadow_blur=OptionalNumber(None), shadow_spread=OptionalNumber(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
    padding: OptionalNumber = None,
)
```

## Methods

### `update`

```mojo
def update(mut self, mut context: Context, mut canvas: Canvas) raises
```

Work out its look from its fields: call it before drawing it.

It is drawn in the canvas's colours,
`canvas.colors()`.

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
