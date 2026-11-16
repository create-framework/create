# Antialiasing

```mojo
struct Antialiasing
```

How smoothly the edges of shapes are drawn.

`run`'s `antialiasing` argument is the starting level; `canvas.antialiasing`
changes it for the whole frame it is called in and every later one.

The levels name a quality, not a technique, because each backend reaches
it its own way:

| Level | GPU (MSAA samples) | CPU (samples per pixel) |
|---|---|---|
| `OFF` | none | 1, the pixel centre |
| `LOW` | 2 | 2 x 2 |
| `MEDIUM` | 4 | 4 x 4 |
| `HIGH` | 8 | 8 x 8 |

The GPU draws the frame into an offscreen multisampled framebuffer and
resolves it into the window (or a headless target), capped at the
driver's maximum sample count. The CPU replays each shape through its own
rasteriser on a grid that much finer and composites the coverage once,
fill and stroke together, so a shape's edge has no seam between the two.
Shapes only: text and images are smooth already. A clip's edge is
antialiased like a shape's on both. Pixel reads and `save_image` replay
on the CPU at the same level, under either backend.

Implements `Copyable`, `Deinitable`, `Equatable`, `ImplicitlyCopyable`, `Movable`, `Writable`.

## Constants

- `OFF = Antialiasing(Int(0))`: Hard, aliased edges.
- `LOW = Antialiasing(Int(1))`: Some smoothing, at little cost.
- `MEDIUM = Antialiasing(Int(2))`: Smooth edges. The default.
- `HIGH = Antialiasing(Int(3))`: The smoothest edges, at the most cost.

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
