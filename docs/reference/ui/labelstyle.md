# LabelStyle

```mojo
struct LabelStyle
```

How a label's text looks, where it differs from the theme: the theme's `on_surface` colour and `body` text unless given.

Implements `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `Writable`.

## Fields

- `color: Optional[Color]`
- `text_style: Optional[TypeStyle]`

## Constructors

```mojo
@staticmethod
def __init__(
    out self,
    *,
    color: Optional[Color] = None,
    text_style: Optional[TypeStyle] = None,
)
```
