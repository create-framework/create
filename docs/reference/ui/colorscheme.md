# ColorScheme

```mojo
struct ColorScheme
```

The colours widgets are drawn in, as pairs of roles: each colour a widget is filled with, and the `on_` colour for text and icons drawn on it, chosen to read well together. A program gives its scheme to a `UI` with `ui.colors(scheme)`, and draws its own things in it too, such as `canvas.background(scheme.background)`.

- **`primary`** is for the most important actions, such as a filled
  button; **`secondary`** and **`tertiary`** for less prominent ones and
  accents; **`error`** for mistakes and warnings.
- Each of those has a **`_container`**: a quieter fill of the same
  colour, such as a tonal button's.
- **`background`** is behind everything, and **`surface`** is what
  widgets sit on; usually the two are the same colour. **`surface_dim`**
  and **`surface_bright`** are the darkest and lightest surfaces, and the
  **`surface_container_`** roles, from `lowest` to `highest`, are
  surfaces set apart from the one around them, such as a panel, a text
  field's fill or a slider's track. Text on any surface is `on_surface`,
  or the quieter `on_surface_variant`.
- **`outline`** draws borders, and **`outline_variant`** fainter
  dividers.

Implements `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `Writable`.

## Fields

- `primary: Color`
- `on_primary: Color`
- `primary_container: Color`
- `on_primary_container: Color`
- `secondary: Color`
- `on_secondary: Color`
- `secondary_container: Color`
- `on_secondary_container: Color`
- `tertiary: Color`
- `on_tertiary: Color`
- `tertiary_container: Color`
- `on_tertiary_container: Color`
- `error: Color`
- `on_error: Color`
- `error_container: Color`
- `on_error_container: Color`
- `surface: Color`
- `surface_dim: Color`
- `surface_bright: Color`
- `on_surface: Color`
- `on_surface_variant: Color`
- `surface_container_lowest: Color`
- `surface_container_low: Color`
- `surface_container: Color`
- `surface_container_high: Color`
- `surface_container_highest: Color`
- `outline: Color`
- `outline_variant: Color`
- `background: Color`
- `on_background: Color`

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

Dark colours on a light background, with the colours given replacing its own.

A colour given also changes its container to a quieter mix of it
with the surface, and a colour given without its `on_` partner gets
black or white, whichever reads better on it. So this is enough to
make the buttons orange:

```mojo
# In `create`, building the `colors` field:
var colors = ColorScheme.light(primary=Color.ORANGE)
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

Light colours on a dark background, with the colours given replacing its own, as `ColorScheme.light` does.

### `from_seed`

```mojo
@staticmethod
def from_seed(
    seed: Color,
    *,
    dark: Bool = False,
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

The colours worked out from one colour, such as a game's own, as Material's dynamic colour does: light unless `dark`.

The seed's hue gives five families of colour: the primary, a greyer
secondary, a tertiary turned 60 degrees round the colour wheel,
near-greys for the surfaces, and a fixed red for errors. Each role
then takes Material's fixed tone, a lightness that looks the same in
every hue: in the light scheme `primary` is tone 40 and `on_primary`
100, `primary_container` 90 and `on_primary_container` 10. The gap
between two paired roles keeps them readable together, whatever the
seed. A grey seed gives grey colours.

The colours given replace those worked out, as in `light` and `dark`.

```mojo
# In `create`, building the `colors` field:
var colors = ColorScheme.from_seed(Color.hex(0xE07A2E))  # orange
var warning = ColorScheme.from_seed(  # the same, with a yellow error
    Color.hex(0xE07A2E), error=Color.hex(0xE0B000)
)
```
