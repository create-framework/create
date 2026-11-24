# Color

```mojo
struct Color
```

A colour: red, green and blue, each from 0 to 255, and an alpha from 0 (invisible) to 255 (opaque, the default).

`Color(200)` is a gray. Build one from text with `hex`, or from hue,
saturation and value with `hsv`; the named colours (`RED`, `TRANSPARENT`,
…) are constants. `with_alpha` and `lerp` derive new colours.

Implements `Copyable`, `Deinitable`, `Equatable`, `ImplicitlyCopyable`, `Movable`, `Writable`.

## Constants

- `TRANSPARENT = Color(UInt8(0), UInt8(0), UInt8(0), UInt8(0))`
- `BLACK = Color(UInt8(0))`
- `WHITE = Color(UInt8(255))`
- `DARK_GRAY = Color(UInt8(64))`
- `GRAY = Color(UInt8(128))`
- `LIGHT_GRAY = Color(UInt8(192))`
- `RED = Color(UInt8(255), UInt8(0), UInt8(0), UInt8(255))`
- `GREEN = Color(UInt8(0), UInt8(255), UInt8(0), UInt8(255))`
- `BLUE = Color(UInt8(0), UInt8(0), UInt8(255), UInt8(255))`
- `CYAN = Color(UInt8(0), UInt8(255), UInt8(255), UInt8(255))`
- `MAGENTA = Color(UInt8(255), UInt8(0), UInt8(255), UInt8(255))`
- `YELLOW = Color(UInt8(255), UInt8(255), UInt8(0), UInt8(255))`
- `ORANGE = Color(UInt8(255), UInt8(128), UInt8(0), UInt8(255))`
- `PINK = Color(UInt8(255), UInt8(128), UInt8(192), UInt8(255))`
- `PURPLE = Color(UInt8(128), UInt8(0), UInt8(255), UInt8(255))`
- `BROWN = Color(UInt8(128), UInt8(64), UInt8(0), UInt8(255))`

## Fields

- `r: UInt8`
- `g: UInt8`
- `b: UInt8`
- `a: UInt8`

## Constructors

```mojo
@staticmethod
def __init__(out self, r: UInt8, g: UInt8, b: UInt8, a: UInt8 = UInt8(255))
@staticmethod
def __init__(out self, gray: UInt8)
```

### `hex`

```mojo
@staticmethod
def hex(rgb: Int) -> Self
```

Build a color from a packed literal: `Color.hex(0x336699)`.

```mojo
@staticmethod
def hex(code: String) raises -> Self
```

Build a color from a CSS hex string: `Color.hex("#336699")`.

Accepts `#rgb`, `#rgba`, `#rrggbb` and `#rrggbbaa`; the leading `#` is
optional and case does not matter. The short forms double each digit,
as CSS does, so `"#f80"` is `"#ff8800"`. Alpha defaults to opaque.

This is the form to paste into from a design tool, and the only one
that carries alpha in a single token. `hex(Int)` stays the form for a
literal written in source, since a parse can raise and so cannot run
at compile time.

**Raises** If the string is not one of the four accepted lengths, or holds a
character that is not a hex digit.

### `hsv`

```mojo
@staticmethod
def hsv(h: Float64, s: Float64, v: Float64) -> Self
```

Build a color from hue in degrees (wraps) and saturation/value in 0..1.

Hue cycling is the point: `Color.hsv(Float64(context.frame_count()) % 360.0, 1.0, 1.0)`
sweeps the spectrum without hand-mixing channels.

### `oklch`

```mojo
@staticmethod
def oklch(lightness: Float64, chroma: Float64, hue: Float64) -> Self
```

Build a colour from OKLCH: perceived lightness from 0 (black) to 1 (white), chroma (how colourful, 0 for a grey, up to about 0.37 for the most vivid colours a screen shows) and hue in degrees (wraps).

Unlike HSV's value, equal steps of lightness look like equal steps
to the eye, whatever the hue: a yellow and a blue at the same
lightness look about as light as each other. A colour too vivid for
the screen to show is brought inside by lowering its chroma, keeping
its lightness and hue.

## Methods

### `luminance`

```mojo
def luminance(self) -> Float64
```

WCAG relative luminance, 0.0 (black) to 1.0 (white).

Answers "is this background light or dark" — the usual caller picks
black or white text against it, with 0.18 as the crossover.

### `to_hsv`

```mojo
def to_hsv(self) -> Tuple[Float64, Float64, Float64]
```

Inverse of `hsv`: hue in degrees, saturation and value in 0..1.

Hue is 0.0 for grays, which have none.

### `over`

```mojo
def over(self, dst: Self) -> Self
```

Composite this color over `dst`, source-over.

`self.a` decides how much of `self` shows through. Compositing over an
opaque color yields an opaque color, so this is what a background fill does
against the framebuffer.

Over a translucent `dst`, each color counts by how much of it shows:
`self` by its alpha, `dst` by its own alpha times what `self` leaves
uncovered. So a translucent color over a transparent one is itself,
not darkened towards the transparent color's channels.

### `with_alpha`

```mojo
def with_alpha(self, a: UInt8) -> Self
```

This color at a different opacity, 0 (invisible) to 255 (opaque).

The RGB channels are carried over untouched, so a named constant or a
computed color stays spelled once: `Color.RED.with_alpha(128)` rather
than respelling all three channels to change the fourth.

### `to_oklch`

```mojo
def to_oklch(self) -> Tuple[Float64, Float64, Float64]
```

Inverse of `oklch`: perceived lightness from 0 to 1, chroma, and hue in degrees from 0 to 360. Hue is 0.0 for greys, which have none.

### `lerp`

```mojo
def lerp(self, other: Self, t: Float64) -> Self
```

A new colour `t` of the way from this one to `other`, `t` clamped to 0..1; this one is unchanged. Mixes in sRGB, like a paint program's gradient — not perceptually uniform, but what the eye expects from two swatches.

## Special methods

### `__eq__`

```mojo
def __eq__(self, other: Self) -> Bool
```

### `__ne__`

```mojo
def __ne__(self, other: Self) -> Bool
```
