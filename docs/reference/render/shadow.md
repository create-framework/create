# Shadow

```mojo
struct Shadow
```

A shadow cast by what is rendered: a darkened copy of its silhouette, offset and softened, as CSS's `drop-shadow` is.

Every part has a default, so `Shadow()` is a soft, translucent black
shadow down and to the right. Set it with `canvas.shadow(...)`,
`Style(shadow=)` or `canvas.style(shadow=)`:

```mojo
with canvas.style(shadow=Shadow(Color(0, 0, 0, 120), blur=12)):
    canvas.rectangle((0, 0), 200, 120)
```

`color` is the shadow's colour; a translucent black darkens what is
behind it rather than covering it. `offset` is how far it sits from its
shape, `(4, -4)`: down and to the right, since y is up. It is fixed to
the screen unless `follows_transform`, which turns it with the shape.
`blur` is how far the fade from shadow to nothing reaches, the CSS blur
radius; 0 gives a hard edge. `spread` grows the silhouette before it is
blurred. `blur`, `spread` and the offset are world units, scaled like a
coordinate.

`inset=True` paints the shadow inside the shape instead, over its fill
and within its stroke, as if the shape were a hole cut in a surface.
Only rectangles, circles and triangles take an inset shadow; other
shapes, text and images cast none while it is set.

Implements `Copyable`, `Deinitable`, `Equatable`, `ImplicitlyCopyable`, `Movable`, `Writable`.

## Fields

- `color: Color`
- `offset: Vector`
- `blur: Float64`
- `spread: Float64`
- `inset: Bool`
- `follows_transform: Bool`

## Constructors

```mojo
@staticmethod
def __init__(
    out self,
    color: Color = Color(UInt8(0), UInt8(0), UInt8(0), UInt8(96)),
    *,
    offset: Vector = Vector(Int(4), Int(-4)),
    blur: Float64 = 8,
    spread: Float64 = 0,
    inset: Bool = False,
    follows_transform: Bool = False,
)
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
