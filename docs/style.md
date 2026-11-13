# Style

How what you draw looks: colours, strokes, gradients, shadows, tint and blending, and text. A
style setting applies to every render call after it, until the end of the frame or the `with`
block it was set in.

## Defaults

`Style()` defaults are not blank: **stroke `BLACK`, on, 1 unit**; fill `WHITE`, off; `BLACK`
text. Every frame opens with a clear to gray 200 so those defaults are visible (see
[Drawing](drawing.md#the-background)). So a shape drawn with no style at all is a thin black
outline.

## Colours

`fill`, `stroke` and `text_color` set three independent colours: `fill_enabled(False)` does not
hide text, and text is hidden by a zero-alpha `text_color` instead.

`fill_enabled` and `stroke_enabled` switch a part off without losing its colour.
`fill(...)`, `stroke(...)` and `shadow(...)` switch it back on, and with no arguments keep every
part, so `fill()` alone paints the default white.

## Three ways to style

All three are additive:

| Form | Effect |
|---|---|
| `canvas.fill(Color.RED)` (any setter) | Rest of the frame |
| `with canvas.style(fill=Color.RED):` | Only the named fields, for the block (each goes through its setter) |
| `with canvas.style(heading):` | A whole `Style` value, for the block — unset fields are `Style()` defaults, not the previous style |

```mojo
from create import *


@fieldwise_init
struct Styles(Program):
    var label: Style

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> Styles:
        return Styles(Style(text_color=Color.BLUE, font_size=32))

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        canvas.background(Color.WHITE)
        canvas.fill(Color.ORANGE)  # for the rest of the frame
        canvas.circle((-150, 0), 50)
        with canvas.style(stroke=Color.RED, stroke_thickness=6):
            canvas.circle((0, 0), 50)  # orange, thick red stroke
        canvas.circle((150, 0), 50)  # orange, thin black stroke again
        with canvas.style(self.label):
            canvas.text("Three ways", (0, -120))


def main() raises:
    run[Styles]("Styles")
```

`Style(...)` takes the setters' names as keywords and, like them, naming any part of the fill,
stroke or shadow switches it on unless its `*_enabled` keyword says otherwise. A reusable style is
a field built in `create`, like `label` above.

A `Float64` keyword (`blur`, `spread`, `thickness`, `font_size`, `opacity`) takes `12`, `1.5`,
`None` or an `Optional[Float64]` alike. It is the internal `_OptionalFloat64`, since an integer
literal won't convert through `Optional[Float64]` in one step. Every optional keyword left unset
is `None`.

**Corner radius** is style only for shapes the canvas builds from numbers: `canvas.corner_radius(r)`
rounds the next `canvas.rectangle(...)`. A shape value keeps its own (see
[`corner_radius`](geometry.md)), so `with canvas.style(corner_radius=8): canvas.draw(rect)` does
not round `rect`.

## Strokes

Strokes are style like the rest: `canvas.stroke(color, thickness)`, `stroke_enabled`, and two
settings that place the paint.

**`stroke_alignment(StrokeAlign.INSIDE/CENTER/OUTSIDE)`** puts a region's stroke inside its edge
(the default), centred on it, or around it. The fill meets the stroke's inner edge, so `OUTSIDE`
leaves the whole shape to the fill.

- Regions only (rectangle, circle, triangle, sector, polygon): lines and curves have no inside and
  are always centred. A self-crossing polygon's seams (edges through its inside) stay centred
  under every alignment.
- `INSIDE` keeps drawn pixels within what `contains`, `overlaps` and `clip` see.
- Shadows and a gradient fill follow the shape, not the stroke: the gradient spans the true shape
  whatever the alignment.

**`stroke_cap(StrokeCap.BUTT/ROUND/SQUARE)`** ends an open stroke — a `Line`, `Arc`, `Bezier` or
open `Spline` — flush (the default), with a half disc, or half the thickness further, square.

- A closed curve and a shape's stroke have no ends.
- A zero-length line draws nothing with `BUTT`, a dot with `ROUND` and an axis-aligned square with
  `SQUARE`.
- Caps composite with the stroke once, translucent or not, and are part of its shadow, so
  segments drawn end to end with `ROUND` meet without notches.

## Gradients

A `Gradient` fills regions and backgrounds: `canvas.fill(gradient)` and
`canvas.background(gradient)` are overloads beside the colour ones. Build one in `create` and
keep it as a field (or in a `Style`): construction samples its colour ramp, and the GPU uploads
one ramp per distinct set of stops.

```mojo
# A fragment: `sky` is a field, built in `create`.
var sky = Gradient.linear(Color(20, 30, 80), Color(250, 150, 90))  # top to bottom
var glow = Gradient.radial(Color.WHITE, Color.TRANSPARENT)

# In `update`:
canvas.background(self.sky)
with canvas.style(fill_gradient=self.glow, stroke_enabled=False):
    canvas.circle((0, 0), 80)
```

A gradient is its stops (0..1 positions, each a `Color`) and how it runs:

- **Placed by the shape's local bounding box**, before the transform, so it moves and turns with
  the shape and one `Style` suits every entity. A sector's box is its whole circle.
- `linear` runs along `direction` (a `Vector2D`, default `DOWN`, any length); the box's extreme
  corners land on 0 and 1, as in CSS. `Gradient.linear([(0.0, Color.BLUE), (0.7, Color.PURPLE),
  (1.0, Color.ORANGE)])` places the stops; given colours alone, they are spread evenly.
- `radial` runs from `center` in the box's unit space (-1..1, y up) out to its edges: an ellipse
  on a long box.
- A zero `direction` or a zero-size box paints the first stop.
- It blends premultiplied, so a fade to `TRANSPARENT` stays clean, and is dithered on both
  backends.

How it combines with the rest of the style:

- In `Style` and `canvas.style`, the keyword is `fill_gradient=`, not `fill=`: one keyword can't
  take both types, and an `Optional[Paint]` wrapper would need two implicit conversions from a
  bare `Color`, which Mojo won't chain. Given `fill=` and `fill_gradient=` together, the gradient
  wins.
- While a gradient is set it fills, and `fill_color` is kept: `fill(color)` clears the gradient,
  while `fill()` and `fill_enabled(...)` keep it.
- It fills only. Strokes, lines, curves and text ignore it, and a shadow stays the silhouette in
  `shadow_color` (a fill fading to transparent still casts a full shadow).
- `background(gradient)` spans the screen (`left()`…`top()`), ignoring the camera, and replaces
  the autoclear only if every stop is opaque.

## Shadows

Shadows are part of the style and **off by default**. `canvas.shadow(color=, offset=, blur=,
spread=, inset=)` switches one on; parts left unset keep their values, so `shadow()` alone
switches the current one back on. `shadow_enabled(False)` switches it off, and `canvas.style(...)`
takes the same parts as `shadow*` keywords (`shadow=` for the colour):

```mojo
# A fragment of an `update`.
with canvas.style(shadow=Color(0, 0, 0, 120), shadow_blur=12):
    canvas.rectangle((0, 0), 200, 120)
```

- **One silhouette, like CSS `drop-shadow`:** fill and stroke cast together (a stroke alone casts
  a ring); lines and arcs cast their stroke, text its glyphs, images their alpha. A translucent
  fill shows its own shadow through it. The clear, the background and the letterbox never cast.
- **`blur` is the CSS radius** (σ = blur / 2). `blur` and `spread` are world units, scaled like
  coordinates. Blur 0 is hard.
- **`shadow_inset`** paints inside the shape instead, after it, clipped to the interior within the
  stroke. Rectangles, circles and triangles only: sectors, polygons, lines, arcs, text and images
  cast nothing while it is set.
- **The offset is screen-fixed** by default (`(4, -4)`, down-right): rotation doesn't turn it, but
  camera zoom and autoscale scale it. `shadow_follows_transform(True)` turns it with the shape.
- Shadows use the render call's own tint, opacity and blend mode.

## Tint, opacity and blend modes

These reach every render call, images included (`background()` never), and every shape composites
once: fill and stroke never overlap, so a translucent shape is evenly translucent.

- **`canvas.tint(color)`** multiplies every colour of the call — fill, gradient stops, stroke,
  text, shadow, each image texel — channel by channel. White (the default) is no tint, and its
  alpha stacks with `opacity`. It recolours a whole look at once, where `fill`, `stroke` and
  `text_color` set one part each; scope it with `with canvas.style(tint=...)`. Multiplying only
  darkens, so it can't flash a sprite white.
- **`canvas.opacity(a)`**, from 0 to 1, fades the whole call.
- **`canvas.blend_mode(mode)`** sets how the call combines with what is already drawn: `NORMAL`
  (the default), `ADD`, `MULTIPLY`, `SUBTRACT` or `SCREEN`.

## Text and fonts

`canvas.text(string, position)` draws text in the current text style. Fonts are part of the
style: `canvas.font(f)`, `Style(font=f)` or `with canvas.style(font=f):`, beside `font_size`,
`font_weight` and `font_italic`:

```mojo
# A fragment: `title_font` is a field, loaded in `create`.
var title_font = Font.load(source_path("fonts/Title.ttf"))

# In `update`:
with canvas.style(font=self.title_font, font_size=48, font_weight=FontWeight.BOLD):
    canvas.text("Game over", (0, 0))
```

- A `Font` is kept as a field, like an `Image`: a shared asset, cheap to copy, closed when its
  last copy goes.
- With no font set, text is the packaged Noto Sans, and a character the face lacks falls back to
  Noto Sans Symbols.
- Each `text` call keeps its face, so several share a frame. Like every style setter,
  `canvas.font` resets next frame. Switching faces costs nothing: cached glyphs are keyed by face.

**Italic** is `canvas.font_italic(True)` (or the `font_italic=` keyword), and always slants, from
the best source the font has: the `italic_path` file of `Font.load(path, italic_path=...)` (the
packaged Noto Sans ships its italic this way), else the file's own `ital` or `slnt` axis, else its
upright glyphs sheared 12°. Fallback glyphs follow, so Noto Sans Symbols comes out sheared. Weight
reaches a variable italic like an upright. A shear's overhang is not measured: `text_width` is the
advance, as in CSS.
