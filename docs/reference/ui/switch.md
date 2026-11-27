# Switch

```mojo
struct Switch
```

A setting that is on or off and applies at once, such as music or full screen: a track against the left edge of a rectangle, its handle at the right end while `on`, with text beside it. A click anywhere in the rectangle turns it over.

```mojo
# In `create`, building the `music` field:
var music = Switch("Music", Rectangle((0, 0), 200, 32), on=True)

# In `update`:
self.music.update(context, canvas)
canvas.draw(self.music)
if self.music.changed():
    self.audio.volume(1.0 if self.music.on else 0.0)
```

A switch and a checkbox do the same job. A switch reads as a setting
that takes effect the moment it is turned, and a checkbox as a choice
made before something else happens, such as a box ticked in a form.

Each part is a shape drawn in a style of its own: `track` is a
rectangle, its outline and fill drawn while off, rounded as the
controls are; `on_track` is the same rectangle while on, taking what it
leaves unset from `track`; `handle` is a square in it, larger while on,
so its fill is its colour and its `corner_radius` how round it is; and
`text_style` is the text's. Unless styled, the handle is rounded as much
less than the track as it sits inside it, so a track rounded into a
pill, `corner_radius=12`, holds a round handle.

Implements `Clickable`, `Copyable`, `Deinitable`, `Drawable`, `Hoverable`, `Movable`, `Widget`.

## Fields

- `text: String`: The text beside the track.
- `rect: Rectangle`: Where it is: the track against its left edge, and the area a click turns it over in.
- `on: Bool`: Whether it is on. Set it to turn it from the program.
- `track: Style`: The track while off, a rectangle rounded as the controls are.
- `on_track: Style`: The track while on, taking what it leaves unset from `track`.
- `handle: Style`: The handle, a square in the track: its fill is its colour, and its `corner_radius` how round it is.
- `text_style: Style`: The text beside the track.
- `enabled: Bool`: Whether it reacts to the mouse. A disabled switch is faded.

## Constructors

```mojo
@staticmethod
def __init__(
    out self,
    text: String,
    rect: Rectangle = Rectangle(Point(Number(SIMD(0)), Number(SIMD(0))), Number(SIMD(0)), Number(SIMD(0)), corner_radius=OptionalNumber(SIMD(0)), rotation=OptionalNumber(SIMD(0))),
    *,
    on: Bool = False,
    track: Style = Style(fill=OptionalColor(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=OptionalColor(None), stroke_thickness=OptionalNumber(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=OptionalNumber(None), text_color=OptionalColor(None), font=Optional(None), font_size=OptionalNumber(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=OptionalColor(None), opacity=OptionalNumber(None), blend_mode=Optional(None), shadow=OptionalColor(None), shadow_offset=Optional(None), shadow_blur=OptionalNumber(None), shadow_spread=OptionalNumber(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
    on_track: Style = Style(fill=OptionalColor(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=OptionalColor(None), stroke_thickness=OptionalNumber(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=OptionalNumber(None), text_color=OptionalColor(None), font=Optional(None), font_size=OptionalNumber(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=OptionalColor(None), opacity=OptionalNumber(None), blend_mode=Optional(None), shadow=OptionalColor(None), shadow_offset=Optional(None), shadow_blur=OptionalNumber(None), shadow_spread=OptionalNumber(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
    handle: Style = Style(fill=OptionalColor(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=OptionalColor(None), stroke_thickness=OptionalNumber(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=OptionalNumber(None), text_color=OptionalColor(None), font=Optional(None), font_size=OptionalNumber(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=OptionalColor(None), opacity=OptionalNumber(None), blend_mode=Optional(None), shadow=OptionalColor(None), shadow_offset=Optional(None), shadow_blur=OptionalNumber(None), shadow_spread=OptionalNumber(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
    text_style: Style = Style(fill=OptionalColor(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=OptionalColor(None), stroke_thickness=OptionalNumber(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=OptionalNumber(None), text_color=OptionalColor(None), font=Optional(None), font_size=OptionalNumber(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=OptionalColor(None), opacity=OptionalNumber(None), blend_mode=Optional(None), shadow=OptionalColor(None), shadow_offset=Optional(None), shadow_blur=OptionalNumber(None), shadow_spread=OptionalNumber(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
    enabled: Bool = True,
)
```

## Methods

### `update`

```mojo
def update(mut self, mut context: Context, mut canvas: Canvas) raises
```

Read what the mouse did to it this frame, turning it over on a click, and work out its look: call it before drawing it.

It is drawn in the canvas's colours,
`canvas.colors()`.

### `changed`

```mojo
def changed(self) -> Bool
```

Whether its last `update` turned it over.

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

Whether it was clicked this frame: let go over it after being pressed on it, or, in a `UI`, pressed with Enter, Space or a gamepad's south button while it has focus.

### `draw_to`

```mojo
def draw_to(self, mut canvas: Canvas)
```
