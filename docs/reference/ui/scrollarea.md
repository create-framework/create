# ScrollArea

```mojo
struct ScrollArea
```

A window onto a column of widgets, showing the part of it that fits.

Add one column inside it. The column is as tall as its widgets, and
the window shows the part of it `offset` down from its top; what falls
outside the window is neither drawn nor clicked. While the column is
taller than the window, a scroll bar runs down the window's right edge:
the mouse wheel over the window scrolls it, and so does dragging the
bar's thumb.

```mojo
# In `create`: a list of levels, never taller than 240.
var window = ui.add(ScrollArea(max_height=240), column)
var levels = ui.add(Column(), window)
for name in ["Forest", "Caves", "Castle", "Sky", "Moon"]:
    _ = ui.add(Button(name), levels)

# In `update`: back to the top.
self.ui[self.window].offset = 0
```

It leaves room round its column for a focused widget's ring, so the
ring isn't cut at its edges. With no `rect` of its own it is as wide as
its column, and as tall as it too, that room included, up to
`max_height`. In a column or row it can `grow` to fill
the room left over, like any other widget.

The bar has two parts, each a line drawn in a style of its own:
`track`, the length the thumb runs along, and `thumb`, whose length
shows how much of the column the window shows. The stroke of each is
its colour and thickness.

Implements `Copyable`, `Deinitable`, `Movable`.

## Fields

- `rect: Rectangle`: Where the window is: given, or set by what it is in.
- `offset: Float64`: How far down its column the window shows, from 0 at the top. Each layout keeps it between 0 and as far as the column goes.
- `max_height: Optional[Float64]`: The tallest it grows to fit its column, with no `rect` of its own: as tall as the column when `None`.
- `track: Style`
- `thumb: Style`

## Constructors

```mojo
@staticmethod
def __init__(
    out self,
    rect: Rectangle = Rectangle(Point(SIMD(0), SIMD(0)), SIMD(0), SIMD(0), corner_radius=OptionalNumber(SIMD(0)), rotation=OptionalNumber(SIMD(0))),
    *,
    max_height: OptionalNumber = None,
    track: Style = Style(fill=OptionalColor(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=OptionalColor(None), stroke_thickness=OptionalNumber(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=OptionalNumber(None), text_color=OptionalColor(None), font=Optional(None), font_size=OptionalNumber(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=OptionalColor(None), opacity=OptionalNumber(None), blend_mode=Optional(None), shadow=OptionalColor(None), shadow_offset=Optional(None), shadow_blur=OptionalNumber(None), shadow_spread=OptionalNumber(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
    thumb: Style = Style(fill=OptionalColor(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=OptionalColor(None), stroke_thickness=OptionalNumber(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=OptionalNumber(None), text_color=OptionalColor(None), font=Optional(None), font_size=OptionalNumber(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=OptionalColor(None), opacity=OptionalNumber(None), blend_mode=Optional(None), shadow=OptionalColor(None), shadow_offset=Optional(None), shadow_blur=OptionalNumber(None), shadow_spread=OptionalNumber(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
)
```
