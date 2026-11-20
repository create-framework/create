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
| [`Theme`](theme.md) | The design tokens every widget draws from: colours, kinds of text, corner radii, gaps, state layers and the focus ring. A widget's look is worked out from these when it is drawn, so changing a token changes every widget that uses it. |
| [`ColorScheme`](colorscheme.md) | The colours of a theme, as pairs of roles: each colour a widget is filled with, and the `on_` colour for text and icons drawn on it, chosen to read well together. |
| [`Typography`](typography.md) | The theme's kinds of text: `title` for headings, `body` for running text and `label` for the text on widgets, such as a button's. |
| [`TypeStyle`](typestyle.md) | How one kind of text looks: its size, its weight and its font, or the canvas's default font when `font` is `None`. |
| [`CornerRadii`](cornerradii.md) | How round the theme's corners are, from `small`, such as a checkbox's, to `large`, such as a panel's. |
| [`Spacing`](spacing.md) | The theme's gaps, from `small`, between a label and its widget, to `large`, between groups of widgets. |
| [`StateLayers`](statelayers.md) | How strongly a widget shows its state. |
| [`FocusRing`](focusring.md) | The ring drawn around a widget focused from the keyboard, a gamepad or `take_focus`: its `thickness`, the `gap` between it and the widget, and its `color`, the scheme's `secondary` unless given. It follows the widget's shape, its corners rounded by the widget's own radius grown by the gap. |
| [`ButtonVariant`](buttonvariant.md) | Which of the theme's colours a button is drawn in. |
| [`ButtonStyle`](buttonstyle.md) | How one button looks, where it differs from its variant. Every field left unset is worked out from the theme when the button is drawn. |
| [`LabelStyle`](labelstyle.md) | How a label's text looks, where it differs from the theme: the theme's `on_surface` colour and `body` text unless given. |
| [`SliderStyle`](sliderstyle.md) | How one slider looks, where it differs from the theme. Every field left unset is worked out from the theme when the slider is drawn. |
| [`CheckboxStyle`](checkboxstyle.md) | How one checkbox looks, where it differs from the theme. Every field left unset is worked out from the theme when the checkbox is drawn. |
| [`TextFieldStyle`](textfieldstyle.md) | How one text field looks, where it differs from the theme. Every field left unset is worked out from the theme when the text field is drawn. |
| [`TextFieldResult`](textfieldresult.md) | What a text field reports back: whether it changed the text, whether Enter was pressed in it, and where its caret and selection are. As a `Bool`, it is whether the text changed, so `if ui.text_field(...):` works like every other widget. |
| [`PanelStyle`](panelstyle.md) | How one panel looks, where it differs from the theme. Every field left unset is worked out from the theme when the panel is drawn. |
