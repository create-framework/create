# Style

The style is everything about how a shape looks rather than where it is: its fill, its stroke, its
shadow, the font of its text and how it blends with what is already on the screen. This page
explains how the style works as a whole: what it starts as, the four ways to change it, and the
settings that affect everything a render call draws at once. (A **render call** is any call that
draws, such as `canvas.circle` or `canvas.text`.) The parts of the style each have a page of their
own:

- [Colours](colours.md): making a `Color`, and mixing and fading colours.
- [Strokes](strokes.md): the outline, where it sits, how its ends look and dashes.
- [Gradients](gradients.md): fills that blend from one colour to another.
- [Shadows](shadows.md): drop shadows and inset shadows.
- [Text](text.md): fonts, alignment, lines and wrapping.

A style setting applies to every render call made after it, until the end of the frame or until the
`with` block it was set in ends.

## Defaults

**Shapes are not filled by default**, unlike in Processing. A new style has a black stroke, which is
switched on and 1 unit thick, and a white fill, which is switched off. Text is black. So a shape
drawn with no style at all is a thin black outline, which shows up on the light grey every frame
starts with (see [The canvas](canvas.md#the-background)).

## Fill, stroke and text colours

**The fill, the stroke and text each have their own colour**, set by `fill`, `stroke` and
`text_color`. Unlike in Processing, `fill` never colours text, and `fill_enabled(False)` doesn't
hide it; to hide text, give it a transparent `text_color`.

`fill_enabled(False)` and `stroke_enabled(False)` switch a part off but remember its colour.
`fill(color)` sets the colour and switches the fill on, and `fill()` with no arguments switches it
back on with the colour it had before (white, if it was never set). `stroke` and `shadow` work the
same way.

## Four ways to style

There are four ways to change the style, and they can be mixed and nested:

| Form | Effect |
|---|---|
| `canvas.fill(Color.RED)` (any setter) | Lasts for the rest of the frame |
| `with canvas.style(fill=Color.RED):` | Changes only the named parts, until the block ends |
| `with canvas.style(heading):` | Changes the parts a `Style` value sets, until the block ends |
| `canvas.draw(shape, style=heading)` | Changes the parts a `Style` value sets, for that one call |

```mojo
from create import *


@fieldwise_init
struct Styles(Program):
    var label: Style
    var ring: Style

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> Styles:
        return Styles(
            Style(text_color=Color.BLUE, font_size=32),
            Style(fill=Color.BLUE, stroke_thickness=6),
        )

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        canvas.background(Color.WHITE)
        canvas.fill(Color.ORANGE)  # for the rest of the frame
        canvas.circle((-225, 0), 50)
        with canvas.style(stroke=Color.RED, stroke_thickness=6):
            canvas.circle((-75, 0), 50)  # orange, thick red stroke
        canvas.circle((75, 0), 50)  # orange, thin black stroke again
        canvas.draw(Circle((225, 0), 50), style=self.ring)  # blue, thick stroke
        with canvas.style(self.label):
            canvas.text("Four ways", (0, -120))


def main() raises:
    run[Styles]("Styles")
```

**A `Style` is a set of changes, kept to use again.** `Style(...)` takes the setters' names as
keywords, and holds only the parts it is given: `Style(text_color=Color.BLUE, font_size=32)` says
nothing about the fill or the stroke, so a shape drawn inside its block keeps the ones set before
it. So the two `with` forms do the same thing, and `with canvas.style(self.label):` is `with
canvas.style(text_color=..., font_size=...):` written once and kept. A style you reuse is a field
built in `create`, like `label` above.

**Give `canvas.draw` a style you have named**, `canvas.draw(button, style=ghost)`: it is applied
over the current style as a block's is, for that one call (see [Your own
types](canvas.md#your-own-types)). A style written out in the call reads better as a `with` block
around it, even for a single call.

As with the setters, naming any part of the fill, stroke or shadow switches that part on when the
style is applied, unless its `*_enabled` keyword says otherwise, so `Style(fill=Color.RED)` fills.

**`a.over(b)` layers one style over another:** each part `a` sets, and `b`'s for the rest. It is how
to make a variant of a look without repeating it:

```mojo
# In `create`, building the `card` and `selected` fields:
var card = Style(fill=Color.WHITE, stroke=Color.GRAY, corner_radius=12)
var selected = Style(stroke=Color.BLUE, stroke_thickness=3).over(card)
```

Printing a style shows only the parts it sets: `print(Style(fill=Color.RED))` prints
`Style(fill=Color(255, 0, 0, 255))`.

A keyword that takes a number (`stroke_thickness`, `shadow_blur`, `shadow_spread`, `font_size`,
`opacity` and the like) accepts a whole number or a decimal alike, such as `12` or `1.5`.

**Corner radius** is part of the style only for shapes the canvas builds from numbers:
`canvas.corner_radius(radius)` rounds every `canvas.rectangle`, `triangle`, `polygon` and `sector`
drawn after it. A shape value keeps its own radius (see [Corner
radius](../geometry/shapes.md#corner-radius)), so `with canvas.style(corner_radius=8):
canvas.draw(rect)` does not round `rect`.

## Colours by role

**A style can name a colour by what it is for,** with a `ColorRole`, wherever it takes a colour:
`Style(fill=ColorRole.PRIMARY)`, or `canvas.style(text_color=ColorRole.ON_SURFACE)`. The canvas's
colour scheme, `canvas.colors()`, says which colour each role is: the light scheme unless set with
`canvas.colors(scheme)`. The role becomes a colour when the style is applied, so a `Style` kept in a
field follows the scheme when it changes, and what was drawn before keeps its colours. The roles,
and the schemes, are the ones a `UI`'s widgets are drawn in (see [Themes and
styling](../ui/themes.md#colours)):

```mojo
# In `create`:
canvas.colors(ColorScheme.dark())

# In `update`, with a `banner: Style` field built in `create` as
# `Style(fill=ColorRole.PRIMARY, text_color=ColorRole.ON_PRIMARY)`:
canvas.background(canvas.colors().background)
with canvas.style(self.banner):
    canvas.rectangle((0, canvas.top() - 30), canvas.width(), 60)
    canvas.text("Level 1", (0, canvas.top() - 30))
```

The setters take a `Color`, since they change the style at once:
`canvas.fill(canvas.colors().primary)` fills in the scheme's primary colour.

## Tint, opacity and blend modes

These three settings apply to everything a render call draws, images included, but never to
`background()`. A shape's fill and stroke never overlap, so a translucent shape is evenly
translucent, with no darker band where the two meet.

- **`canvas.tint(color)`** multiplies every colour of the call by `color`, channel by channel: the
  fill, a gradient's stops, the stroke, text, the shadow and each pixel of an image. The default,
  white, leaves the colours as they are. The tint's alpha multiplies with `opacity`. Where `fill`,
  `stroke` and `text_color` each set one part, a tint recolours everything the call draws at once;
  to limit it to a few calls, set it with `with canvas.style(tint=...)`. Multiplying can only
  darken, so a tint can't flash a sprite white.
- **`canvas.opacity(a)`**, from 0 to 1, fades the whole call.
- **`canvas.blend_mode(mode)`** sets how the call combines with what is already drawn:

  | Mode | What it does |
  |---|---|
  | `NORMAL` | Paints over what is there (the default) |
  | `ADD` | Adds its colour to what is there, so overlaps grow brighter: glows, light, fire |
  | `SCREEN` | Brightens too, but more gently than `ADD`, so overlaps wash out less quickly |
  | `MULTIPLY` | Multiplies with what is there, so it can only darken: shade, ink, stains |
  | `SUBTRACT` | Takes its colour away from what is there, darkening towards black |
