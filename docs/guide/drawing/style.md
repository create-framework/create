# Style

The style is everything about how a shape looks rather than where it is: its fill, its stroke,
its shadow, the font of its text, and how it blends with what is already on the screen. This page
explains how the style works as a whole: what it starts as, the three ways to change it, and the
settings that affect everything a **render call** (any call that draws, such as `canvas.circle` or
`canvas.text`) draws at once. The parts of the style each have a page of
their own:

- [Colours](colours.md): making a `Color`, and mixing and fading colours.
- [Strokes](strokes.md): the outline, where it sits, how its ends look, and dashes.
- [Gradients](gradients.md): fills that blend from one colour to another.
- [Shadows](shadows.md): drop shadows and inset shadows.
- [Text](text.md): fonts, alignment, lines and wrapping.

A style setting applies to every render call made after it, until the end of the frame or until
the `with` block it was set in ends.

## Defaults

**Shapes are not filled by default**, unlike in Processing. A new style has a black stroke, which
is switched on and 1 unit thick, and a white fill, which is switched off. Text is black. So a
shape drawn with no style at all is a thin black outline, which shows up on the light gray every
frame starts with (see [Drawing](drawing.md#the-background)).

## Fill, stroke and text colours

**The fill, the stroke and text each have their own colour**, set by `fill`, `stroke` and
`text_color`. Unlike in Processing, `fill` never colours text, and `fill_enabled(False)` doesn't
hide it; to hide text, give it a transparent `text_color`.

`fill_enabled(False)` and `stroke_enabled(False)` switch a part off but remember its colour.
`fill(color)` sets the colour and switches the fill on, and `fill()` with no arguments switches it
back on with the colour it had before (white, if it was never set). `stroke` and `shadow` work the
same way.

## Three ways to style

There are three ways to change the style, and they can be mixed and nested:

| Form | Effect |
|---|---|
| `canvas.fill(Color.RED)` (any setter) | Lasts for the rest of the frame |
| `with canvas.style(fill=Color.RED):` | Changes only the named parts, until the block ends |
| `with canvas.style(heading):` | Uses a whole `Style` value until the block ends. Parts it doesn't set are the `Style()` defaults, not what the style was before |

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

`Style(...)` takes the setters' names as keywords. As with the setters, naming any part of the
fill, stroke or shadow switches that part on, unless its `*_enabled` keyword says otherwise, so
`Style(fill=Color.RED)` is filled. A style you reuse is a field built in `create`, like `label`
above.

A keyword that takes a number (`blur`, `spread`, `thickness`, `font_size`, `opacity`) accepts a
whole number or a decimal alike, such as `12` or `1.5`.

**Corner radius** is part of the style only for shapes the canvas builds from numbers:
`canvas.corner_radius(radius)` rounds every `canvas.rectangle`, `triangle`, `polygon` and `sector`
drawn after it. A shape value keeps its own radius (see
[Corner radius](../geometry/shapes.md#corner-radius)), so
`with canvas.style(corner_radius=8): canvas.draw(rect)` does not round `rect`.

## Tint, opacity and blend modes

These three settings apply to everything a render call draws, images included, but never to
`background()`. A shape's fill and stroke never overlap, so a translucent shape is evenly
translucent, with no darker band where the two meet.

- **`canvas.tint(color)`** multiplies every colour of the call by `color`, channel by channel: the
  fill, a gradient's stops, the stroke, text, the shadow and each pixel of an image. White, the
  default, is no tint, and the tint's alpha multiplies with `opacity`. Where `fill`, `stroke` and
  `text_color` set one part each, a tint recolours the whole look at once; scope it with
  `with canvas.style(tint=...)`. Multiplying can only darken, so a tint can't flash a sprite white.
- **`canvas.opacity(a)`**, from 0 to 1, fades the whole call.
- **`canvas.blend_mode(mode)`** sets how the call combines with what is already drawn:

  | Mode | What it does |
  |---|---|
  | `NORMAL` | Paints over what is there (the default) |
  | `ADD` | Adds its colour to what is there, so overlaps grow brighter: glows, light, fire |
  | `SCREEN` | Brightens too, but more gently than `ADD`, so overlaps wash out less quickly |
  | `MULTIPLY` | Multiplies with what is there, so it can only darken: shade, ink, stains |
  | `SUBTRACT` | Takes its colour away from what is there, darkening towards black |
