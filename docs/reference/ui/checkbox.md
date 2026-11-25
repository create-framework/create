# Checkbox

```mojo
struct Checkbox
```

A box against the left edge of a rectangle, ticked while `checked`, with text beside it. A click anywhere in the rectangle ticks or unticks it.

```mojo
# In `create`, building the `music` field:
var music = Checkbox("Music", Rectangle((0, 0), 200, 32), checked=True)

# In `update`:
self.music.update(context, canvas)
canvas.draw(self.music)
if self.music.changed():
    self.audio.volume(1.0 if self.music.checked else 0.0)
```

Each part is a shape drawn in a style of its own: `box` is the empty
box, an outline unless its style fills it; `checked_box` is the ticked
box, filled, taking what it leaves unset from `box`; `tick` is the lines
of the tick, so its stroke is their colour and width; and `text_style`
is the text's.

Implements `Clickable`, `Copyable`, `Deinitable`, `Drawable`, `Hoverable`, `Movable`, `Widget`.

## Fields

- `text: String`: The text beside the box.
- `rect: Rectangle`: Where it is: the box against its left edge, and the area a click ticks it in.
- `checked: Bool`: Whether it is ticked. Set it to tick it from the program.
- `box: Style`
- `checked_box: Style`
- `tick: Style`
- `text_style: Style`
- `enabled: Bool`: Whether it reacts to the mouse. A disabled checkbox is faded.

## Constructors

```mojo
@staticmethod
def __init__(
    out self,
    text: String,
    rect: Rectangle = Rectangle(Point(SIMD(0), SIMD(0)), SIMD(0), SIMD(0), corner_radius=_OptionalFloat64(SIMD(0)), rotation=_OptionalFloat64(SIMD(0))),
    *,
    checked: Bool = False,
    box: Style = Style(fill=Optional(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=Optional(None), stroke_thickness=_OptionalFloat64(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=_OptionalFloat64(None), text_color=Optional(None), font=Optional(None), font_size=_OptionalFloat64(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=Optional(None), opacity=_OptionalFloat64(None), blend_mode=Optional(None), shadow=Optional(None), shadow_offset=Optional(None), shadow_blur=_OptionalFloat64(None), shadow_spread=_OptionalFloat64(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
    checked_box: Style = Style(fill=Optional(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=Optional(None), stroke_thickness=_OptionalFloat64(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=_OptionalFloat64(None), text_color=Optional(None), font=Optional(None), font_size=_OptionalFloat64(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=Optional(None), opacity=_OptionalFloat64(None), blend_mode=Optional(None), shadow=Optional(None), shadow_offset=Optional(None), shadow_blur=_OptionalFloat64(None), shadow_spread=_OptionalFloat64(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
    tick: Style = Style(fill=Optional(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=Optional(None), stroke_thickness=_OptionalFloat64(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=_OptionalFloat64(None), text_color=Optional(None), font=Optional(None), font_size=_OptionalFloat64(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=Optional(None), opacity=_OptionalFloat64(None), blend_mode=Optional(None), shadow=Optional(None), shadow_offset=Optional(None), shadow_blur=_OptionalFloat64(None), shadow_spread=_OptionalFloat64(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
    text_style: Style = Style(fill=Optional(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=Optional(None), stroke_thickness=_OptionalFloat64(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=_OptionalFloat64(None), text_color=Optional(None), font=Optional(None), font_size=_OptionalFloat64(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=Optional(None), opacity=_OptionalFloat64(None), blend_mode=Optional(None), shadow=Optional(None), shadow_offset=Optional(None), shadow_blur=_OptionalFloat64(None), shadow_spread=_OptionalFloat64(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
    enabled: Bool = True,
)
```

## Methods

### `update`

```mojo
def update(mut self, mut context: Context, mut canvas: Canvas) raises
```

Read what the mouse did to it this frame, ticking or unticking it on a click, and work out its look: call it before drawing it.

### `changed`

```mojo
def changed(self) -> Bool
```

Whether its last `update` ticked or unticked it.

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
