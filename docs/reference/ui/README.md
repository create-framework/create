# create.ui

The user interface: widgets, such as `Button`, `Checkbox`, `Switch`, `ChoiceGroup`, `Tabs`, `Label`, `Panel`, `Slider`, `ProgressBar`, `TextField`, `NumberField` and `Dropdown`, which are values a program keeps, updates and draws with `canvas.draw`, and the traits they share (`Widget`, `Hoverable`, `Clickable`); `UI`, which keeps widgets together, lays them out with `Column`, `Row` and `Space` and scrolls them with `ScrollArea`, reached through `WidgetHandle`s; and the settings a `UI` draws them with, `StateLayers` and `FocusRing`.

## Types

| Type | Description |
|---|---|
| [`UI`](ui.md) | Widgets kept together: added once, then updated and drawn each frame in one call each. |
| [`WidgetHandle`](widgethandle.md) | Where a widget of type `W` is in a `UI`: what `ui.add` returns, and how the program reaches the widget again, as `ui[handle]`. |
| [`StateLayers`](statelayers.md) | How strongly a widget shows its state. |
| [`FocusRing`](focusring.md) | The ring drawn around a widget focused from the keyboard, a gamepad or `ui.focus`: its `thickness`, the `gap` between it and the widget, and its `color`, the scheme's `primary` unless given. It follows the widget's shape, its corners rounded by the widget's own radius grown by the gap. |
| [`Button`](button.md) | A button with a line of text on it, which the mouse clicks. |
| [`Checkbox`](checkbox.md) | A box against the left edge of a rectangle, ticked while `checked`, with text beside it. A click anywhere in the rectangle ticks or unticks it. |
| [`Switch`](switch.md) | A setting that is on or off and applies at once, such as music or full screen: a track against the left edge of a rectangle, its handle at the right end while `on`, with text beside it. A click anywhere in the rectangle turns it over. |
| [`ChoiceGroup`](choicegroup.md) | A few options, one under the other, of which one is chosen: each a circle with its text, the chosen one's circle with a dot in it. Other toolkits call these radio buttons. |
| [`Tabs`](tabs.md) | A row of tabs, one of them selected, for switching between pages of a menu: the selected one's text in the accent colour, with a line beneath it. |
| [`Label`](label.md) | Text placed in a rectangle, by an alignment: against its left edge unless told otherwise, as text in a form reads, in its centre with `Align.CENTER`, and so on. It reacts to nothing. |
| [`Column`](column.md) | Widgets one under the other, from the top down, each across the column's whole width and as tall as it prefers, or as the `height` it was added with: a button or a slider the `UI`'s `control_height`, a label one and a half times its text's size. A `gap` is left between each and the next. The room left over goes to the widgets added with a `grow`, shared in proportion to it, so a growing `Space` pushes what comes after it to the bottom. |
| [`Row`](row.md) | Widgets side by side, from the left, each as tall as the row and as wide as it prefers, or as the `width` it was added with. |
| [`Space`](space.md) | Room left empty in a column, or a row, such as to set one group of widgets apart from the next: twice the `UI`'s `spacing` unless given an `amount`. |
| [`ScrollArea`](scrollarea.md) | A window onto a column of widgets, showing the part of it that fits. |
| [`Panel`](panel.md) | A surface filling a rectangle, for widgets to sit on: a rounded card in its colours' `surface_container`, unless its `style` says otherwise. It reacts to nothing. |
| [`Slider`](slider.md) | A handle on a track, dragged to set `value` between `minimum` and `maximum`. |
| [`ProgressBar`](progressbar.md) | A bar filled as far as `value` has got from `minimum` to `maximum`, such as a level loading, a health bar or a cooldown. It reacts to nothing. |
| [`TextField`](textfield.md) | A field to type a line of text into. |
| [`NumberField`](numberfield.md) | A number between `minimum` and `maximum`, typed into a field or stepped with the − and + buttons beside it, such as a count of players or a volume in whole percent. |
| [`Dropdown`](dropdown.md) | A field showing the chosen one of its options, which opens a list of them all when clicked, drawn over everything else. Use it to choose one of many options, such as a screen resolution, where a `ChoiceGroup` would take too much room. |

## Traits

| Trait | Description |
|---|---|
| [`Widget`](widget.md) | A value that reacts to input and draws itself: a `Button`, say. |
| [`Hoverable`](hoverable.md) | A widget the pointer can be over. |
| [`Clickable`](clickable.md) | A widget the mouse presses, in the words the input devices use: *pressed* and *released* are the edges, true only in the frame they happen, and *down* is held. Each is as of its last `update`. |
