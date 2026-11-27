# Themes and styling

Every widget in a `UI` is drawn in the same colours and sizes, so a UI looks of a piece without
being styled widget by widget. This page explains the colours a UI is drawn in, how to make them
from a single colour, the sizes and states the `UI` keeps, and how to change the look of one widget,
every widget of a kind, or the surface they sit on.

## Colours

**Widgets are drawn in a `ColorScheme`: the canvas's, set with `canvas.colors(scheme)`.** It lasts
until changed, so set it once in `create`, and draw your own things in it too, so everything
matches:

```mojo
from create import *


@fieldwise_init
struct Menu(Program):
    var ui: UI
    var play: WidgetHandle[Button]

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> Menu:
        canvas.colors(ColorScheme.dark())
        var ui = UI()
        var play = ui.add(Button("Play", Rectangle((0, 0), 160, 40)))
        return Menu(ui^, play)

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        canvas.background(canvas.colors().background)
        self.ui.update(context, canvas)
        canvas.draw(self.ui)
        if self.ui[self.play].released():
            context.quit()


def main() raises:
    run[Menu]("Menu")
```

A canvas given no colours has `ColorScheme.light()`. To change them, such as from a settings screen,
set them again: the widgets take the new colours at their next `update`. A widget on its own,
outside a `UI`, is drawn in the canvas's colours too.

**A `UI` can have colours of its own,** set with `ui.colors(scheme)`, such as for one dark panel on
a light screen; `ui.colors(None)` follows the canvas's again. `ui.colors()` reads back the colours
it draws in.

`ColorScheme.light()` and `ColorScheme.dark()` are the two built-in schemes. Both take colours to
replace their own, and a colour given without its partner for text gets black or white, whichever
reads better on it. So making the buttons orange is one word:

```mojo
# In `create`, building the `ui` field:
ui.colors(ColorScheme.light(primary=Color.ORANGE))
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
| `surface_container_lowest` to `_highest`, `surface_dim`, `surface_bright` | Surfaces set apart from the one around them, such as a panel or a switch's track |
| `surface_raised` | A surface lifted above the one around it, such as a dropdown's open list or a panel with a shadow: lighter than the surface in either scheme |
| `outline`, `outline_variant` | Borders and fainter dividers |

The roles are Material Design's. Use them for your own drawing too, so it matches the widgets
whichever scheme you pick.

**A style can name a role instead of a colour,** with `ColorRole`: `Style(fill=ColorRole.PRIMARY)`
is filled with whichever `primary` the scheme in use has. The role becomes a colour when the style
is applied, so a style written once follows the scheme when it changes. On a widget, the role is
taken from the colours the widget is drawn in; drawn on the canvas, from the canvas's (see
[Style](../drawing/style.md#colours-by-role)):

```mojo
# In `create`, building the `ui` field: a label in the quieter text colour, light or dark.
_ = ui.add(Label("Saved", style=Style(text_color=ColorRole.ON_SURFACE_VARIANT)))
```

## Colours from one colour

**`ColorScheme.from_seed(color)` works out every colour from one,** such as a game's own:

```mojo
# In `create`, building the colours a `UI` is given:
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

The `UI` keeps the rest of what its widgets are drawn with. Each is a setting, set with an argument
and read back without one, like the run's settings on `Context`:

| Setting | Default | What it sets |
|---|---|---|
| `corner_radius` | 4 | How round the controls' corners are: buttons, fields, dropdowns, the highlight behind a tab, a tooltip. A panel and a dropdown's open list are rounded twice as much, so a control in a panel's corner follows its curve, and a checkbox's box at most 4.5, so it stays a box. `self.ui.corner_radius(0)` squares them all |
| `spacing` | 8 | The gap between the widgets in a column or row. A panel's inside is inset by twice it, and a `Space` leaves twice it empty |
| `control_height` | 40 | How tall a button, slider, checkbox or text field is when the `UI` sizes it |
| `state_layers` | | How strongly a widget shows that it is hovered, pressed or disabled (see [below](#hovered-pressed-and-disabled)) |
| `focus_ring` | | The ring round a widget focused from the keyboard or a gamepad (see [Focus rings](focus.md#focus-rings)) |

```mojo
# In `create`, building the `ui` field:
var ui = UI()
ui.corner_radius(8)  # rounder widgets
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
# In `create`, building the `ui` field:
var stop = ui.add(Button("Stop", Rectangle((0, 0), 120, 40), style=Style(corner_radius=4)))
var sunset = Gradient.linear(Color.ORANGE, Color.RED)
var go = ui.add(Button("Go", Rectangle((0, 50), 120, 40), style=Style(fill_gradient=sunset)))
_ = ui.add(Label("Settings", Rectangle((0, 100), 240, 32), style=Style(font_size=22)))
```

The style is a field of the widget, so it can change later: `self.ui[self.stop].style =
Style(fill=Color.RED)`.

**A button's ready-made styles are where a look of your own starts.** `Button.FILLED`, `TONAL`,
`OUTLINED` and `TEXT` name their colours by `ColorRole`, so they follow the colours they are drawn
in, and `over` builds on one. Keep a look you use more than once as a constant:

```mojo
# At the top of the file: a quiet, square button for a toolbar.
comptime TOOL = Style(corner_radius=0, font_size=14).over(Button.TONAL)

# In `create`, building the `ui` field:
var undo = ui.add(Button("Undo", style=TOOL))
```

**A widget with several parts takes a `Style` for each,** and each part is a shape drawn in it, so
what a part's style means follows from the shape. A slider's `track` is a line, so its `stroke` and
`stroke_thickness` are the track's colour and thickness, and `active_track`, the line from the start
to the handle, takes what it leaves unset from `track`. Its `handle` is a rectangle: its `fill` is
the handle's colour, its `stroke` an outline round it and its `corner_radius` how round it is. A
radius of half its size makes it round, and 0 square. A style has no size, so the slider takes the
handle's: `handle_size=` for a square, or `handle_width=` and `handle_height=` together for any
rectangle, such as a thin upright handle. Half the `control_height` square unless given:

```mojo
# In `create`, building the `volume` field: a round white handle with a grey rim.
var volume = Slider(
    0.5,
    0,
    1,
    Rectangle((0, -60), 240, 32),
    track=Style(stroke_thickness=2),
    handle=Style(
        fill=Color.WHITE,
        stroke=Color.GRAY,
        corner_radius=12,
        shadow=Color(0, 0, 0, 60),
        shadow_blur=8,
    ),
    handle_size=24,
)
```

A checkbox works the same way: `box` is the empty box, a rectangle drawn as an outline;
`checked_box` is the ticked one, filled, taking what it leaves unset from `box`, such as its
corners; `tick` is the lines of the tick; and `text_style` is the text beside it.

A text field's `container` is the field, a rectangle, an outline unless styled with a fill, and
`focused_container` is layered over it while the field has focus: by default its outline turns
`primary` and twice as thick. `text_style` is the typed text, `placeholder_style` the placeholder
(taking what it leaves unset from `text_style`), `caret` a line and `selection` the rectangle behind
selected text. `padding`, a number, is the gap between the field's sides and its text.

A tooltip has one part, `ui.style(tooltip=...)`: its box, a rectangle, whose text parts set its
text, such as `Style(fill=Color.BLACK, text_color=Color.WHITE)`.

A dropdown's `field` is its field, a rectangle with the chosen option's text; `list` is the open
list, a rectangle, raised with a shadow by default; and `item` is each item's text, the chosen one
in `primary`.

A number field is a text field with two buttons, and is styled as they are: `container` and
`text_style` are its field's, as a text field's are, and `buttons` is the `style` of both buttons.
`ui.style(number_field_container=...)` and the like style every number field; the `UI`'s text field
and button styles apply beneath those.

Tabs' `tab` is each tab, a rectangle with its text, bare unless its style gives it a fill or an
outline; `selected_tab` is the selected one, taking what it leaves unset from `tab`; and `indicator`
is the line beneath the selected tab.

A choice group's `circle` is each option's circle, an outline; `selected_circle` is the chosen
one's, taking what it leaves unset from `circle`; `dot` is a point in it, drawn as `canvas.point`
draws one, so its `stroke` is its colour and its `stroke_thickness` its diameter; and `text_style`
is the options' text.

A switch works the same way: `track` is a rectangle, rounded as the controls are, drawn while it is
off; `on_track` is the same rectangle while it is on, taking what it leaves unset from `track`;
`handle` is a square in it, larger while on, so its `fill` is its colour and its `corner_radius` how
round it is; and `text_style` is the text beside it. Unless styled, the handle is rounded as much
less than the track as it sits inside it, so `track=Style(corner_radius=12)` makes a pill with a
round handle.

A progress bar has two parts, each a line, as a slider's track has: `track`, the whole length, and
`indicator`, from the start to its value, which takes what it leaves unset from `track`.

A scroll area's bar has two parts, each a line: `track`, the length the thumb runs along, and
`thumb`, whose length shows how much of the column the window shows. The stroke of each is its
colour and thickness. The thumb steps like a button when hovered or dragged.

## Styling every widget of a kind

**`ui.style(button=..., slider_handle=..., ...)`** sets style fields for every widget of a kind in a
`UI`. A widget's own style wins over it, field by field: a button styled `Style(fill=Color.RED)` in
a `UI` whose buttons are `Style(corner_radius=4)` is red and square. Each part is named by the
widget and its keyword for the part: `slider_handle=`, `checkbox_tick=`, `checkbox_text_style=`,
`text_field_caret=`, `scroll_area_thumb=` and so on.

**Each call changes only the kinds it names.** A keyword given replaces what an earlier call set for
that kind, and a kind left out keeps its style, so the styles can be set a few at a time. Give a
kind `Style()` to clear its style:

```mojo
# In `create`, building the `ui` field: square buttons throughout.
ui.style(button=Style(corner_radius=4))
ui.style(slider_handle=Style(stroke=Color.ORANGE))  # the buttons stay square
```

The focus ring isn't a part: it comes from the `UI`'s `focus_ring` (see [Focus
rings](focus.md#focus-rings)). Widgets in other colours from the rest, such as one dark panel on a
light screen, belong in a `UI` of their own, given those colours.

## Panels

**A `Panel` is a surface for other widgets to sit on.** It is the colours' `surface_container`, a
little set apart from the surface, its corners rounded twice the `UI`'s `corner_radius`, unless its
`Style` says otherwise. A shadow in its style lifts it off what is beneath; fill a lifted panel with
`ColorRole.SURFACE_RAISED`, which is lighter than the surface, as something nearer the light is. In
a `UI`, widgets added inside it are drawn on it, and it covers what is under it from the pointer, so
a click on its background doesn't reach a button behind it.

A panel also sets the colour of text on it: its style's `text_color` if given, otherwise the `on_`
partner of its colour, or black or white for a colour that isn't one of the scheme's. In a `UI`, a
label added inside a panel filled with `primary` turns light without being told. On its own, a panel
gives the colour as `panel.content_color()`, for text drawn on it.

```mojo
# In `create`, building the `ui` field: a raised card with a column of widgets.
var lifted = Style(
    fill=ColorRole.SURFACE_RAISED,
    shadow=Color(0, 0, 0, 60),
    shadow_offset=Vector(0, -3),
    shadow_blur=12,
)
var card = ui.add(Panel(Rectangle((0, 0), 320, 120), style=lifted))
var column = ui.add(Column(), card)
_ = ui.add(Label("Volume"), column)
var volume = ui.add(Slider(0.5, 0, 1), column)
```

A panel places a column or row added inside it across its inside, short of its edges, and with no
size of its own it fits round them (see [Laying out widgets](widgets.md#laying-out-widgets)).

## Hovered, pressed and disabled

A widget shows its state by moving its colour's lightness towards its text colour: a little when
hovered, more when pressed or dragged. The `UI`'s `state_layers` sets how far, as steps of
lightness, which look like the same change on any colour, a pale fill as much as a dark one. A
disabled widget instead fades, its text and fill to `state_layers.disabled_content` and
`disabled_container` of their opacity.
