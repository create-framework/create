# Themes and styling

Every widget in a `UI` is drawn in the same colours and sizes, so a UI looks of a piece without
being styled widget by widget. This page explains the colours a UI is drawn in, how to make them
from a single colour, the sizes and states the `UI` keeps, and how to change the look of one widget,
every widget of a kind, or the surface they sit on.

## Colours

**A `UI` draws its widgets in a `ColorScheme`, set with `ui.colors(scheme)`.** Keep the colours
where your own drawing can reach them too, and draw in them, so everything matches:

```mojo
from create import *

comptime COLORS = ColorScheme.dark()


@fieldwise_init
struct Menu(Program):
    var ui: UI
    var play: WidgetHandle[Button]

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> Menu:
        var ui = UI()
        ui.colors(COLORS)
        var play = ui.add(Button("Play", Rectangle((0, 0), 160, 40)))
        return Menu(ui^, play)

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        canvas.background(COLORS.background)
        self.ui.update(context, canvas)
        canvas.draw(self.ui)
        if self.ui[self.play].released():
            context.quit()


def main() raises:
    run[Menu]("Menu")
```

A `UI` given no colours draws in `ColorScheme.light()`, and `ui.colors()` reads back the ones it
draws in. To change them, such as from a settings screen, set them again: the widgets take the new
colours at the next `update`. A widget on its own, outside a `UI`, is drawn in the colours its
`update` is given, the light ones unless told otherwise, and its own style changes any part of its
look (see [Styling one widget](#styling-one-widget)):

```mojo
# In `update`, with a `play: Button` field, on a dark screen:
self.play.update(context, canvas, colors=ColorScheme.dark())
canvas.draw(self.play)
```

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
| `surface_container_lowest` to `_highest`, `surface_dim`, `surface_bright` | Surfaces set apart from the one around them, such as a panel or a text field's fill |
| `outline`, `outline_variant` | Borders and fainter dividers |

The roles are Material Design's. Use them for your own drawing too, so it matches the widgets
whichever scheme you pick.

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
| `corner_radius` | 16 | How round a panel's corners are. The other widgets follow it: a text field is rounded by a quarter of it and a checkbox's box by an eighth, and a button is a pill at 16 or more and squarer below, so `self.ui.corner_radius(0)` squares them all |
| `spacing` | 8 | The gap between the widgets in a column or row. A panel's inside is inset by twice it, and a `Space` leaves twice it empty |
| `control_height` | 40 | How tall a button, slider, checkbox or text field is when the `UI` sizes it |
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
# In `create`, building the `ui` field:
var stop = ui.add(Button("Stop", Rectangle((0, 0), 120, 40), style=Style(corner_radius=4)))
var sunset = Gradient.linear(Color.ORANGE, Color.RED)
var go = ui.add(Button("Go", Rectangle((0, 50), 120, 40), style=Style(fill_gradient=sunset)))
_ = ui.add(Label("Settings", Rectangle((0, 100), 240, 32), style=Style(font_size=22)))
```

The style is a field of the widget, so it can change later: `self.ui[self.stop].style =
Style(fill=Color.RED)`.

**A widget with several parts takes a `Style` for each,** and each part is a shape drawn in it, so
what a part's style means follows from the shape. A slider's `track` is a line, so its `stroke` and
`stroke_thickness` are the track's colour and thickness, and `active_track`, the line from the start
to the handle, takes what it leaves unset from `track`. Its `handle` is a point, drawn as
`canvas.point` draws one: its `stroke` is the handle's colour and its `stroke_thickness` its
diameter, and `stroke_cap=StrokeCap.SQUARE` makes it square. `handle_outline` is a circle round the
handle, drawn only when it sets a stroke or a fill:

```mojo
# In `create`, building the `volume` field:
var volume = Slider(
    0.5,
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
corners; `tick` is the lines of the tick; and `text_style` is the text beside it.

A text field's `container` is the field, a rectangle, and `focused_container` is layered over it
while the field has focus: by default its outline turns `primary` and twice as thick. `text_style`
is the typed text, `placeholder_style` the placeholder (taking what it leaves unset from
`text_style`), `caret` a line and `selection` the rectangle behind selected text. `padding`, a
number, is the gap between the field's sides and its text.

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

**A `Panel` is a surface for other widgets to sit on.** It is the colours' `surface_container`, its
corners rounded by the `UI`'s `corner_radius`, unless its `Style` says otherwise, and a shadow in
its style lifts it off what is beneath. In a `UI`, widgets added inside it are drawn on it, and it
covers what is under it from the pointer, so a click on its background doesn't reach a button behind
it.

A panel also sets the colour of text on it: its style's `text_color` if given, otherwise the `on_`
partner of its colour, or black or white for a colour that isn't one of the scheme's. In a `UI`, a
label added inside a panel filled with `primary` turns light without being told. On its own, a panel
gives the colour as `panel.content_color()`, for text drawn on it.

```mojo
# In `create`, building the `ui` field: a raised card with a column of widgets.
var lifted = Style(shadow=Color(0, 0, 0, 60), shadow_offset=Vector(0, -3), shadow_blur=12)
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
