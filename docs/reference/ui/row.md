# Row

```mojo
struct Row
```

Widgets side by side, from the left, each as tall as the row and as wide as it prefers, or as the `width` it was added with.

A `gap` is left between each widget and the next. The room left over
goes to the widgets added with a `grow`, shared in proportion to it:

```mojo
# In `create`: a label and a slider for it, on one line of a column.
var line = ui.add(Row(), list)
_ = ui.add(Label("Volume", alignment=Align.LEFT), line)
var volume = ui.add(Slider(0.8, 0, 1), line, grow=1)  # the rest
```

In a column it is a strip as tall as its tallest widget, or the
`height` it was added with. It fills the inside of the panel it is in,
and elsewhere, with no `rect` of its own, it is as big as what is
inside it.

Implements `Copyable`, `Deinitable`, `Movable`.

## Fields

- `rect: Rectangle`: Where it is: given, or set by what it is in.
- `gap: Optional[Float64]`: What is left between each widget and the next: the `UI`'s `spacing` when `None`.

## Constructors

```mojo
@staticmethod
def __init__(
    out self,
    rect: Rectangle = Rectangle(Point(SIMD(0), SIMD(0)), SIMD(0), SIMD(0), corner_radius=OptionalNumber(SIMD(0)), rotation=OptionalNumber(SIMD(0))),
    *,
    gap: OptionalNumber = None,
)
```
