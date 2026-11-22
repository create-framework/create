# Typography

```mojo
struct Typography
```

The theme's kinds of text: `title` for headings, `body` for running text and `label` for the text on widgets, such as a button's. Each is a `Style` setting the text's size and weight, and its font where it has one of its own; its colour comes from where the text is drawn.

```mojo
# In `update`, inside `with self.ui.screen(context, canvas) as ui:`:
var title = LabelStyle(text_style=ui.theme().typography.title)
ui.label("Settings", Rectangle((0, 0), 200, 32), style=title)
```

Implements `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `Writable`.

## Fields

- `title: Style`
- `body: Style`
- `label: Style`

## Constructors

```mojo
@staticmethod
def __init__(out self)
```
