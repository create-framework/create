# Themes and styling

Every widget is drawn in the same colours and sizes, so a UI looks of a piece without being styled
widget by widget. This page explains the colours a UI is drawn in, how to make them from a single
colour, the sizes and states the `UI` keeps, and how to change the look of one widget, a whole block
of them, or the surface they sit on.

## Colours

**A program keeps its colours in a field, a `ColorScheme`, and hands them to each layer.** The
widgets are drawn in them, and the program draws its own things in them too, so there is one copy of
the colours and everything matches:

```mojo
from create import *


@fieldwise_init
struct Menu(Program):
    var ui: UI
    var colors: ColorScheme

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> Menu:
        return Menu(UI(), ColorScheme.dark())

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        canvas.background(self.colors.background)
        with self.ui.screen(context, canvas, self.colors) as ui:
            if ui.button("Play", Rectangle((0, 0), 160, 40)):
                ...


def main() raises:
    run[Menu]("Menu")
```

A layer given no colours is drawn in `ColorScheme.light()`. To change the colours, such as from a
settings screen, assign the field: `self.colors = ColorScheme.light()`.

`ColorScheme.light()` and `ColorScheme.dark()` are the two built-in schemes. Both take colours to
replace their own, and a colour given without its partner for text gets black or white, whichever
reads better on it. So making the buttons orange is one word:

```mojo
# In `create`, building the `colors` field:
var colors = ColorScheme.light(primary=Color.ORANGE)
```

A `ColorScheme`'s colours come in pairs of **roles**, each colour a widget is filled with and the
`on_` colour for text and icons drawn on it, chosen to read well together:

| Roles | Used for |
|---|---|
| `primary`, `on_primary` | The most important actions, such as a filled button |
| `secondary`, `tertiary` and their `on_` partners | Less prominent actions and accents |
| `error`, `on_error` | Mistakes and warnings |
| Each of those as `_container`, with `on_..._container` | A quieter fill of the same colour, such as a tonal button's |
| `background`, `surface`, `on_surface`, `on_surface_variant` | What everything sits on, and text on it |
| `surface_container_lowest` to `_highest`, `surface_dim`, `surface_bright` | Surfaces set apart from the one around them, such as a panel or a text field's fill |
| `outline`, `outline_variant` | Borders and fainter dividers |

The roles are Material Design's. Use them for your own drawing too, through your `colors` field, so
it matches the widgets whichever scheme you pick. Inside a `ui.colors` block (see [Styling a
block](#styling-a-block)), `ui.colors()` gives the colours in effect there.

## Colours from one colour

**`ColorScheme.from_seed(color)` works out every colour from one,** such as a game's own:

```mojo
# In `create`, building the `colors` field:
var colors = ColorScheme.from_seed(Color.hex(0xE07A2E))  # orange
var night = ColorScheme.from_seed(Color.hex(0xE07A2E), dark=True)  # the same, dark
```

The seed's hue gives the primary colour, a greyer secondary, a tertiary turned round the colour
wheel, near-greys for the surfaces and a fixed red for errors. Each role then takes a fixed
lightness, the same in every hue, with enough difference between each colour and its `on_` partner
that the two always read together, whatever the seed. The lightness is measured as the eye sees it,
which is what [OKLCH](../drawing/colours.md#lightness-that-looks-even) is for. A grey seed gives
grey colours.

`from_seed` takes colours to replace its own too, as `light` and `dark` do, such as an error colour
of the game's: `ColorScheme.from_seed(Color.hex(0xE07A2E), error=Color.hex(0xE0B000))`.

## Sizes and states

The `UI` keeps the rest of what every widget is drawn with. Each is a setting, set with an argument
and read back without one, like the run's settings on `Context`:

| Setting | Default | What it sets |
|---|---|---|
| `corner_radius` | 16 | How round a panel's corners are. The other widgets follow it: a text field is rounded by a quarter of it and a checkbox's box by an eighth, and a button is a pill at 16 or more and squarer below, so `self.ui.corner_radius(0)` squares them all |
| `spacing` | 8 | The gap between the widgets in a column or row. A panel's inside is inset by twice it, and `ui.space()` leaves twice it empty |
| `control_height` | 40 | How tall a button, slider, checkbox or text field is in a column, and how tall a row is |
| `state_layers` | | How strongly a widget shows that it is hovered, pressed or disabled (see [below](#hovered-pressed-and-disabled)) |
| `focus_ring` | | The ring round a widget focused from the keyboard or a gamepad (see [Focus rings](focus.md#focus-rings)) |

```mojo
# In `create`, building the `ui` field:
var ui = UI()
ui.corner_radius(4)  # squarer widgets
ui.spacing(12)  # roomier columns and rows
```

## Styling one widget

**A button, a label and a panel take a `Style`,** the same one the canvas draws with (see
[Style](../drawing/style.md)). Each part it leaves unset comes from the widget's defaults, so a
style only says what differs: `Style(corner_radius=4)` gives a button square corners and keeps its
colours. For a button, `fill` is the colour behind the text, `stroke` its outline and `text_color`
and the `font_*` parts its text; for a label, the text; for a panel, its surface, with `text_color`
the colour of text on it. Anything a `Style` can do, a widget's style can do too, such as a gradient
fill or a dashed outline:

```mojo
# In `update`, inside `with self.ui.screen(context, canvas) as ui:`:
if ui.button("Stop", Rectangle((0, 0), 120, 40), style=Style(corner_radius=4)):
    self.stop()
var sunset = Gradient.linear(Color.ORANGE, Color.RED)
if ui.button("Go", Rectangle((0, 50), 120, 40), style=Style(fill_gradient=sunset)):
    self.go()
ui.label("Settings", Rectangle((0, 100), 240, 32), style=Style(font_size=22))
```

**A widget with several parts takes a `Style` for each,** and each part is a shape drawn in it, so
what a part's style means follows from the shape. A slider's `track` is a line, so its `stroke` and
`stroke_thickness` are the track's colour and thickness, and `active_track`, the line from the start
to the handle, takes what it leaves unset from `track`. Its `handle` is a point, drawn as
`canvas.point` draws one: its `stroke` is the handle's colour and its `stroke_thickness` its
diameter, and `stroke_cap=StrokeCap.SQUARE` makes it square. `handle_outline` is a circle round the
handle, drawn only when it sets a stroke or a fill:

```mojo
# In `update`, inside `with self.ui.screen(context, canvas) as ui:`:
ui.slider(
    self.volume,
    0,
    1,
    Rectangle((0, -60), 240, 32),
    track=Style(stroke_thickness=2),
    handle=Style(stroke=Color.WHITE, stroke_thickness=24, shadow=Color(0, 0, 0, 60), shadow_blur=8),
    handle_outline=Style(stroke=Color.GRAY),
)
```

A checkbox works the same way: `box` is the empty box, a rectangle drawn as an outline;
`checked_box` is the ticked one, filled, taking what it leaves unset from `box`, such as its
corners; `tick` is the lines of the tick; and `label_style` is the text beside it.

A text field's `container` is the field, a rectangle, and `focused` is layered over it while the
field has focus: by default its outline turns `primary` and twice as thick. `text_style` is the
typed text, `placeholder_style` the placeholder (taking what it leaves unset from `text_style`),
`caret` a line and `selection` the rectangle behind selected text. `padding`, a number, is the gap
between the field's sides and its text.

`ui.style` takes every part too, named by the widget and the call's keyword for the part:
`slider_handle=`, `checkbox_tick=`, `checkbox_label_style=`, `text_field_caret=` and so on. The
focus ring isn't a part: it comes from the `UI`'s `focus_ring` (see [Focus
rings](focus.md#focus-rings)).

## Styling a block

Two `with` blocks change the look of every widget inside them:

- **`with ui.style(button=..., slider_handle=..., ...):`** sets style fields for every widget of a
  kind in the block. A call's own style wins over the block's, and a block inside another wins over
  the outer one, field by field: an inner block that sets only the corner radius keeps the outer
  block's colours.
- **`with ui.colors(colors):`** draws the block's widgets in other colours, such as one panel in the
  dark scheme on a light screen.

```mojo
# In `update`, inside `with self.ui.screen(context, canvas) as ui:`:
with ui.style(button=Style(corner_radius=4)):
    if ui.button("Square", Rectangle((0, 0), 120, 40)):
        ...
    if ui.button("Square too", Rectangle((0, -50), 120, 40)):
        ...
with ui.colors(ColorScheme.dark()):
    if ui.button("Dark", Rectangle((0, -100), 120, 40)):
        ...
```

## Panels

**`with ui.panel(rect):` draws a surface beneath everything called inside it.** It is the colours'
`surface_container`, its corners rounded by the `UI`'s `corner_radius`, unless its `Style` says
otherwise, and a shadow in its style lifts it off what is beneath. It covers what is under it from
the pointer, so a click on its background doesn't reach a button behind it.

A panel also sets the colour of text on it: its style's `text_color` if given, otherwise the `on_`
partner of its colour, or black or white for a colour that isn't one of the scheme's. So a label on
a panel filled with `primary` turns light without being told. A widget of your own reads that colour
with `ui.content_color()`.

```mojo
# In `update`, inside `with self.ui.screen(context, canvas) as ui:`:
var lifted = Style(shadow=Color(0, 0, 0, 60), shadow_offset=Vector(0, -3), shadow_blur=12)
with ui.panel(Rectangle((0, 0), 320, 120), style=lifted):
    with ui.column():
        ui.label("Volume")
        ui.slider(self.volume, 0, 1)
```

A panel doesn't place what is inside it: a `ui.column()` opened in it fills it, short of its edges,
and places the widgets (see [Laying out widgets](widgets.md#laying-out-widgets)).

## Hovered, pressed and disabled

A widget shows its state by moving its colour's lightness towards its text colour: a little when
hovered, more when pressed or dragged. The `UI`'s `state_layers` sets how far, as steps of
lightness, which look like the same change on any colour, a pale fill as much as a dark one. A
disabled widget instead fades, its text and fill to `state_layers.disabled_content` and
`disabled_container` of their opacity.
