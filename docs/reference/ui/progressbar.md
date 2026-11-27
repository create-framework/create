# ProgressBar

```mojo
struct ProgressBar
```

A bar filled as far as `value` has got from `minimum` to `maximum`, such as a level loading, a health bar or a cooldown. It reacts to nothing.

```mojo
# In `create`, building the `loading` field:
var loading = ProgressBar(0, Rectangle((0, -100), 300, 20))

# In `update`: fill it as the level loads.
self.loading.value = self.loaded / self.total
self.loading.update(context, canvas)
canvas.draw(self.loading)
```

A `value` outside `minimum` to `maximum` fills it no further than its
ends. `maximum` may be less than `minimum`, which runs it the other way.

Each part is a line drawn in a style of its own, so its stroke is its
colour and thickness: `track` is the whole length, and `indicator`, the
line from the start to `value`, lies over it, taking what it leaves
unset from `track`.

Implements `Copyable`, `Deinitable`, `Drawable`, `Movable`, `Widget`.

## Fields

- `value: Float64`: How far it has got. Set it as what it shows moves on.
- `minimum: Float64`: The value at the left end: empty.
- `maximum: Float64`: The value at the right end: full.
- `rect: Rectangle`: Where it is: the bar runs across its middle.
- `track: Style`
- `indicator: Style`
- `enabled: Bool`: Whether it is shown as active. A disabled bar is faded.

## Constructors

```mojo
@staticmethod
def __init__(
    out self,
    value: Float64,
    rect: Rectangle = Rectangle(Point(SIMD(0), SIMD(0)), SIMD(0), SIMD(0), corner_radius=OptionalNumber(SIMD(0)), rotation=OptionalNumber(SIMD(0))),
    *,
    minimum: OptionalNumber = None,
    maximum: OptionalNumber = None,
    track: Style = Style(fill=OptionalColor(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=OptionalColor(None), stroke_thickness=OptionalNumber(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=OptionalNumber(None), text_color=OptionalColor(None), font=Optional(None), font_size=OptionalNumber(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=OptionalColor(None), opacity=OptionalNumber(None), blend_mode=Optional(None), shadow=OptionalColor(None), shadow_offset=Optional(None), shadow_blur=OptionalNumber(None), shadow_spread=OptionalNumber(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
    indicator: Style = Style(fill=OptionalColor(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=OptionalColor(None), stroke_thickness=OptionalNumber(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=OptionalNumber(None), text_color=OptionalColor(None), font=Optional(None), font_size=OptionalNumber(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=OptionalColor(None), opacity=OptionalNumber(None), blend_mode=Optional(None), shadow=OptionalColor(None), shadow_offset=Optional(None), shadow_blur=OptionalNumber(None), shadow_spread=OptionalNumber(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
    enabled: Bool = True,
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

### `fraction`

```mojo
def fraction(self) -> Float64
```

How far along it is, from 0 when empty to 1 when full.

### `draw_to`

```mojo
def draw_to(self, mut canvas: Canvas)
```
