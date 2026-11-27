# BlendMode

```mojo
struct BlendMode
```

How a shape, glyph or image combines with what is already rendered.

Set with `canvas.blend_mode` or the `blend_mode` keyword of
`canvas.style`/`Style`, and read by every render call after it, like any
other style setting. Each mode is a per-channel formula over the source
colour `s` and the colour already there, `d`, both as fractions of 255:

| Mode | Result | Looks like |
|---|---|---|
| `NORMAL` | `s` | Paint over paint: the default |
| `ADD` | `d + s` | Light: glows, sparks, fire. Only brightens |
| `SUBTRACT` | `d - s` | Removing light. Only darkens |
| `MULTIPLY` | `d * s` | Stacked tinted film: shadows. Only darkens |
| `SCREEN` | `1 - (1 - d) * (1 - s)` | Projected light. Only brightens, softer than `ADD` |

Results are clamped to `[0, 1]`. The source's alpha (after `opacity`)
scales how much of the effect shows, so a half-transparent `ADD` adds
half as much. The framebuffer's own alpha channel always composites
source-over, whatever the mode.

Modes apply to render calls, not to `canvas.background`, which always
paints normally. A shape's fill and its stroke overlap along the edge,
so under a mode that accumulates (`ADD`, `MULTIPLY`, ...) the overlap
shows twice; switch the stroke off for a clean glow. A shadow is
combined by its caster's mode, so under `ADD` it brightens rather than
darkens.

```mojo
with canvas.style(blend_mode=BlendMode.ADD, stroke_enabled=False):
    for p in self.sparks:
        canvas.circle(p.position, 6)
```

Implements `Copyable`, `Deinitable`, `Equatable`, `ImplicitlyCopyable`, `Movable`, `Writable`.

## Constants

- `NORMAL = BlendMode(Int(0))`
- `ADD = BlendMode(Int(1))`
- `MULTIPLY = BlendMode(Int(2))`
- `SUBTRACT = BlendMode(Int(3))`
- `SCREEN = BlendMode(Int(4))`

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
