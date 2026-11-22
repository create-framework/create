# Theme

```mojo
struct Theme
```

The colours every widget draws from. A widget's look is worked out from them when it is drawn, so changing a colour changes every widget that uses it.

```mojo
# In `create`, building the `ui` field:
var ui = UI(Theme.dark(primary=Color.ORANGE))
```

Implements `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `Writable`.

## Fields

- `colors: ColorScheme`

## Constructors

### `light`

```mojo
@staticmethod
def light(
    *,
    primary: Optional[Color] = None,
    on_primary: Optional[Color] = None,
    secondary: Optional[Color] = None,
    on_secondary: Optional[Color] = None,
    tertiary: Optional[Color] = None,
    on_tertiary: Optional[Color] = None,
    error: Optional[Color] = None,
    on_error: Optional[Color] = None,
    surface: Optional[Color] = None,
    on_surface: Optional[Color] = None,
) -> Self
```

A theme of dark colours on a light background, with the colours given replacing its own.

A colour given also changes its container to a quieter mix of it
with the surface, and a colour given without its `on_` partner gets
black or white, whichever reads better on it. So this is enough to
make the buttons orange:

```mojo
# In `create`, building the `ui` field:
var ui = UI(Theme.light(primary=Color.ORANGE))
```

### `dark`

```mojo
@staticmethod
def dark(
    *,
    primary: Optional[Color] = None,
    on_primary: Optional[Color] = None,
    secondary: Optional[Color] = None,
    on_secondary: Optional[Color] = None,
    tertiary: Optional[Color] = None,
    on_tertiary: Optional[Color] = None,
    error: Optional[Color] = None,
    on_error: Optional[Color] = None,
    surface: Optional[Color] = None,
    on_surface: Optional[Color] = None,
) -> Self
```

A theme of light colours on a dark background, with the colours given replacing its own, as `Theme.light` does.

### `from_seed`

```mojo
@staticmethod
def from_seed(seed: Color, *, dark: Bool = False) -> Self
```

A whole theme worked out from one colour, as `ColorScheme.from_seed` does: light unless `dark`.
