# Style

```mojo
struct Style
```

A set of style changes: how something is painted, independent of where it goes. Each part is optional, and a part left unset changes nothing.

The canvas holds a whole style, set piece by piece through `canvas.fill`,
`canvas.stroke` and the other style setters, read by every render call
until changed and rebuilt fresh each frame. A `Style` is a reusable set
of changes to it: `with canvas.style(s):` applies the parts `s` sets,
keeps the rest, and restores the whole style when the block ends.

```mojo
var label = Style(stroke_enabled=False, text_color=Color.WHITE, font_size=24)
with canvas.style(label):
    canvas.text("Score", (0, canvas.top() - 20))
```

A shadow is part of the style too, so a card's look can carry its own:

```mojo
var card = Style(
    fill=Color.WHITE,
    stroke_enabled=False,
    shadow=Color(0, 0, 0, 80),
    shadow_blur=16,
)
```

`over` layers one style over another, part by part:
`Style(corner_radius=4).over(card)` is the card with square corners.

`corner_radius` rounds the shapes the canvas builds from numbers --
`canvas.rectangle(p, w, h)`, `triangle`, `polygon` and `sector` -- unless
the call names its own `corner_radius`. A shape value carries its own
radius, so `canvas.draw(shape)` and `canvas.clip(shape)` ignore the
style's: what is drawn from a shape is what its `contains` tests.

The keywords are named after the canvas setters and act like them when
the style is applied: naming any part of the fill, stroke or shadow
switches it on (a part, not a modifier such as `stroke_alignment`,
`stroke_cap`, `stroke_dash` or `corner_radius`), unless `fill_enabled`,
`stroke_enabled` or `shadow_enabled` says otherwise, so
`Style(shadow=Color.RED, shadow_enabled=False)` keeps a shadow ready but
off. `fill_gradient` is the keyword for `fill`'s `Gradient` overload,
since one keyword can't take both: given beside `fill`, the gradient
paints and the colour is kept for when it is cleared.

Implements `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `Writable`.

## Fields

- `fill: Optional[Color]`
- `fill_gradient: Optional[Gradient]`
- `fill_enabled: Optional[Bool]`
- `stroke: Optional[Color]`
- `stroke_thickness: Optional[Float64]`
- `stroke_enabled: Optional[Bool]`
- `stroke_alignment: Optional[StrokeAlign]`
- `stroke_cap: Optional[StrokeCap]`
- `stroke_dash: Optional[StrokeDash]`
- `corner_radius: Optional[Float64]`
- `text_color: Optional[Color]`
- `font: Optional[Font]`
- `font_size: Optional[Float64]`
- `font_weight: Optional[FontWeight]`
- `font_italic: Optional[Bool]`
- `text_alignment: Optional[Align]`
- `tint: Optional[Color]`
- `opacity: Optional[Float64]`
- `blend_mode: Optional[BlendMode]`
- `shadow: Optional[Color]`
- `shadow_offset: Optional[Vector]`
- `shadow_blur: Optional[Float64]`
- `shadow_spread: Optional[Float64]`
- `shadow_inset: Optional[Bool]`
- `shadow_follows_transform: Optional[Bool]`
- `shadow_enabled: Optional[Bool]`

## Constructors

```mojo
@staticmethod
def __init__(
    out self,
    *,
    fill: Optional[Color] = None,
    fill_gradient: Optional[Gradient] = None,
    fill_enabled: Optional[Bool] = None,
    stroke: Optional[Color] = None,
    stroke_thickness: OptionalNumber = None,
    stroke_enabled: Optional[Bool] = None,
    stroke_alignment: Optional[StrokeAlign] = None,
    stroke_cap: Optional[StrokeCap] = None,
    stroke_dash: Optional[StrokeDash] = None,
    corner_radius: OptionalNumber = None,
    text_color: Optional[Color] = None,
    font: Optional[Font] = None,
    font_size: OptionalNumber = None,
    font_weight: Optional[FontWeight] = None,
    font_italic: Optional[Bool] = None,
    text_alignment: Optional[Align] = None,
    tint: Optional[Color] = None,
    opacity: OptionalNumber = None,
    blend_mode: Optional[BlendMode] = None,
    shadow: Optional[Color] = None,
    shadow_offset: Optional[Vector] = None,
    shadow_blur: OptionalNumber = None,
    shadow_spread: OptionalNumber = None,
    shadow_inset: Optional[Bool] = None,
    shadow_follows_transform: Optional[Bool] = None,
    shadow_enabled: Optional[Bool] = None,
)
```

## Methods

### `over`

```mojo
def over(self, base: Self) -> Self
```

This style layered over `base`: each part this style sets, and `base`'s for the rest. Applying the result is applying `base` and then this style, so a part named here switches on what `base` switched off: `Style(stroke=Color.RED).over(Style(stroke_enabled=False))` is stroked.

```mojo
var card = Style(fill=Color.WHITE, corner_radius=12)
var square = Style(corner_radius=0).over(card)  # white, square
```
