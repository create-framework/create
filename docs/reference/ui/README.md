# create.ui

The user interface: `UI`, which keeps the widgets' state from frame to frame, `UILayer`, the handle a `with` block gets to draw widgets with, and `Theme`, the design tokens they draw from.

## Types

| Type | Description |
|---|---|
| [`UI`](ui.md) | The state of a program's widgets, kept from frame to frame under each widget's ID. |
| [`UILayer`](uilayer.md) | The handle a `with self.ui.screen(context, canvas) as ui:` or `ui.world` block gets: every widget is a method on it. |
| [`IDGuard`](idguard.md) | Takes the key `ui.id` added off the widget IDs again, on scope exit. Only `ui.id` builds one. |
| [`DisabledGuard`](disabledguard.md) | Ends the `ui.disabled` block it was made for, on scope exit. Only `ui.disabled` builds one. |
| [`ThemeGuard`](themeguard.md) | Ends the `ui.theme` block it was made for, on scope exit. Only `ui.theme` builds one. |
| [`WidgetStyleGuard`](widgetstyleguard.md) | Ends the `ui.style` block it was made for, on scope exit. Only `ui.style` builds one. |
| [`PanelGuard`](panelguard.md) | Ends the `ui.panel` block it was made for, on scope exit. Only `ui.panel` builds one. |
| [`LayoutGuard`](layoutguard.md) | Ends the `ui.column` or `ui.row` block it was made for, on scope exit. Only `ui.column` and `ui.row` build one. |
| [`Theme`](theme.md) | The colours every widget draws from. A widget's look is worked out from them when it is drawn, so changing a colour changes every widget that uses it. |
| [`ColorScheme`](colorscheme.md) | The colours of a theme, as pairs of roles: each colour a widget is filled with, and the `on_` colour for text and icons drawn on it, chosen to read well together. |
| [`StateLayers`](statelayers.md) | How strongly a widget shows its state. |
| [`FocusRing`](focusring.md) | The ring drawn around a widget focused from the keyboard, a gamepad or `take_focus`: its `thickness`, the `gap` between it and the widget, and its `color`, the scheme's `secondary` unless given. It follows the widget's shape, its corners rounded by the widget's own radius grown by the gap. |
| [`ButtonVariant`](buttonvariant.md) | Which of the theme's colours a button is drawn in. |
| [`TextEditor`](texteditor.md) | A text field's caret, selection and editing, from `ui.text_editor()` right after the field. It reads where the caret and selection are, to draw beside them, and edits the field through the same methods typing uses, so a program can drive it from its own keys or buttons. |
