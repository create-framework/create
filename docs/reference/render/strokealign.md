# StrokeAlign

```mojo
struct StrokeAlign
```

Where a region's stroke sits against the shape's edge.

| Alignment | Stroke |
|---|---|
| `INSIDE` | Within the shape, its outer edge on the shape's (the default) |
| `CENTER` | Centred on the edge, half its thickness either side |
| `OUTSIDE` | Around the shape, its inner edge on the shape's |

The fill always meets the stroke's inner edge, so `OUTSIDE` leaves the
fill the whole shape and `INSIDE` erodes it by the thickness. The
default keeps what is drawn within what `contains`, `overlaps` and
`clip` see. Only regions have an inside: a rectangle, circle, triangle,
sector or polygon. Lines and curves are always stroked centred, and a
self-crossing polygon's seams (edges running through its inside) stay
centred too.

Set with `canvas.stroke_alignment(alignment)`, `Style(stroke_alignment=)`
or `canvas.style(stroke_alignment=)`; like all style it resets each
frame. A type of its own, so a bare number never passes for one.

Implements `Copyable`, `Deinitable`, `Equatable`, `ImplicitlyCopyable`, `Movable`, `Writable`.

## Constants

- `INSIDE = StrokeAlign(Int(0))`
- `CENTER = StrokeAlign(Int(1))`
- `OUTSIDE = StrokeAlign(Int(2))`

## Fields

- `value: Int`

## Constructors

```mojo
@staticmethod
def __init__(out self, value: Int)
```

## Special methods

### `__eq__`

```mojo
def __eq__(self, other: Self) -> Bool
```

### `__ne__`

```mojo
def __ne__(self, other: Self) -> Bool
```
