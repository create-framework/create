# StrokeDash

```mojo
struct StrokeDash
```

How a stroke is broken into dashes along its length.

| Value | Stroke |
|---|---|
| `SOLID` | Unbroken (the default) |
| `DASHED` | Dashes 3 thicknesses long, 2 apart |
| `DOTTED` | Round dots as wide as the stroke, 2 thicknesses apart |
| `StrokeDash(on, off)` | Dashes `on` long, `off` apart |
| `StrokeDash(on, off, on, off, ...)` | Up to four on/off pairs, repeated |

**A preset is a look; a constructor is exact control.** The presets
scale with the stroke's thickness, so they suit any stroke as they are.
A constructor's lengths are world units, scaled by autoscale, the
camera and the transform as the thickness is, and keep their spacing
whatever the thickness. A dot is a dash of no length: `DOTTED` is
always round, while `StrokeDash(0, 8)` takes `stroke_cap`, so it draws
dots under `ROUND`, squares under `SQUARE` and nothing under `BUTT`.

```mojo
canvas.stroke_dash(StrokeDash.DASHED)
with canvas.style(stroke_dash=StrokeDash(12, 4, 2, 4)):  # dash-dot
    canvas.circle((0, 0), 80)
```

**Where it starts.** A line starts at its start, a curve at its first
point, a polygon or triangle at its first vertex, all in their own
order. A rectangle starts at its top-left corner and a circle or
ellipse at its right-most point, both running counter-clockwise. A
sector starts at its tip, out along its start radius. `offset` starts
the pattern that far into itself, so raising it every frame marches the
dashes backwards along the stroke (`with_offset`). A closed outline
doesn't stretch the pattern to fit: where it comes back round, a dash
can meet a shorter one.

**Every dash is a stroke of its own:** `stroke_cap` finishes both its
ends, a region's dashes included, and a dash round a corner is mitred
as a solid stroke is. Dashes whose caps reach into each other overlap
there, which a translucent stroke shows. Lengths are measured along the
middle of the stroke, after `stroke_alignment` has placed it. The fill
still meets the stroke's inner edge, so a gap shows what is behind the
shape; `StrokeAlign.OUTSIDE` puts the fill under the gaps instead.

Set with `canvas.stroke_dash(dash)`, `Style(stroke_dash=)` or
`canvas.style(stroke_dash=)`; like all style it resets each frame.

Implements `Copyable`, `Deinitable`, `Equatable`, `ImplicitlyCopyable`, `Movable`, `Writable`.

## Constants

- `SOLID = StrokeDash(_kind=Int(0), _offset=Float64("0"))`
- `DASHED = StrokeDash(_preset=Int(1))`
- `DOTTED = StrokeDash(_preset=Int(2))`

## Constructors

```mojo
@staticmethod
def __init__(out self, on: Float64, off: Float64, *, offset: Float64 = Float64("0"))
```

Dashes `on` world units long, `off` apart, starting `offset` into the pattern. A negative length counts as none.

```mojo
@staticmethod
def __init__(out self, *lengths: Float64, *, offset: Float64 = Float64("0")) raises
```

The pattern `on, off, on, off, ...`, in world units, repeated along the stroke and starting `offset` into it. A negative length counts as none.

Raises unless `lengths` is whole on/off pairs, at most four of them.

## Methods

### `with_offset`

```mojo
def with_offset(self, offset: Float64) -> Self
```

This pattern starting `offset` world units into itself, for marching dashes: `dash.with_offset(context.time.elapsed * 20)`.

### `offset`

```mojo
def offset(self) -> Float64
```

How far into the pattern the stroke starts, in world units.

## Special methods

### `__eq__`

```mojo
def __eq__(self, other: Self) -> Bool
```

### `__ne__`

```mojo
def __ne__(self, other: Self) -> Bool
```
