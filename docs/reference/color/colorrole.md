# ColorRole

```mojo
struct ColorRole
```

A colour named by what it is for, such as `ColorRole.PRIMARY`, rather than by its channels: the colour scheme in use decides which colour it is.

A `Style` takes a role wherever it takes a colour, so a look can be
written once and follow the scheme:

```mojo
# In `create`, building the `banner` field: a strip in the scheme's
# primary colour, whichever scheme is in use.
var banner = Style(
    fill=ColorRole.PRIMARY, text_color=ColorRole.ON_PRIMARY
)
```

The role is turned into a colour when the style is applied: by the
canvas's colours (`canvas.colors`) when it is drawn, and by a `UI`'s
colours when a widget is styled with it. There is a role for each of
`ColorScheme`'s colours, named as its field is, in capitals:
`ColorRole.SURFACE_CONTAINER` is `scheme.surface_container`.

Implements `Copyable`, `Deinitable`, `Equatable`, `ImplicitlyCopyable`, `Movable`, `Writable`.

## Constants

- `PRIMARY = ColorRole(Int(0))`
- `ON_PRIMARY = ColorRole(Int(1))`
- `PRIMARY_CONTAINER = ColorRole(Int(2))`
- `ON_PRIMARY_CONTAINER = ColorRole(Int(3))`
- `SECONDARY = ColorRole(Int(4))`
- `ON_SECONDARY = ColorRole(Int(5))`
- `SECONDARY_CONTAINER = ColorRole(Int(6))`
- `ON_SECONDARY_CONTAINER = ColorRole(Int(7))`
- `TERTIARY = ColorRole(Int(8))`
- `ON_TERTIARY = ColorRole(Int(9))`
- `TERTIARY_CONTAINER = ColorRole(Int(10))`
- `ON_TERTIARY_CONTAINER = ColorRole(Int(11))`
- `ERROR = ColorRole(Int(12))`
- `ON_ERROR = ColorRole(Int(13))`
- `ERROR_CONTAINER = ColorRole(Int(14))`
- `ON_ERROR_CONTAINER = ColorRole(Int(15))`
- `SURFACE = ColorRole(Int(16))`
- `SURFACE_DIM = ColorRole(Int(17))`
- `SURFACE_BRIGHT = ColorRole(Int(18))`
- `ON_SURFACE = ColorRole(Int(19))`
- `ON_SURFACE_VARIANT = ColorRole(Int(20))`
- `SURFACE_CONTAINER_LOWEST = ColorRole(Int(21))`
- `SURFACE_CONTAINER_LOW = ColorRole(Int(22))`
- `SURFACE_CONTAINER = ColorRole(Int(23))`
- `SURFACE_CONTAINER_HIGH = ColorRole(Int(24))`
- `SURFACE_CONTAINER_HIGHEST = ColorRole(Int(25))`
- `OUTLINE = ColorRole(Int(26))`
- `OUTLINE_VARIANT = ColorRole(Int(27))`
- `BACKGROUND = ColorRole(Int(28))`
- `ON_BACKGROUND = ColorRole(Int(29))`

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
