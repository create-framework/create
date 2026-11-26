# Widgets

A widget is a button, a slider, a checkbox, a text field, a label or a panel: something drawn on the
screen that the player can point at, click, drag or type into. This page explains what a widget is,
how a program updates and draws one, how a `UI` keeps many together and lays them out, and how to
draw things of your own among them.

## A widget is a value

**A widget is a value the program keeps, in a field, like a `Rectangle` or a `Tween`.** It holds
what it shows and what happened to it: a button its text, and whether it was just clicked; a slider
its value. Each frame, the program does three things with it:

1. **`widget.update(context, canvas)`** reads what the mouse did to it and works out its look.
2. **`canvas.draw(widget)`** draws it, as a shape is drawn.
3. **The program asks it what happened**, such as `button.released()`, the click.

```mojo
from create import *


@fieldwise_init
struct Counter(Program):
    var button: Button
    var clicks: Int

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> Counter:
        return Counter(Button("Click me", Rectangle((0, 0), 160, 48)), 0)

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        self.button.update(context, canvas)
        canvas.draw(self.button)
        if self.button.released():
            self.clicks += 1
        canvas.text(String(self.clicks) + " clicks", (0, -60))


def main() raises:
    run[Counter]("Counter")
```

A widget's `rect` is a `Rectangle`, positioned by its centre like every shape in Create (see
[Coordinates](../basics/coordinates.md)). Its fields are its own to change at any time:
`self.button.text = "Again"` changes the text from the next draw.

**Update a widget before drawing it, in the same transform.** `update` finds the pointer with
`canvas.to_local`, so a widget under a camera, or inside a `canvas.transform` block, is hit where it
is drawn. And since it works out the widget's look as well, a button shows that it is hovered from
the very frame the pointer reaches it.

**Asking a widget what happened** uses the words the mouse and keyboard use (see
[Input](../interaction/input.md)): `pressed()` and `released()` are true only in the frame they
happen, and `down()` while it is held. `released()` is the click: the button let go over the widget,
after being pressed on it. A press that starts elsewhere, or a release away from it, isn't a click,
which is how a player changes their mind. `hovered()` is whether the pointer is over it.

## The widgets

| Widget | What it is | What it reports |
|---|---|---|
| `Button(text, rect)` | A button showing `text` | `released()`, the click, and `pressed()`, `down()` and `hovered()` |
| `Checkbox(text, rect, checked=)` | A box, ticked or not, with `text` beside it | `checked`, and `changed()` in the frame a click ticks or unticks it |
| `Slider(value, minimum, maximum, rect)` | A track with a handle setting `value` | `value`, and `changed()` in the frame it moves |
| `TextField(text, rect)` | A field to type a line of text into, holding `text` to start with | `text()`, `changed()` and `submitted()` |
| `Label(text, rect, alignment)` | Text placed in `rect` | Nothing |
| `Panel(rect)` | A surface for other widgets to sit on | Nothing |

- **A button** has a `variant` that picks how prominent it is: `ButtonVariant.FILLED` (the default)
  for the main action, `TONAL` for a secondary one, `OUTLINED` and `TEXT` for quieter ones.
- **A checkbox** ticks or unticks when clicked anywhere in its rectangle, its text included. Its
  `checked` field is the program's to set too.
- **A slider** jumps to where it is pressed and follows the pointer while held, even off its track,
  stopping at its ends. `step=` rounds the value to multiples of the step, counted from `minimum`,
  and must be more than 0. A value outside `minimum` to `maximum` is drawn at the nearer end and
  left as it is until dragged.
- **A text field** is explained in [Typing](../interaction/typing.md#text-fields).
- **A label** places its text by its `alignment`, or its style's `text_alignment` without one: in
  the middle of `rect` unless given, against its left edge with `Align.LEFT`, and so on.
- **A label and a panel react to nothing.** A panel's `content_color()` is the colour for text on it
  (see [Panels](themes.md#panels)).

`changed()` reports only what the player did. A value the program sets, such as `slider.value =
0.5`, isn't a change.

Each widget's look can be changed with a `Style`: a button, a label or a panel takes one as `style`,
and a slider, a checkbox or a text field takes one for each of its parts, such as `handle`. [Themes
and styling](themes.md) explains both.

## Keeping widgets together in a UI

A screen of widgets, such as a settings menu, is easier kept together than one field at a time. **A
`UI` keeps widgets together**, updates them all in one call and draws them in another. It also does
what single widgets can't do on their own: it lays them out, gives them a shared look, lets only the
one on top react where they overlap, and moves focus between them (see [Focus and
navigation](focus.md)).

```mojo
from create import *


@fieldwise_init
struct Settings(Program):
    var ui: UI
    var volume: WidgetHandle[Slider]
    var done: WidgetHandle[Button]

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> Settings:
        var ui = UI()
        var card = ui.add(Panel())  # fits round the column inside it
        var column = ui.add(Column(), card)
        _ = ui.add(Label("Volume"), column)
        var volume = ui.add(Slider(0.8, 0, 1), column)
        var done = ui.add(Button("Done"), column)
        return Settings(ui^, volume, done)

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        self.ui.update(context, canvas)
        canvas.draw(self.ui)
        if self.ui[self.volume].changed():
            print("volume", self.ui[self.volume].value)
        if self.ui[self.done].released():
            context.quit()


def main() raises:
    run[Settings]("Settings")
```

- **`ui.add(widget)`** adds a widget, and **`ui.add(widget, parent)`** adds it inside a panel, a
  column or a row; adding one inside anything else doesn't compile. Each returns a `WidgetHandle`,
  kept to reach the widget again. A handle belongs to the `UI` that made it: using it on another
  stops the program with a message saying so. A widget added later, or inside another, is drawn on
  top.
- **`ui[handle]` is the widget itself**, inside the `UI`, to ask or change: `self.ui[self.done]
  .released()`, or `self.ui[self.done].text = "Close"`.
- **`ui.get(handle)` is a copy of the widget, to read.** In a method that changes the `UI`, such as
  `update`, two widgets can't both be reached through `ui[...]` in one expression: `Vector(ui[x]
  .value, ui[y].value)` doesn't compile, since each is the widget inside the `UI`. Read them with
  `get`, `Vector(ui.get(x).value, ui.get(y).value)`, or each into a variable first.
- **`ui.update(context, canvas)`** updates every widget, and **`canvas.draw(ui)`** draws them all.

**Where widgets overlap, only the one on top reacts to the pointer.** A panel covers what is beneath
it, so a click on its background doesn't reach a button behind it. A label lets the pointer through
to whatever is under it.

**Screen or world is where you draw the `UI`.** A menu that should stay put on the screen while the
camera moves is updated and drawn inside `canvas.overlay()`, which suspends the camera. A button
above a treasure chest is drawn without it, under the camera, and moves and zooms with the world:

```mojo
# In `update`, with `menu: UI` and `chest_ui: UI` fields and a `camera: Camera`:
canvas.camera(self.camera)
self.chest_ui.update(context, canvas)  # in the world, through the camera
canvas.draw(self.chest_ui)
with canvas.overlay():  # on the screen, whatever the camera is doing
    self.menu.update(context, canvas)
    canvas.draw(self.menu)
```

## Laying out widgets

**A widget given no `rect` is placed by the `UI`.** A widget added with a `rect` goes where it says,
so a button can sit over a chest or in a corner of the screen. One added without a `rect` is placed
for you, by what it is added inside:

- **`Column(rect)`** places the widgets in it one under the other, from the top down, each as tall
  as it prefers and stretched across the column's width: a button, checkbox, slider or text field is
  the `UI`'s `control_height` tall, 40 unless changed, and a label one and a half times the size of
  its text. `gap=` sets the space between them, the `UI`'s `spacing` unless given.
- **`Row(rect)`** places them side by side, from the left, each as wide as it prefers and stretched
  across the row's height. In a column, a row is as tall as its tallest widget.
- **`Space(amount)`** leaves room in a column, twice the `UI`'s `spacing` unless given, such as to
  set the buttons apart from the settings above them.
- **A panel places a column or row added inside it with no `rect`** across its inside, short of its
  edges by its `padding`: twice the `UI`'s `spacing` unless given, as in `Panel(padding=8)`. Other
  widgets added straight onto a panel keep their own `rect`.
- **A widget added with a `rect` keeps it**, even inside a column or row, and takes no room there,
  so one widget can be placed by hand among the others.
- **A widget, panel, column or row with no `rect` and nothing to place it** takes the size it
  prefers, centred on the origin. A panel with no size fits round the column or row inside it, and a
  column round its widgets.

**How a widget fits in its column or row is set when it is added**, with keywords on `ui.add`:

- **`width=` and `height=` set the size it starts from**, in place of the one it prefers:
  `ui.add(Button("OK"), buttons, width=120)`. Two buttons given the same `width` are as wide as each
  other, whatever their text. A negative size stops the program.
- **`grow=` shares out the room left over.** Once every widget in a column or row has the size it
  starts from, what is left of the column's height, or the row's width, goes to the widgets added
  with a `grow`, in proportion to it. A slider beside a label with `grow=1` takes the rest of the
  row. Two widgets with `grow=1` and `grow=3` take a quarter and three quarters of what is left, and
  with `width=0` as well they take exactly a quarter and three quarters of the row. When nothing is
  left over, nothing grows.
- **A `Space` that grows is a spring.** `ui.add(Space(), column, grow=1)` pushes what comes after it
  to the bottom of the column; one before and one after a widget centre it.
- **`align=` sets it at the width it prefers across a column, or the height across a row**, rather
  than stretched. `Column(align=Align.CENTER)` does so for every widget in the column, centring
  each, and `Align.LEFT` or `Align.RIGHT` sets them against a side; a row reads `Align.TOP`,
  `CENTER` or `BOTTOM` the same way. `align=` on `ui.add` sets one widget apart from the rest:
  `ui.add(Label("Title"), column, align=Align.LEFT)`. A widget given a `width` in a column, or a
  `height` in a row, is centred unless it is aligned.

```mojo
# In `create`, building the `ui` field: a card of settings.
var card = ui.add(Panel())
var column = ui.add(Column(), card)
_ = ui.add(Label("Settings", style=Style(font_size=22)), column)
var line = ui.add(Row(), column)
_ = ui.add(Label("Volume", alignment=Align.LEFT), line, width=80)
var volume = ui.add(Slider(0.8, 0, 1), line, grow=1)  # the rest of the line
_ = ui.add(Space(), column)
var buttons = ui.add(Row(), column)
_ = ui.add(Space(), buttons, grow=1)  # pushes the buttons to the right
var ok = ui.add(Button("OK"), buttons, width=100)
var cancel = ui.add(Button("Cancel"), buttons, width=100)
```

Columns and rows nest, so a row of columns is a grid. The `UI` lays out again every frame, before it
reads the pointer, so a widget whose text changes is resized at once, and is clicked where it was
just placed.

The same cuts, without the widgets, are `Rectangle`'s `inset`, `rows` and `columns`, for laying out
what you draw on the canvas (see [Shapes](../geometry/shapes.md#rectangle)).

### Scroll areas

**A `ScrollArea` shows part of a column that is taller than the room it has**, such as a long list
of levels in a menu. Add one column inside it: the column is as tall as its widgets, and the scroll
area is a window onto it. What falls outside the window is neither drawn nor clicked.

```mojo
# In `create`: a list of levels, never taller than 240.
var window = ui.add(ScrollArea(max_height=240), column)
var levels = ui.add(Column(), window)
for name in ["Forest", "Caves", "Castle", "Sky", "Moon"]:
    _ = ui.add(Button(name), levels)
```

- **Its size:** with no `rect` of its own, a scroll area is as wide as its column and as tall as it
  too, up to `max_height`. In a column or row it can also take a `height`, or `grow` into the room
  left over, like any other widget.
- **The wheel and the scroll bar scroll it.** While the column is taller than the window, a scroll
  bar runs down the window's right edge, and the column leaves room for it. Turning the mouse wheel
  over the window scrolls it by a control's height a notch: in a scroll area inside another, the
  inner one scrolls. Dragging the bar's thumb scrolls it too, and holds the mouse until the button
  is let go, as dragging a slider does. Its look is set as other widgets' parts are, with `track=`
  and `thumb=` (see [Themes and styling](themes.md)).
- **`offset` is how far down the column the window shows**, from 0 at the top. Set it to scroll from
  code, such as `self.ui[self.window].offset = 0` to go back to the top. Each layout keeps it
  between 0 and as far as the column goes, so setting it too far shows the end of the column.
- **`ui.scroll_to(handle)` brings a widget into view**, scrolling each scroll area it is in by the
  least that shows all of it, such as to show the level just unlocked. Moving focus onto a widget
  with Tab, the arrows or a gamepad does the same (see [Focus and navigation](focus.md#focus)). It
  takes effect at the tree's next `update`.

## Drawing your own things

**Draw your own things before or after the `UI`.** What is drawn before `canvas.draw(ui)` is beneath
every widget, and what is drawn after it is on top, such as an icon on a button. A widget's `rect`
says where it is:

```mojo
# In `update`, with `ui: UI` and `star: WidgetHandle[Button]` fields:
self.ui.update(context, canvas)
canvas.draw(self.ui)
var at = self.ui.get(self.star).rect.position
canvas.draw(Circle(at, 10), Style(fill=self.ui.colors().on_primary))
```

**A widget of your own is a `Drawable` with an `update`**, built from the shapes, `Text` and
`Picture`s it is made of, each drawn in a style of its own (see [The
canvas](../drawing/canvas.md#your-own-types)). It can conform to `Widget`, `Hoverable` and
`Clickable` to answer as the built-in widgets do, and it works anywhere a widget on its own does. It
can't be added to a `UI` yet, which holds only the built-in kinds: keep it in a field beside the
`UI`, and update and draw it there. An image in a `UI` is a `Picture`, which a `UI` takes as it is.

## Disabled widgets

**A widget whose `enabled` is `False` is drawn faded and reacts to nothing.** It never reports a
click or a change, and takes no focus, but still covers what is beneath it, so a click on it doesn't
fall through. In a `UI`, **`ui.enabled(handle, False)`** disables a widget and everything inside it,
such as a whole panel, without changing each widget's own `enabled`:

```mojo
# In `update`: grey the online section out while offline.
self.ui.enabled(self.online_panel, self.connected)
```

Labels and pictures in a disabled part of a `UI` fade along with the widgets, so the whole section
looks switched off.

## Hiding and removing widgets

**`ui.visible(handle, False)` hides a widget and everything inside it** until `ui.visible(handle,
True)` shows them again. A hidden part of the tree isn't drawn, reacts to nothing and takes no
focus; a widget that had focus loses it. It takes no room either, so the widgets after it in a
column or row close up. Each widget keeps its fields while hidden, so a slider comes back at the
value it had:

```mojo
# In `update`: the advanced settings show while their box is ticked.
var ticked = self.ui[self.advanced].checked
self.ui.visible(self.advanced_settings, ticked)
```

**`ui.remove(handle)` takes a widget and everything inside it out of the `UI` for good**, such as an
item used up from an inventory, or the rows of a list being rebuilt. Hide a widget that will come
back, and remove one that won't. A removed widget's handle names nothing: using it stops the program
with a message saying so, so drop it along with the widget. A widget added later never takes over an
old handle, even when it takes the removed widget's place:

```mojo
# In `update`, with `ui: UI` and `items: List[WidgetHandle[Button]]` fields:
# the item clicked is used up.
for i in range(len(self.items)):
    if self.ui[self.items[i]].released():
        self.ui.remove(self.items.pop(i))
        break
```

## One UI for widgets that belong together

Keep **one `UI` for every widget the player navigates together**: it is what Tab moves through, and
what decides which widget has focus. Several `UI`s are for groups that are separate, such as each
player's menu in a split-screen game, or a menu on the screen and buttons in the world. They take
turns at the keyboard and mouse (see [Focus and navigation](focus.md#several-uis)).
