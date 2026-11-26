# ScrollArea

```mojo
struct ScrollArea
```

A window onto a column of widgets, showing the part of it that fits.

Add one column inside it. The column is as tall as its widgets, and
the window shows the part of it `offset` down from its top; what falls
outside the window is neither drawn nor clicked.

```mojo
# In `create`: a list of levels, never taller than 240.
var window = ui.add(ScrollArea(max_height=240), column)
var levels = ui.add(Column(), window)
for name in ["Forest", "Caves", "Castle", "Sky", "Moon"]:
    _ = ui.add(Button(name), levels)

# In `update`: back to the top.
self.ui[self.window].offset = 0
```

With no `rect` of its own it is as wide as its column, and as tall as
it too, up to `max_height`. In a column or row it can `grow` to fill
the room left over, like any other widget.

Implements `Copyable`, `Deinitable`, `Movable`.

## Fields

- `rect: Rectangle`: Where the window is: given, or set by what it is in.
- `offset: Float64`: How far down its column the window shows, from 0 at the top. Each layout keeps it between 0 and as far as the column goes.
- `max_height: Optional[Float64]`: The tallest it grows to fit its column, with no `rect` of its own: as tall as the column when `None`.

## Constructors

```mojo
@staticmethod
def __init__(
    out self,
    rect: Rectangle = Rectangle(Point(SIMD(0), SIMD(0)), SIMD(0), SIMD(0), corner_radius=OptionalNumber(SIMD(0)), rotation=OptionalNumber(SIMD(0))),
    *,
    max_height: OptionalNumber = None,
)
```
