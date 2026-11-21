# Style

```mojo
struct Style
```

How the next shape or glyph is painted, independent of where it goes.

The canvas holds one, set piece by piece through `canvas.fill`,
`canvas.stroke` and the other style setters, read by every render call
until changed and rebuilt fresh each frame. A program can also build its
own and apply it whole with `canvas.style(s)`, to reuse one look across
render calls, frames or entities:

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
    shadow=Shadow(Color(0, 0, 0, 80), blur=16),
)
```

`corner_radius` rounds the shapes the canvas builds from numbers --
`canvas.rectangle(p, w, h)`, `triangle`, `polygon` and `sector` -- unless
the call names its own `corner_radius`. A shape value carries its own
radius, so `canvas.draw(shape)` and `canvas.clip(shape)` ignore the
style's: what is drawn from a shape is what its `contains` tests.

The constructor's keywords are named after the canvas setters and act
like them: naming any part of the fill, stroke or shadow switches it
on (a part, not a modifier such as `stroke_alignment`, `stroke_cap`,
`stroke_dash` or `corner_radius`),
unless `fill_enabled`, `stroke_enabled` or `shadow_enabled` says
otherwise, so `Style(shadow=Shadow(Color.RED), shadow_enabled=False)`
keeps a shadow ready but off. `fill_gradient` is the keyword for `fill`'s
`Gradient` overload, since one keyword can't take both: given beside
`fill`, the gradient paints and the colour is kept for when it is
cleared. Every part left unset is what a fresh frame starts with.

Implements `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `Writable`.

## Fields

- `fill_color: Color`
- `fill_gradient: Optional[Gradient]`: Paints the fill instead of `fill_color` while set; `fill_color` is kept for when it is cleared.
- `fill_enabled: Bool`
- `stroke_color: Color`
- `stroke_thickness: Float64`
- `stroke_enabled: Bool`
- `stroke_alignment: StrokeAlign`: Where a region's stroke sits against its edge; `INSIDE` unless set. Lines and curves are always stroked centred.
- `stroke_cap: StrokeCap`: How the open ends of lines and curves are finished; `BUTT` unless set. Regions' strokes and closed curves have no ends, unless dashed.
- `stroke_dash: StrokeDash`: How the stroke is broken into dashes; `SOLID` unless set.
- `corner_radius: Float64`: How far the shapes the canvas builds from numbers are rounded, in world units; 0 is sharp. A shape value keeps its own.
- `text_color: Color`
- `font: Optional[Font]`: The face text is drawn in; none for the packaged Noto Sans.
- `font_size: Float64`
- `font_weight: FontWeight`
- `font_italic: Bool`
- `text_alignment: Align`
- `tint: Color`
- `opacity: Float64`
- `blend_mode: BlendMode`
- `shadow: Optional[Shadow]`: The shadow cast while `shadow_enabled`; none unless set.
- `shadow_enabled: Bool`

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
    stroke_thickness: _OptionalFloat64 = None,
    stroke_enabled: Optional[Bool] = None,
    stroke_alignment: StrokeAlign = StrokeAlign.INSIDE,
    stroke_cap: StrokeCap = StrokeCap.BUTT,
    stroke_dash: StrokeDash = StrokeDash.SOLID,
    corner_radius: _OptionalFloat64 = None,
    text_color: Color = Color.BLACK,
    font: Optional[Font] = None,
    font_size: _OptionalFloat64 = None,
    font_weight: FontWeight = FontWeight.REGULAR,
    font_italic: Bool = False,
    text_alignment: Align = Align.CENTER,
    tint: Color = Color.WHITE,
    opacity: _OptionalFloat64 = None,
    blend_mode: BlendMode = BlendMode.NORMAL,
    shadow: Optional[Shadow] = None,
    shadow_enabled: Optional[Bool] = None,
)
```
