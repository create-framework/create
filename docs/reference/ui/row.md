# Row

```mojo
struct Row
```

Widgets side by side, from the left, each in a slot of its own as tall as the row. The slots share the row's width in proportion to `weights`, one for each widget, so `Row(1, 3)` gives the first a quarter of it and the second three quarters; with no weights, every widget gets an equal slot. A `gap` is left between each slot and the next.

```mojo
# In `create`: a label and a slider for it, on one line of a column.
var line = ui.add(Row(1, 3), list)
_ = ui.add(Label("Volume", alignment=Align.LEFT), line)
var volume = ui.add(Slider(0.8, 0, 1), line)
```

In a column it is a strip as tall as its tallest widget, or `height`.
It fills the inside of the panel it is in, and elsewhere, with no
`rect` of its own, it is as big as what is inside it.

Implements `Copyable`, `Deinitable`, `Movable`.

## Fields

- `rect: Rectangle`: Where it is: given, or set by what it is in.
- `weights: List[Float64]`: How the slots share the width, left first; equal slots when empty.
- `gap: Optional[Float64]`: What is left between each slot and the next: the `UI`'s `spacing` when `None`.
- `height: Optional[Float64]`: How tall it is in a column: its tallest widget's height when `None`.

## Constructors

```mojo
@staticmethod
def __init__(
    out self,
    *weights: Float64,
    *,
    rect: Rectangle = Rectangle(Point(SIMD(0), SIMD(0)), SIMD(0), SIMD(0), corner_radius=_OptionalFloat64(SIMD(0)), rotation=_OptionalFloat64(SIMD(0))),
    gap: _OptionalFloat64 = None,
    height: _OptionalFloat64 = None,
)
```
