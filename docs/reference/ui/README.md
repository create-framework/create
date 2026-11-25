# create.ui

The user interface: widgets, such as `Button`, `Checkbox`, `Label`, `Panel` and `Slider`, which are values a program keeps, updates and draws with `canvas.draw`, and the traits they share (`Widget`, `Hoverable`, `Clickable`); `UI`, which keeps the widgets' state from frame to frame, `UILayer`, the handle a `with` block gets to draw widgets with, and `ColorScheme`, the colours they are drawn in.

## Types

| Type | Description |
|---|---|
| [`UI`](ui.md) | The state of a program's widgets, kept from frame to frame under each widget's ID. |
| [`UILayer`](uilayer.md) | The handle a `with self.ui.screen(context, canvas) as ui:` or `ui.world` block gets: every widget is a method on it. |
| [`IDGuard`](idguard.md) | Takes the key `ui.id` added off the widget IDs again, on scope exit. Only `ui.id` builds one. |
| [`DisabledGuard`](disabledguard.md) | Ends the `ui.disabled` block it was made for, on scope exit. Only `ui.disabled` builds one. |
| [`ColorsGuard`](colorsguard.md) | Ends the `ui.colors` block it was made for, on scope exit. Only `ui.colors` builds one. |
| [`WidgetStyleGuard`](widgetstyleguard.md) | Ends the `ui.style` block it was made for, on scope exit. Only `ui.style` builds one. |
| [`PanelGuard`](panelguard.md) | Ends the `ui.panel` block it was made for, on scope exit. Only `ui.panel` builds one. |
| [`LayoutGuard`](layoutguard.md) | Ends the `ui.column` or `ui.row` block it was made for, on scope exit. Only `ui.column` and `ui.row` build one. |
| [`ColorScheme`](colorscheme.md) | The colours widgets are drawn in, as pairs of roles: each colour a widget is filled with, and the `on_` colour for text and icons drawn on it, chosen to read well together. A program keeps its scheme in a field, passes it to `ui.screen` or `ui.world`, and draws its own things in it, such as `canvas.background(self.colors.background)`. |
| [`StateLayers`](statelayers.md) | How strongly a widget shows its state. |
| [`FocusRing`](focusring.md) | The ring drawn around a widget focused from the keyboard, a gamepad or `take_focus`: its `thickness`, the `gap` between it and the widget, and its `color`, the scheme's `secondary` unless given. It follows the widget's shape, its corners rounded by the widget's own radius grown by the gap. |
| [`Button`](button.md) | A button with a line of text on it, which the mouse clicks. |
| [`ButtonVariant`](buttonvariant.md) | Which of the colours a button is drawn in. |
| [`Checkbox`](checkbox.md) | A box against the left edge of a rectangle, ticked while `checked`, with text beside it. A click anywhere in the rectangle ticks or unticks it. |
| [`Label`](label.md) | Text placed in a rectangle, by an alignment: in its centre unless told otherwise, against its left edge with `Align.LEFT`, and so on. It reacts to nothing. |
| [`Panel`](panel.md) | A surface filling a rectangle, for widgets to sit on: a rounded card in the light colours' `surface_container`, unless its `style` says otherwise. It reacts to nothing. |
| [`Slider`](slider.md) | A handle on a track, dragged to set `value` between `minimum` and `maximum`. |
| [`TextEditor`](texteditor.md) | A text field's caret, selection and editing, from `ui.text_editor()` right after the field. It reads where the caret and selection are, to draw beside them, and edits the field through the same methods typing uses, so a program can drive it from its own keys or buttons. |

## Traits

| Trait | Description |
|---|---|
| [`Clickable`](clickable.md) | A widget the mouse presses, in the words the input devices use: *pressed* and *released* are the edges, true only in the frame they happen, and *down* is held. Each is as of its last `update`. |
| [`Hoverable`](hoverable.md) | A widget the pointer can be over. |
| [`Widget`](widget.md) | A value that reacts to input and draws itself: a `Button`, say. |
