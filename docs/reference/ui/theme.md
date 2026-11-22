# Theme

```mojo
struct Theme
```

The design tokens every widget draws from: colours, kinds of text, corner radii, gaps, the height of a control, state layers and the focus ring. A widget's look is worked out from these when it is drawn, so changing a token changes every widget that uses it.

```mojo
# In `create`, building the `ui` field:
var ui = UI(Theme.dark(primary=Color.ORANGE))
```

Implements `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `Writable`.

## Fields

- `colors: ColorScheme`
- `typography: Typography`
- `corner_radii: CornerRadii`
- `spacing: Spacing`
- `control_height: Float64`: How tall a button, slider, checkbox or text field is in a `ui.column`, and how tall a `ui.row` is, unless told otherwise.
- `state_layers: StateLayers`
- `focus_ring: FocusRing`

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

A whole theme worked out from one colour, such as a game's own, as Material's dynamic colour does: light unless `dark`.

The seed's hue gives five families of colour: the primary, a greyer
secondary, a tertiary turned 60 degrees round the colour wheel,
near-greys for the surfaces, and a fixed red for errors. Each role
then takes Material's fixed tone, a lightness that looks the same in
every hue: in the light scheme `primary` is tone 40 and `on_primary`
100, `primary_container` 90 and `on_primary_container` 10. The gap
between two paired roles keeps them readable together, whatever the
seed. A grey seed gives a grey theme.

```mojo
# In `create`, building the `ui` field:
var ui = UI(Theme.from_seed(Color.hex(0xE07A2E)))  # an orange theme
```
