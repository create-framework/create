# Themes and styling

Every widget is drawn in the colours, text and shapes of a theme, so a UI looks of a piece without
being styled widget by widget. This page explains themes and their colours, how to make one from a
single colour, and how to change the look of one widget, a whole block of them, or the surface they
sit on.

## Themes

**A `Theme` holds design tokens, not widget looks:** the colours, the kinds of text, the corner
radii, the gaps, the height of a control such as a button (`control_height`), the strength of the
hovered and pressed states, and the focus ring. Each widget works out its look from these when it is
drawn, so changing one token changes every widget that uses it. The kinds of text,
`theme.typography`'s `title`, `body` and `label`, are each a `Style` setting a size and a weight, so
they can be used wherever a `Style` can. A `UI` is drawn in the theme it is built with, the light
one unless given:

```mojo
# In `create`, building the `ui` field:
var ui = UI(Theme.dark())
```

`Theme.light()` and `Theme.dark()` are the two built-in themes. Both take colours to replace their
own, and a colour given without its partner for text gets black or white, whichever reads better on
it. So making the buttons orange is one word:

```mojo
# In `create`, building the `ui` field:
var ui = UI(Theme.light(primary=Color.ORANGE))
```

`self.ui.theme(Theme.dark())` changes a `UI`'s theme later, such as from a settings screen.

## Colours

The theme's colours are a `ColorScheme`: colours in pairs of **roles**, each colour a widget is
filled with and the `on_` colour for text and icons drawn on it, chosen to read well together:

| Roles | Used for |
|---|---|
| `primary`, `on_primary` | The most important actions, such as a filled button |
| `secondary`, `tertiary` and their `on_` partners | Less prominent actions and accents |
| `error`, `on_error` | Mistakes and warnings |
| Each of those as `_container`, with `on_..._container` | A quieter fill of the same colour, such as a tonal button's |
| `background`, `surface`, `on_surface`, `on_surface_variant` | What everything sits on, and text on it |
| `surface_container_lowest` to `_highest`, `surface_dim`, `surface_bright` | Surfaces set apart from the one around them, such as a panel or a text field's fill |
| `outline`, `outline_variant` | Borders and fainter dividers |

The roles are Material Design's. Use them for your own drawing too, through `ui.theme().colors`, so
it matches the widgets in any theme.

## A theme from one colour

**`Theme.from_seed(color)` builds a whole theme from one colour,** such as a game's own:

```mojo
# In `create`, building the `ui` field:
var ui = UI(Theme.from_seed(Color.hex(0xE07A2E)))  # an orange theme
var night = Theme.from_seed(Color.hex(0xE07A2E), dark=True)  # the same, dark
```

The seed's hue gives the primary colour, a greyer secondary, a tertiary turned round the colour
wheel, near-greys for the surfaces and a fixed red for errors. Each role then takes a fixed
lightness, the same in every hue, with enough difference between each colour and its `on_` partner
that the two always read together, whatever the seed. The lightness is measured as the eye sees it,
which is what [OKLCH](../drawing/colours.md#lightness-that-looks-even) is for. A grey seed gives a
grey theme.

## Styling one widget

**A button, a label and a panel take a `Style`,** the same one the canvas draws with (see
[Style](../drawing/style.md)). Each part it leaves unset comes from the theme, so a style only says
what differs: `Style(corner_radius=4)` gives a button square corners and keeps its colours. For a
button, `fill` is the colour behind the text, `stroke` its outline and `text_color` and the `font_*`
parts its text; for a label, the text; for a panel, its surface, with `text_color` the colour of
text on it. Anything a `Style` can do, a widget's style can do too, such as a gradient fill or a
dashed outline:

```mojo
# In `update`, inside `with self.ui.screen(context, canvas) as ui:`:
if ui.button("Stop", Rectangle((0, 0), 120, 40), style=Style(corner_radius=4)):
    self.stop()
var sunset = Gradient.linear(Color.ORANGE, Color.RED)
if ui.button("Go", Rectangle((0, 50), 120, 40), style=Style(fill_gradient=sunset)):
    self.go()
ui.label("Settings", Rectangle((0, 100), 240, 32), style=ui.theme().typography.title)
ui.slider(
    self.volume,
    0,
    1,
    Rectangle((0, -60), 240, 32),
    style=SliderStyle(handle_color=Color.WHITE, handle_shadow=True),
)
```

The slider, the checkbox and the text field have their own style types, listed in the
[reference](../../reference/ui/README.md). The focus ring always comes from the theme; to change it
for some widgets, draw them in a `ui.theme` block (below).

## Styling a block

Two `with` blocks change the look of every widget inside them:

- **`with ui.style(button=..., slider=..., ...):`** sets style fields for every widget of a kind in
  the block. A call's own style wins over the block's, and a block inside another wins over the
  outer one, field by field: an inner block that sets only the corner radius keeps the outer block's
  colours.
- **`with ui.theme(theme):`** draws the block's widgets in another theme, such as one panel in the
  dark theme on a light screen.

```mojo
# In `update`, inside `with self.ui.screen(context, canvas) as ui:`:
with ui.style(button=Style(corner_radius=4)):
    if ui.button("Square", Rectangle((0, 0), 120, 40)):
        ...
    if ui.button("Square too", Rectangle((0, -50), 120, 40)):
        ...
with ui.theme(Theme.dark()):
    if ui.button("Dark", Rectangle((0, -100), 120, 40)):
        ...
```

## Panels

**`with ui.panel(rect):` draws a surface beneath everything called inside it.** It is the theme's
`surface_container` with rounded corners unless its `Style` says otherwise, and the theme's shadow,
`style=ui.theme().shadow`, lifts it off what is beneath. It covers what is under it from the
pointer, so a click on its background doesn't reach a button behind it.

A panel also sets the colour of text on it: its style's `text_color` if given, otherwise the `on_`
partner of its colour, or black or white for a colour that isn't one of the theme's. So a label on a
panel filled with `primary` turns light without being told. A widget of your own reads that colour
with `ui.content_color()`.

```mojo
# In `update`, inside `with self.ui.screen(context, canvas) as ui:`:
with ui.panel(Rectangle((0, 0), 320, 120), style=ui.theme().shadow):
    with ui.column():
        ui.label("Volume")
        ui.slider(self.volume, 0, 1)
```

A panel doesn't place what is inside it: a `ui.column()` opened in it fills it, short of its edges,
and places the widgets (see [Laying out widgets](widgets.md#laying-out-widgets)).

## Hovered, pressed and disabled

A widget shows its state by moving its colour's lightness towards its text colour: a little when
hovered, more when pressed or dragged. The theme's `state_layers` sets how far, as steps of
lightness, which look like the same change on any colour, a pale fill as much as a dark one. A
disabled widget instead fades, its text and fill to `state_layers.disabled_content` and
`disabled_container` of their opacity.
