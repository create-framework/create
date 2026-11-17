# Strokes

The stroke is the line drawn along a shape's edge, or along a line or curve, which has no edge
other than itself. This page covers its colour and thickness, where it sits against a shape's
edge, how its ends look, and how to break it into dashes.

## Colour and thickness

`canvas.stroke(color, thickness)` sets the stroke's colour and thickness, in units, and switches
it on. `stroke_enabled(False)` switches it off while remembering both, and `stroke()` with no
arguments switches it back on. A new style has a black stroke 1 unit thick. In `Style` and
`canvas.style(...)` the keywords are `stroke=` and `stroke_thickness=`.

The stroke has three more settings: where it sits (`stroke_alignment`), how its ends look
(`stroke_cap`), and whether it is broken into dashes (`stroke_dash`).

## Where the stroke sits

**`stroke_alignment(...)`** decides where a shape's stroke sits against its edge: inside it
(`StrokeAlign.INSIDE`, the default), centred on it (`StrokeAlign.CENTER`), or outside it
(`StrokeAlign.OUTSIDE`). Processing always centres the stroke, so a shape stroked there is larger
than its numbers say by half the stroke's thickness. With `INSIDE`, a shape is exactly as big as
its numbers say, however thick the stroke.

The fill always stops where the stroke starts, so with `OUTSIDE` the fill covers the whole shape.

- Alignment applies only to regions, the shapes with an inside: rectangles, circles, ellipses,
  capsules, triangles, sectors and polygons. Lines and curves have no inside, so their stroke is
  always centred. A self-crossing polygon's seams, the edges that run through its inside, stay
  centred under every alignment.
- With `INSIDE`, nothing is drawn outside the shape, so what you see is exactly what `contains`,
  `overlaps` and `clip` use.
- Shadows and a gradient fill follow the shape, not the stroke, so a gradient spans the true shape
  whatever the alignment.

## How the ends look

**`stroke_cap(...)`** sets how an open stroke ends, that is, the stroke of a `Line`, `Arc`,
`Bezier` or open `Spline`:

| Cap | End |
|---|---|
| `StrokeCap.BUTT` | Stops flush at the end point (the default) |
| `StrokeCap.ROUND` | Adds a half disc round the end point |
| `StrokeCap.SQUARE` | Reaches half the thickness past the end point, square |

- A closed curve and a shape's stroke have no ends, unless they are dashed: then every dash has two.
- A line of zero length draws nothing with `BUTT`, a dot with `ROUND`, and an upright square with
  `SQUARE`.
- The caps are blended onto the frame together with the stroke, as one, whether it is translucent
  or not, and are part of its shadow. So segments drawn end to end with `ROUND` caps meet without
  notches.

## Dashes

**`stroke_dash(...)`** breaks a stroke into dashes, on every kind of shape. The presets scale with
the stroke's thickness, so they look the same on a thin stroke and a thick one, and
`StrokeDash(...)` takes exact lengths, in the same units as the thickness:

| Value | Stroke |
|---|---|
| `StrokeDash.SOLID` | Unbroken (the default) |
| `StrokeDash.DASHED` | Dashes 3 thicknesses long, 2 apart |
| `StrokeDash.DOTTED` | Round dots as wide as the stroke, 2 thicknesses apart |
| `StrokeDash(12, 6)` | Dashes 12 long, 6 apart |
| `StrokeDash(12, 4, 2, 4)` | Up to four pairs of dash and gap lengths, repeated (dash-dot here) |

```mojo
# In `update`: marching ants round a selection.
var ants = StrokeDash(6, 6).with_offset(context.time.elapsed * 20)
with canvas.style(stroke=Color.BLACK, fill_enabled=False, stroke_dash=ants):
    canvas.draw(self.selection)
```

**Each dash is a stroke of its own.** `stroke_cap` finishes both its ends, and a dash that runs
round a corner turns it with a sharp, pointed join. A dot is a dash of no length, so
`StrokeDash(0, 8)` draws dots under `ROUND`, squares under `SQUARE` and nothing under `BUTT`;
`DOTTED` is round whatever the cap. Caps that reach into each other overlap, which shows on a
translucent stroke.

**Where the pattern starts** depends on the shape, and from there it runs along the outline:

- a line from its start, and a curve from its first point;
- a polygon or triangle from its first vertex, through the others in their order;
- a rectangle from its top-left corner, and a circle or ellipse from its right-most point, both
  counter-clockwise;
- a sector from its tip, out along its start radius.

`with_offset(offset)` starts the pattern that far into it, so raising the offset a little every
frame moves the dashes back along the stroke, as the marching ants above do. On a closed outline
the pattern isn't stretched to fit, so where it comes round to its start a dash can meet a
shorter one.

A few more details:

- **Lengths are measured along the middle of the stroke**, after `stroke_alignment` has placed
  it. The fill still meets the stroke's inner edge, so a gap shows what is behind the shape; with
  `OUTSIDE` the fill lies under the gaps.
- **Shadows:** a stroke alone casts its dashes, while a filled shape casts its whole silhouette,
  gaps included.
- A pattern that repeats in less than a pixel on the screen couldn't be seen, so it is drawn solid.
