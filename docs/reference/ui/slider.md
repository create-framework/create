# Slider

```mojo
struct Slider
```

A handle on a track, dragged to set `value` between `minimum` and `maximum`.

```mojo
# In `create`, building the `volume` field:
var volume = Slider(0.8, 0, 1, Rectangle((0, 0), 240, 32))

# In `update`:
self.volume.update(context, canvas)
canvas.draw(self.volume)
if self.volume.changed():
    self.audio.volume(self.volume.value)
```

Pressing anywhere in `rect` moves the handle there, and dragging moves
it on, even once the pointer leaves `rect`. `step` rounds the value to
multiples of it counted from `minimum`, and must be more than 0. A
`value` outside `minimum` to `maximum` is drawn at the nearer end, and
left as it is until dragged. `maximum` may be less than `minimum`, which
runs the slider the other way.

Each part is a shape drawn in a style of its own: `track` is a line, so
its stroke is the track's colour and thickness; `active_track` is the
line from the start to the handle, over `track`, taking what it leaves
unset from it; `handle` is a point, so its stroke is the handle's colour
and its `stroke_thickness` its diameter (`StrokeCap.SQUARE` makes it
square); and `handle_outline` is a circle round the handle, drawn when
it sets a stroke or a fill.

Implements `Clickable`, `Copyable`, `Deinitable`, `Drawable`, `Hoverable`, `Movable`, `Widget`.

## Fields

- `value: Float64`: The value it sets. Set it to move the handle from the program.
- `minimum: Float64`: The value at the left end.
- `maximum: Float64`: The value at the right end.
- `rect: Rectangle`: Where it is: the track runs across its middle, and a press anywhere in it moves the handle.
- `step: Optional[Float64]`: What the value is rounded to a multiple of, from `minimum`; `None` for any value.
- `track: Style`
- `active_track: Style`
- `handle: Style`
- `handle_outline: Style`
- `enabled: Bool`: Whether it reacts to the mouse. A disabled slider is faded.

## Constructors

```mojo
@staticmethod
def __init__(
    out self,
    value: Float64,
    minimum: Float64,
    maximum: Float64,
    rect: Rectangle = Rectangle(Point(SIMD(0), SIMD(0)), SIMD(0), SIMD(0), corner_radius=OptionalNumber(SIMD(0)), rotation=OptionalNumber(SIMD(0))),
    *,
    step: OptionalNumber = None,
    track: Style = Style(fill=OptionalColor(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=OptionalColor(None), stroke_thickness=OptionalNumber(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=OptionalNumber(None), text_color=OptionalColor(None), font=Optional(None), font_size=OptionalNumber(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=OptionalColor(None), opacity=OptionalNumber(None), blend_mode=Optional(None), shadow=OptionalColor(None), shadow_offset=Optional(None), shadow_blur=OptionalNumber(None), shadow_spread=OptionalNumber(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
    active_track: Style = Style(fill=OptionalColor(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=OptionalColor(None), stroke_thickness=OptionalNumber(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=OptionalNumber(None), text_color=OptionalColor(None), font=Optional(None), font_size=OptionalNumber(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=OptionalColor(None), opacity=OptionalNumber(None), blend_mode=Optional(None), shadow=OptionalColor(None), shadow_offset=Optional(None), shadow_blur=OptionalNumber(None), shadow_spread=OptionalNumber(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
    handle: Style = Style(fill=OptionalColor(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=OptionalColor(None), stroke_thickness=OptionalNumber(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=OptionalNumber(None), text_color=OptionalColor(None), font=Optional(None), font_size=OptionalNumber(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=OptionalColor(None), opacity=OptionalNumber(None), blend_mode=Optional(None), shadow=OptionalColor(None), shadow_offset=Optional(None), shadow_blur=OptionalNumber(None), shadow_spread=OptionalNumber(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
    handle_outline: Style = Style(fill=OptionalColor(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=OptionalColor(None), stroke_thickness=OptionalNumber(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=OptionalNumber(None), text_color=OptionalColor(None), font=Optional(None), font_size=OptionalNumber(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=OptionalColor(None), opacity=OptionalNumber(None), blend_mode=Optional(None), shadow=OptionalColor(None), shadow_offset=Optional(None), shadow_blur=OptionalNumber(None), shadow_spread=OptionalNumber(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
    enabled: Bool = True,
)
```

## Methods

### `update`

```mojo
def update(mut self, mut context: Context, mut canvas: Canvas) raises
```

Read what the mouse did to it this frame, moving the handle while it is dragged, and work out its look: call it before drawing it. Raises if `step` isn't more than 0.

It is drawn in the canvas's colours,
`canvas.colors()`.

### `changed`

```mojo
def changed(self) -> Bool
```

Whether its last `update` changed `value`.

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

Whether it is being dragged.

### `released`

```mojo
def released(self) -> Bool
```

### `draw_to`

```mojo
def draw_to(self, mut canvas: Canvas)
```
