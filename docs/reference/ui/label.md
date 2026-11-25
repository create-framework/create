# Label

```mojo
struct Label
```

Text placed in a rectangle, by an alignment: in its centre unless told otherwise, against its left edge with `Align.LEFT`, and so on. It reacts to nothing.

```mojo
# In `create`, building the `title` field:
var title = Label("Settings", Rectangle((0, 200), 300, 40), Align.LEFT)

# In `update`:
self.title.update(context, canvas)
canvas.draw(self.title)
```

Its text is drawn in the light colours' text colour, in its own `style`
over that; `Style(font_size=22)` makes a heading of it. The text is not
wrapped or cut to the rectangle: the rectangle only places it.

Implements `Copyable`, `Deinitable`, `Drawable`, `Movable`, `Widget`.

## Fields

- `text: String`: The text drawn.
- `rect: Rectangle`: Where the text is placed.
- `alignment: Optional[Align]`: Which point of `rect` the text is anchored to: the style's `text_alignment` when `None`, and the centre when that is unset too.
- `style: Style`: Its own style, over the default text style.

## Constructors

```mojo
@staticmethod
def __init__(
    out self,
    text: String,
    rect: Rectangle = Rectangle(Point(SIMD(0), SIMD(0)), SIMD(0), SIMD(0), corner_radius=_OptionalFloat64(SIMD(0)), rotation=_OptionalFloat64(SIMD(0))),
    alignment: Optional[Align] = None,
    *,
    style: Style = Style(fill=Optional(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=Optional(None), stroke_thickness=_OptionalFloat64(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=_OptionalFloat64(None), text_color=Optional(None), font=Optional(None), font_size=_OptionalFloat64(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=Optional(None), opacity=_OptionalFloat64(None), blend_mode=Optional(None), shadow=Optional(None), shadow_offset=Optional(None), shadow_blur=_OptionalFloat64(None), shadow_spread=_OptionalFloat64(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
)
```

## Methods

### `update`

```mojo
def update(mut self, mut context: Context, mut canvas: Canvas) raises
```

Work out its look from its fields: call it before drawing it.

### `draw_to`

```mojo
def draw_to(self, mut canvas: Canvas)
```
