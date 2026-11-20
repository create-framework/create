# TextFieldResult

```mojo
struct TextFieldResult[ui_origin: MutOrigin, context_origin: MutOrigin, text_origin: MutOrigin]
```

What a text field reports back: whether it changed the text, whether Enter was pressed in it, and where its caret and selection are. As a `Bool`, it is whether the text changed, so `if ui.text_field(...):` works like every other widget.

For the rest of its layer's block it also edits the field, through the
same methods typing uses, so a program can drive it from its own keys or
buttons:

```mojo
# In `update`, inside `with self.ui.screen(context, canvas) as ui:`, with
# a `name: String` field:
var field = ui.text_field(self.name, Rectangle((0, 0), 320, 40))
if field.submitted:
    self.start_game(self.name)
if ui.button("Clear", Rectangle((200, 0), 80, 40)):
    field.select_all()
    field.delete_backward()
```

Implements `Boolable`, `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`.

## Fields

- `changed: Bool`: Whether the text changed this frame.
- `submitted: Bool`: Whether Enter was pressed in the field this frame.

## Methods

### `before_caret`

```mojo
def before_caret(self) raises -> String
```

The text left of the caret: what to measure to place it.

### `after_caret`

```mojo
def after_caret(self) raises -> String
```

The text right of the caret.

### `selected_text`

```mojo
def selected_text(self) raises -> String
```

The selected text, empty when nothing is.

### `before_selection`

```mojo
def before_selection(self) raises -> String
```

The text left of the selection: what to measure to place its highlight. The same as `before_caret` when nothing is selected.

### `insert`

```mojo
def insert(self, typed: String) raises
```

Put `typed` in place of the selection, or at the caret.

### `delete_backward`

```mojo
def delete_backward(self) raises
```

Delete the selection, or the character left of the caret.

### `delete_forward`

```mojo
def delete_forward(self) raises
```

Delete the selection, or the character right of the caret.

### `move_left`

```mojo
def move_left(self, *, select: Bool = False) raises
```

### `move_right`

```mojo
def move_right(self, *, select: Bool = False) raises
```

### `move_word_left`

```mojo
def move_word_left(self, *, select: Bool = False) raises
```

### `move_word_right`

```mojo
def move_word_right(self, *, select: Bool = False) raises
```

### `move_to_start`

```mojo
def move_to_start(self, *, select: Bool = False) raises
```

### `move_to_end`

```mojo
def move_to_end(self, *, select: Bool = False) raises
```

### `select_all`

```mojo
def select_all(self) raises
```

### `cut`

```mojo
def cut(self) raises
```

Put the selection on the clipboard and delete it.

### `paste`

```mojo
def paste(self) raises
```

Insert the clipboard's text, as if typed.

## Special methods

### `__bool__`

```mojo
def __bool__(self) -> Bool
```
