# Style

How what you draw looks: colours, strokes, gradients, shadows, tint and blending, and text. A
style setting applies to every render call after it, until the end of the frame or the `with`
block it was set in.

## Defaults

**Shapes are not filled by default**, unlike in Processing. A new style has a black stroke, on and
1 unit thick, and a white fill that is switched off; text is black. So a shape drawn with no style
at all is a thin black outline, which shows on the light gray every frame starts with (see
[Drawing](drawing.md#the-background)).

## Colours

A `Color` is red, green and blue, each from 0 to 255, and an alpha from 0 (invisible) to 255
(opaque, the default):

```mojo
# In `update`:
canvas.fill(Color(255, 128, 0))  # orange
canvas.fill(Color(255, 128, 0, 128))  # orange, half transparent
canvas.fill(Color(200))  # one number is a gray
canvas.fill(Color.RED.with_alpha(64))  # a named colour, mostly transparent
canvas.fill(Color.hex("#336699"))  # as a design tool writes it
canvas.fill(Color.hsv(200, 0.8, 1.0))  # hue in degrees, saturation and value from 0 to 1
```

- The named colours are `BLACK`, `WHITE`, `DARK_GRAY`, `GRAY`, `LIGHT_GRAY`, `RED`, `GREEN`,
  `BLUE`, `CYAN`, `MAGENTA`, `YELLOW`, `ORANGE`, `PINK`, `PURPLE`, `BROWN` and `TRANSPARENT`.
- `Color.hex` also takes a number, `Color.hex(0x336699)`, and its string can carry alpha,
  `"#33669980"`.
- `a.lerp(b, t)` mixes two colours, `t` from 0 (all `a`) to 1 (all `b`).

**Fill, stroke and text have separate colours**, set by `fill`, `stroke` and `text_color`. Unlike
Processing, `fill` never colours text, and `fill_enabled(False)` doesn't hide it; a transparent
`text_color` does.

`fill_enabled(False)` and `stroke_enabled(False)` switch a part off and keep its colour.
`fill(color)` sets the colour and switches the fill on; `fill()` with no arguments switches it back
on with the colour it had (white, if never set). `stroke` and `shadow` work the same way.

## Three ways to style

They can be mixed and nested:

| Form | Effect |
|---|---|
| `canvas.fill(Color.RED)` (any setter) | Rest of the frame |
| `with canvas.style(fill=Color.RED):` | Only the named fields, for the block |
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

`Style(...)` takes the setters' names as keywords. Like the setters, naming any part of the fill,
stroke or shadow switches that part on, unless its `*_enabled` keyword says otherwise:
`Style(fill=Color.RED)` is filled. A reusable style is a field built in `create`, like `label`
above.

A number keyword (`blur`, `spread`, `thickness`, `font_size`, `opacity`) takes a whole or a
decimal number alike, `12` or `1.5`.

**Corner radius** is style only for shapes the canvas builds from numbers:
`canvas.corner_radius(radius)` rounds every `canvas.rectangle`, `triangle`, `polygon` and `sector`
drawn after it. A shape value keeps its own (see [`corner_radius`](geometry.md#corner-radius)), so
`with canvas.style(corner_radius=8): canvas.draw(rect)` does not round `rect`.

## Strokes

Strokes are style like the rest: `canvas.stroke(color, thickness)` and `stroke_enabled`, plus three
settings: where the stroke sits (`stroke_alignment`), how its ends look (`stroke_cap`) and dashes
(`stroke_dash`).

**`stroke_alignment(StrokeAlign.INSIDE/CENTER/OUTSIDE)`** puts a region's stroke inside its edge
(the default; Processing centres it), centred on it, or outside it. The fill always stops where
the stroke starts, so with `OUTSIDE` the fill covers the whole shape.

- Regions only (rectangle, circle, triangle, sector, polygon): lines and curves have no inside and
  are always centred. A self-crossing polygon's seams (edges through its inside) stay centred
  under every alignment.
- With `INSIDE`, nothing is drawn outside the shape, so what you see matches what `contains`,
  `overlaps` and `clip` use.
- Shadows and a gradient fill follow the shape, not the stroke: the gradient spans the true shape
  whatever the alignment.

**`stroke_cap(StrokeCap.BUTT/ROUND/SQUARE)`** sets how an open stroke ends — a `Line`, `Arc`,
`Bezier` or open `Spline`: `BUTT` (the default) stops flush at the end point, `ROUND` adds a half
disc, and `SQUARE` reaches half the thickness further, square.

- A closed curve and a shape's stroke have no ends, unless dashed: then every dash has two.
- A zero-length line draws nothing with `BUTT`, a dot with `ROUND` and an axis-aligned square with
  `SQUARE`.
- Caps composite with the stroke once, translucent or not, and are part of its shadow, so
  segments drawn end to end with `ROUND` meet without notches.

**`stroke_dash(...)`** breaks every stroke into dashes, regions' included. The presets scale with
the stroke's thickness; `StrokeDash(...)` takes exact lengths, in the same units as the
thickness:

| Value | Stroke |
|---|---|
| `StrokeDash.SOLID` | Unbroken (the default) |
| `StrokeDash.DASHED` | Dashes 3 thicknesses long, 2 apart |
| `StrokeDash.DOTTED` | Round dots as wide as the stroke, 2 thicknesses apart |
| `StrokeDash(12, 6)` | Dashes 12 long, 6 apart |
| `StrokeDash(12, 4, 2, 4)` | Up to four on/off pairs, repeated (dash-dot here) |

```mojo
# In `update`: marching ants round a selection.
var ants = StrokeDash(6, 6).with_offset(context.time.elapsed * 20)
with canvas.style(stroke=Color.BLACK, fill_enabled=False, stroke_dash=ants):
    canvas.draw(self.selection)
```

- **Each dash is a stroke of its own:** `stroke_cap` finishes both its ends, and one round a corner
  is mitred. A dot is a dash of no length, so `StrokeDash(0, 8)` draws dots under `ROUND`, squares
  under `SQUARE` and nothing under `BUTT`; `DOTTED` is round whatever the cap. Caps that reach into
  each other overlap, which a translucent stroke shows.
- **Where it starts:** a line at its start, a curve at its first point, a polygon or triangle at
  its first vertex, in their own order; a rectangle at its top-left corner and a circle or ellipse
  at its right-most point, counter-clockwise; a sector at its tip, out along its start radius.
  `offset` starts that far into the pattern, so raising it marches the dashes back along the stroke.
  A closed outline doesn't stretch the pattern to fit, so a dash can meet a shorter one where it
  comes round.
- **Lengths run along the middle of the stroke**, after `stroke_alignment` has placed it. The fill
  still meets the stroke's inner edge, so a gap shows what is behind the shape; with `OUTSIDE` the
  fill lies under the gaps.
- **Shadows:** a stroke alone casts its dashes; a filled shape casts its whole silhouette, gaps
  included.
- A pattern repeating in under a device pixel can't be seen and is drawn solid.

## Gradients

A `Gradient` fills regions and backgrounds: `canvas.fill(gradient)` and
`canvas.background(gradient)` are overloads beside the colour ones. Build one in `create` and
keep it as a field (or in a `Style`), since building one does work up front that drawing it
reuses.

```mojo
# In `create`, building the `sky` and `glow` fields:
var sky = Gradient.linear(Color(20, 30, 80), Color(250, 150, 90))  # top to bottom
var glow = Gradient.radial(Color.WHITE, Color.TRANSPARENT)

# In `update`:
canvas.background(self.sky)
with canvas.style(fill_gradient=self.glow, stroke_enabled=False):
    canvas.circle((0, 0), 80)
```

A gradient is its stops (0..1 positions, each a `Color`) and how it runs:

- **It stretches to fit each shape it fills** (the shape's bounding box, before the transform), so
  it moves and turns with the shape, and one gradient suits shapes of every size. A sector's box is
  its whole circle.
- `linear` runs along `direction` (a `Vector2D`, default `DOWN`, any length); the box's extreme
  corners land on 0 and 1, as in CSS. `Gradient.linear([(0.0, Color.BLUE), (0.7, Color.PURPLE),
  (1.0, Color.ORANGE)])` places the stops; given colours alone, they are spread evenly.
- `radial` runs from `center` in the box's unit space (-1..1, y up) out to its edges: an ellipse
  on a long box.
- A zero `direction` or a zero-size box paints the first stop.
- A fade to `TRANSPARENT` stays clean, with no dark fringe, and a gradient is dithered against
  banding on both backends.

How it combines with the rest of the style:

- In `Style` and `canvas.style`, the keyword is `fill_gradient=`, not `fill=`. Given `fill=` and
  `fill_gradient=` together, the gradient wins.
- While a gradient is set it fills instead of the fill colour, which is kept. `fill(color)`
  removes the gradient; `fill()` and `fill_enabled(...)` keep it.
- It fills only. Strokes, lines, curves and text ignore it, and a shadow stays the silhouette in
  `shadow_color` (a fill fading to transparent still casts a full shadow).
- `background(gradient)` spans the screen (`left()`…`top()`), ignoring the camera.

## Shadows

Shadows are part of the style and **off by default**. `canvas.shadow(color=, offset=, blur=,
spread=, inset=)` switches one on; parts left unset keep their values, so `shadow()` alone
switches the current one back on. `shadow_enabled(False)` switches it off, and `canvas.style(...)`
takes the same parts as `shadow*` keywords (`shadow=` for the colour):

```mojo
# In `update`:
with canvas.style(shadow=Color(0, 0, 0, 120), shadow_blur=12):
    canvas.rectangle((0, 0), 200, 120)
```

- **One silhouette, like CSS `drop-shadow`:** fill and stroke cast together (a stroke alone casts
  a ring); lines and arcs cast their stroke, text its glyphs, images their alpha. A translucent
  fill shows its own shadow through it. The clear, the background and the letterbox never cast.
- **`blur` is the CSS radius** (σ = blur / 2). `blur` and `spread` are in units, scaled like
  coordinates. Blur 0 is hard.
- **`shadow_inset`** paints inside the shape instead, after it, clipped to the interior within the
  stroke. Rectangles, circles and triangles only: sectors, polygons, lines, arcs, text and images
  cast nothing while it is set.
- **The offset is screen-fixed** by default (`(4, -4)`, down-right): rotation doesn't turn it, but
  camera zoom and autoscale scale it. `shadow_follows_transform(True)` turns it with the shape.
- Shadows use the render call's own tint, opacity and blend mode.

## Tint, opacity and blend modes

These apply to every render call, images included, but never to `background()`. A shape's fill
and stroke never overlap, so a translucent shape is evenly translucent, with no darker band where
they meet.

- **`canvas.tint(color)`** multiplies every colour of the call — fill, gradient stops, stroke,
  text, shadow, each image texel — channel by channel. White (the default) is no tint, and its
  alpha multiplies with `opacity`. It recolours a whole look at once, where `fill`, `stroke` and
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
# In `create`, loading the `title_font` field:
var title_font = Font.load("fonts/Title.ttf")

# In `update`:
with canvas.style(font=self.title_font, font_size=48, font_weight=FontWeight.BOLD):
    canvas.text("Game over", (0, 0))
```

- A `Font` is kept as a field, like an `Image`: a shared asset, cheap to copy, closed when its
  last copy goes.
- With no font set, text is the packaged Noto Sans, and a character the face lacks falls back to
  Noto Sans Symbols.
- Different `text` calls in one frame can use different fonts. Like every style setter,
  `canvas.font` resets next frame. Switching fonts costs nothing.

**Italic** is `canvas.font_italic(True)` (or the `font_italic=` keyword), and always slants, from
the best source the font has: the `italic_path` file of `Font.load(path, italic_path=...)` (the
packaged Noto Sans ships its italic this way), else the file's own `ital` or `slnt` axis, else its
upright glyphs sheared 12°. Fallback glyphs follow, so Noto Sans Symbols comes out sheared. Weights
apply to italic text as to upright text. `text_width` ignores the slant, as in CSS, so italic text
can stick out slightly past it.

**Alignment.** `canvas.text_alignment(Align.CENTER)`, the default, centres the text on its
position, like every shape. The other eight values name the point of the text's box that lands on
the position: `TOP`, `BOTTOM`, `LEFT` and `RIGHT` are the middles of its edges, and `TOP_LEFT`,
`TOP_RIGHT`, `BOTTOM_LEFT` and `BOTTOM_RIGHT` its corners. So `Align.TOP_LEFT` hangs the text below
and to the right of the position.

**Lines.** A newline (`"\n"`, or `"\r\n"`) in the string starts a new line, the font's line
height below. Each line is aligned on its own by `text_alignment`, whose top and bottom are those
of the whole block. `canvas.text_width(string)` is the widest line's width, and
`canvas.text_height(string)` the block's height, from the first line's ascent to the last line's
descent:

```mojo
# In `update`: a two-line caption hanging from the top-left corner,
# and a line under it.
var caption = "Level 1\nThe caves"
var corner = Point2D(canvas.left() + 20, canvas.top() - 20)
canvas.text_alignment(Align.TOP_LEFT)
canvas.text(caption, corner)
var under = corner.y - canvas.text_height(caption) - 4
canvas.line((corner.x, under), (corner.x + canvas.text_width(caption), under))
```

**Wrapping.** `canvas.text(string, position, width)` also wraps each line to at most `width`
units, breaking at the last space that fits and dropping the spaces there; a word wider than
`width` alone breaks between its letters. Newlines still break, and every line is still aligned
on its own, so `Align.TOP_LEFT` sets ragged-right text hanging from `position`.
`canvas.text_width(string, width=w)` and `canvas.text_height(string, width=w)` measure the wrapped
block:

```mojo
# In `update`: a paragraph in a 300-unit column, a panel behind it.
var story = "The caves run deeper than the old maps show, and nobody who went down came back."
canvas.text_alignment(Align.TOP_LEFT)
var corner = Point2D(canvas.left() + 20, canvas.top() - 20)
var height = canvas.text_height(story, width=300)
canvas.fill(Color(0, 0, 0, 160))
canvas.rectangle((corner.x + 150, corner.y - height / 2), 300, height)
canvas.text_color(Color.WHITE)
canvas.text(story, corner, 300)
```
