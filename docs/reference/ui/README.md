# create.ui

The user interface: `UI`, which keeps the widgets' state from frame to frame, and `UILayer`, the handle a `with` block gets to draw widgets with.

## Types

| Type | Description |
|---|---|
| [`UI`](ui.md) | The state of a program's widgets, kept from frame to frame under each widget's ID. |
| [`UILayer`](uilayer.md) | The handle a `with self.ui.screen(context, canvas) as ui:` block gets: every widget is a method on it. |
| [`IDGuard`](idguard.md) | Takes the key `ui.id` added off the widget IDs again, on scope exit. Only `ui.id` builds one. |
