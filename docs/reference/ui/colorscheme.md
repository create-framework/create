# ColorScheme

```mojo
struct ColorScheme
```

The colours of a theme, as pairs of roles: each colour a widget is filled with, and the `on_` colour for text and icons drawn on it, chosen to read well together.

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
def light() -> Self
```

Dark colours on a light background.

### `dark`

```mojo
@staticmethod
def dark() -> Self
```

Light colours on a dark background.
