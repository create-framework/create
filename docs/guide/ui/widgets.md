# Widgets

A widget is a button, a slider, a checkbox, a text field, a label or an image: something drawn on
the screen that the player can point at, click, drag or type into. This page explains how a program
calls widgets, where their state lives, how each one works, and how to draw things of your own among
them.

## Calling widgets

**A widget is a call made every frame, not an object you keep.** A button is drawn by calling
`ui.button` in `update`, and the call returns whether it was clicked. A slider is given the value it
controls, and changes it while it is dragged:

```mojo
from create import *


@fieldwise_init
struct Settings(Program):
    var ui: UI
    var volume: Float64
    var clicks: Int

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> Settings:
        return Settings(UI(), 0.5, 0)

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        with self.ui.screen(context, canvas) as ui:
            with ui.column(Rectangle((0, 0), 400, 160)):
                if ui.button("Click me"):
                    self.clicks += 1
                ui.slider(self.volume, 0, 1)
                ui.label(
                    String(self.clicks) + " clicks, volume " + String(self.volume)
                )


def main() raises:
    run[Settings]("Settings")
```

The program keeps one thing for its widgets: a `UI`, built in `create` and kept as a field. It
remembers what each widget needs from one frame to the next, such as which slider is being dragged,
which widget has focus and where a text field's caret is.

Every frame, `with self.ui.screen(context, canvas) as ui:` opens a **layer**, and the widgets are
called inside it, on the `ui` it hands you. Here they are called inside a `ui.column` block, which
places each one under the one before, across the rectangle the column is given. A widget can also be
given a `Rectangle` of its own instead, positioned by its centre like every shape in Create (see
[Coordinates](../basics/coordinates.md)); [Laying out widgets](#laying-out-widgets) explains both.
Nothing has to be added or removed: a widget is on screen in the frames it is called in, so showing
a button only while a menu is open is an `if` around the call.

**A button returns whether it was clicked; a value widget changes its value.** A click is what a
button is for, so `ui.button` returns it, to test with `if`. A value widget, such as a slider, a
checkbox or a text field, takes its value as `mut` and changes it in place, so the value is all most
programs need, and the call returns nothing.

**`ui.changed()` says whether the widget called just before it changed its value this frame**, for
reacting to a change, such as saving a setting or playing a click:

```mojo
# In `update`, inside `with self.ui.screen(context, canvas) as ui:`:
ui.slider(self.volume, 0, 1, Rectangle((0, 0), 240, 32))
if ui.changed():
    self.audio.volume(self.volume)
```

It always answers for the last widget called, so ask right after the widget you mean. After a button
it is `False`, since a button has no value to change.

## Layers

A layer is drawn when its `with` block ends, on top of what was drawn before, so the UI is never
covered by the game drawn under it. There are two kinds:

- **`ui.screen(context, canvas)`** draws in screen space, whatever the camera is doing: menus, the
  score, a settings panel.
- **`ui.world(context, canvas)`** draws in the space that is current when the block opens, through
  the camera and any transform: a button above a chest, a health bar over an enemy. Its widgets move
  and zoom with the camera, and are clicked where they appear.

```mojo
# In `update`, with `ui: UI`, `camera: Camera` and `chest: Point` fields:
canvas.camera(self.camera)
with self.ui.world(context, canvas) as ui:
    if ui.button("Open", Rectangle(self.chest + Vector(0, 40), 80, 32)):
        self.open_chest()
with self.ui.screen(context, canvas) as ui:
    if ui.button("Menu", Rectangle((canvas.left() + 60, canvas.top() - 30), 100, 36)):
        self.paused = True
```

A frame can have as many layers as it needs. Where they overlap, the one drawn last is on top, for
the pointer as well as for the eye. A world layer is drawn beneath whatever is drawn after its
block, so where the block sits decides what covers what.

**Open a new layer every frame.** The `ui` a block hands you belongs to that frame, and using it in
a later one raises an error. A helper that draws part of the UI takes it as a parameter:

```mojo
# A helper, called with the layer inside the block: `settings(ui, ...)`.
def settings(ui: UILayer, mut volume: Float64) raises:
    ui.slider(volume, 0, 1, Rectangle((0, 0), 240, 32))
```

## The widgets

| Call | What it is | Reports |
|---|---|---|
| `ui.button(text, rect)` | A button showing `text` | Returns whether it was clicked |
| `ui.slider(value, min, max, rect)` | A track with a handle setting `value` | `ui.changed()`: whether it changed `value` |
| `ui.checkbox(label, checked, rect)` | A box with `label` beside it | `ui.changed()`: whether it switched `checked` |
| `ui.text_field(text, rect)` | A field for typing into `text` | `ui.changed()`, `ui.submitted()` and `ui.text_editor()` |
| `ui.label(text, rect)` | Text placed in `rect` | Nothing |
| `ui.image(image, rect)` | `image` stretched to fill `rect` | Nothing |

- **A button** is clicked when the left button is pressed and let go over it. Pressing it and
  letting go elsewhere does nothing, which is how a player changes their mind. `variant=` picks how
  prominent it is: `ButtonVariant.FILLED` (the default) for the main action, `TONAL` for a secondary
  one, `OUTLINED` and `TEXT` for quieter ones.
- **A slider** jumps to where it is pressed and follows the pointer while held, even off its track,
  stopping at its ends. `step=` rounds the value to multiples of the step, counted from `min`. A
  value outside `min` to `max` is drawn at the nearer end and left as it is until dragged.
- **A checkbox** switches `checked` when clicked anywhere in its rectangle, its label included.
- **A text field** is explained in [Typing](../interaction/typing.md#text-fields).
- **A label** places its text by `alignment=`, or its style's `text_alignment` when the call gives
  none: in the middle of `rect` unless given, against its left edge with `Align.LEFT`, and so on.
  Labels and images don't react, so the pointer passes through them to whatever is beneath.

Each widget's look can be changed with a `Style`: a button, a label or a panel takes one as
`style=`, and a slider, a checkbox or a text field takes one for each of its parts, such as
`handle=`. [Themes and styling](themes.md) explains both.

## Laying out widgets

**Every widget goes in a rectangle: one you give it, or the next place in a column or row.** A
widget given a `rect` fills it, wherever that is, so a button can sit over a chest or in a corner of
the screen. Called without one, inside a `ui.column` or `ui.row` block, it takes the next place the
column or row has for it, and you never work out a position:

```mojo
# In `update`, inside `with self.ui.screen(context, canvas) as ui:`:
with ui.panel(Rectangle((0, 0), 400, 240)):
    with ui.column():
        ui.label("Settings")
        with ui.row(1, 3):  # a quarter of the width, then three quarters
            ui.label("Volume", alignment=Align.LEFT)
            ui.slider(self.volume, 0, 1)
        ui.checkbox("Music", self.music)
        ui.space()
        with ui.row(columns=2):
            if ui.button("OK"):
                self.close_settings()
            if ui.button("Cancel"):
                self.close_settings()
```

- **`ui.column(rect)`** places the widgets in it one under the other, from the top down, each across
  the column's whole width. A widget is the `UI`'s `control_height` tall, 40 unless changed, and a
  label one and a half times the size of its text. `gap=` sets the space between them, the `UI`'s
  `spacing` unless given.
- **`ui.row(weights...)`** places them side by side, from the left, in slots that share the row's
  width in proportion to the weights: `ui.row(1, 3)` gives the first slot a quarter and the second
  three quarters. `ui.row(columns=4)` makes four equal slots. In a column, a row is `control_height`
  tall, or `height=` if given.
- **Without a rectangle, a panel, column or row fills what is around it:** the inside of the panel
  it is in, short of its edges by twice the `UI`'s `spacing`, the rest of a column, or the next slot
  of a row. Columns and rows nest, so a row of columns is a grid, and a row of panels is a row of
  cards.
- **`ui.space()`** leaves a gap in a column, twice the `UI`'s `spacing` unless given, such as to set
  the buttons apart from the settings above them.
- **A widget given a `rect` inside a column or row** goes where the `rect` says, and the column or
  row doesn't move on, so one widget can be placed by hand among the others.

**A mistake raises an error that says what to do:** a widget called without a `rect` anywhere but in
a column or row, a panel, column or row without one anywhere but in a panel, column or row, and a
widget called once every slot of a row is taken.

**A column doesn't grow to fit what is in it.** Each widget is placed as it is called, so that it
knows where it is and can answer in the same frame. So nothing can be sized from widgets called
after it: a panel is as big as its rectangle says, and a column that is given more than it can hold
carries on past its bottom edge. Make the panel tall enough for what it holds.

The same cuts, without the widgets, are `Rectangle`'s `inset`, `rows` and `columns`, for laying out
what you draw on the canvas (see [Shapes](../geometry/shapes.md#rectangle)).

## How widgets are told apart

**A widget is known by where it is called from.** The `UI` keeps each widget's state, such as a text
field's caret, under an ID it works out from the file, line and column of the call, so you never
name one. A call in a loop gets a different ID each time round, counted from the start of the loop,
and a widget shown only some of the time doesn't change any other widget's ID.

The count only goes wrong when items in a list are reordered or removed while one is in use: the
fields after a removed one would each take on the caret of the one before. Give each item a key of
its own with `ui.id`, and its widgets keep their state wherever it moves:

```mojo
# In `update`, inside `with self.ui.screen(context, canvas) as ui:`, for a list of players:
for ref player in self.players:
    with ui.id(player.name):  # added to the ID of every widget in the block
        ui.text_field(player.name, ...)
        if ui.button("Remove", ...):
            ...
```

`id=` on a single call does the same for one widget, and takes any key `ui.id` takes:
`ui.button("OK", rect, id=player.name)`.

## Drawing your own things

**`ui.draw(shape, style)` draws any shape in a layer, in order with the widgets.** A plain canvas
call inside the block draws at once, beneath the whole layer, because the layer is drawn when the
block ends. So an icon on a button, or a highlight behind a slider, goes through `ui.draw`:

```mojo
# In `update`, inside `with self.ui.screen(context, canvas) as ui:`:
if ui.button("", Rectangle((0, 0), 48, 48)):
    ...
ui.draw(Circle((0, 0), 10), Style(fill=ui.colors().on_primary))  # on top of the button
```

It takes any `Drawable`, your own types included (see [The canvas](../drawing/canvas.md)). Text and
images go through `ui.label` and `ui.image`, which also draw in order.

## Disabled widgets

**`disabled=True` disables one widget, and `with ui.disabled(condition):` every widget in its
block.** A disabled widget is drawn faded, doesn't react to the pointer or the keys, and never
reports a click or a change: a disabled button returns `False`, and `ui.changed()` after any
disabled widget is `False`. It still covers what is beneath it, so a click on it doesn't fall
through to something else. The block form greys out a whole section without an `if` around each
widget:

```mojo
# In `update`, inside `with self.ui.screen(context, canvas) as ui:`:
with ui.disabled(not self.online):
    if ui.button("Find a game", Rectangle((0, 0), 200, 48)):
        self.find_game()
```

Labels and images in a `ui.disabled` block fade along with the widgets, so the whole section looks
switched off.

## One UI for widgets that belong together

Keep **one `UI` for every widget the player navigates together**, however many layers it draws them
in: it is what Tab moves through, and what decides which widget has focus. Several `UI`s are for
groups that are separate, such as each player's menu in a split-screen game; they take turns at the
keyboard and mouse, and Tab stays within the one that has the keyboard (see [Focus and
navigation](focus.md#several-uis)).
