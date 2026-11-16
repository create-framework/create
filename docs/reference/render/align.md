# Align

```mojo
struct Align
```

Which point of a box a position names — one value for both axes.

The nine constants are the nine points of the box, so a single argument
says everything `canvas.text_alignment` needs:

```
# # # # # # # # # # # # # # # # # # # # # #
# TOP_LEFT ———————— TOP ——————— TOP_RIGHT #
# |                  |                  | #
# |                  |                  | #
# LEFT —————————— CENTER —————————— RIGHT #
# |                  |                  | #
# |                  |                  | #
# BOTTOM_LEFT ——— BOTTOM ——— BOTTOM_RIGHT #
# # # # # # # # # # # # # # # # # # # # # #
```

The one-word constants name an edge's midpoint: `TOP` is top-centre,
`LEFT` is middle-left, `CENTER` is the middle of the box.

Edges of the box, not typographic baselines — there is no separate
`text_baseline`. `TOP` and `BOTTOM` mean the visual top and bottom even
though y grows upward, because glyphs are not flipped by the coordinate
system; only their anchor point is mapped.

Implements `Copyable`, `Deinitable`, `Equatable`, `ImplicitlyCopyable`, `Movable`, `Writable`.

## Constants

- `TOP = Align(Int(0))`
- `CENTER = Align(Int(1))`
- `BOTTOM = Align(Int(2))`
- `LEFT = Align(Int(3))`
- `RIGHT = Align(Int(4))`
- `TOP_LEFT = Align(Int(5))`
- `BOTTOM_LEFT = Align(Int(6))`
- `TOP_RIGHT = Align(Int(7))`
- `BOTTOM_RIGHT = Align(Int(8))`

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
