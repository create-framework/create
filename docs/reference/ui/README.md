# create.ui

The user interface: widgets, such as `Button`, `Checkbox`, `Label`, `Panel`, `Slider` and `TextField`, which are values a program keeps, updates and draws with `canvas.draw`, and the traits they share (`Widget`, `Hoverable`, `Clickable`); `UI`, which keeps widgets together and lays them out with `Column`, `Row` and `Space`, reached through `WidgetHandle`s; and `ColorScheme`, the colours they are drawn in.

## Types

| Type | Description |
|---|---|
| [`UI`](ui.md) | Widgets kept together: added once, then updated and drawn each frame in one call each. |
| [`WidgetHandle`](widgethandle.md) | Where a widget of type `W` is in a `UI`: what `ui.add` returns, and how the program reaches the widget again, as `ui[handle]`. |
| [`ColorScheme`](colorscheme.md) | The colours widgets are drawn in, as pairs of roles: each colour a widget is filled with, and the `on_` colour for text and icons drawn on it, chosen to read well together. A program gives its scheme to a `UI` with `ui.colors(scheme)`, and draws its own things in it too, such as `canvas.background(scheme.background)`. |
| [`StateLayers`](statelayers.md) | How strongly a widget shows its state. |
| [`FocusRing`](focusring.md) | The ring drawn around a widget focused from the keyboard, a gamepad or `ui.focus`: its `thickness`, the `gap` between it and the widget, and its `color`, the scheme's `secondary` unless given. It follows the widget's shape, its corners rounded by the widget's own radius grown by the gap. |
| [`Button`](button.md) | A button with a line of text on it, which the mouse clicks. |
| [`ButtonVariant`](buttonvariant.md) | Which of the colours a button is drawn in. |
| [`Checkbox`](checkbox.md) | A box against the left edge of a rectangle, ticked while `checked`, with text beside it. A click anywhere in the rectangle ticks or unticks it. |
| [`Label`](label.md) | Text placed in a rectangle, by an alignment: in its centre unless told otherwise, against its left edge with `Align.LEFT`, and so on. It reacts to nothing. |
| [`Column`](column.md) | Widgets one under the other, from the top down, each across the column's whole width and as tall as it prefers, or as the `height` it was added with: a button or a slider the `UI`'s `control_height`, a label one and a half times its text's size. A `gap` is left between each and the next. The room left over goes to the widgets added with a `grow`, shared in proportion to it, so a growing `Space` pushes what comes after it to the bottom. |
| [`Row`](row.md) | Widgets side by side, from the left, each as tall as the row and as wide as it prefers, or as the `width` it was added with. |
| [`Space`](space.md) | Room left empty in a column, or a row, such as to set one group of widgets apart from the next: twice the `UI`'s `spacing` unless given an `amount`. |
| [`Panel`](panel.md) | A surface filling a rectangle, for widgets to sit on: a rounded card in its colours' `surface_container`, unless its `style` says otherwise. It reacts to nothing. |
| [`Slider`](slider.md) | A handle on a track, dragged to set `value` between `minimum` and `maximum`. |
| [`TextField`](textfield.md) | A field to type a line of text into. |

## Traits

| Trait | Description |
|---|---|
| [`Widget`](widget.md) | A value that reacts to input and draws itself: a `Button`, say. |
| [`Hoverable`](hoverable.md) | A widget the pointer can be over. |
| [`Clickable`](clickable.md) | A widget the mouse presses, in the words the input devices use: *pressed* and *released* are the edges, true only in the frame they happen, and *down* is held. Each is as of its last `update`. |
