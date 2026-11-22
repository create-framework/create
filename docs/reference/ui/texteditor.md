# TextEditor

```mojo
struct TextEditor[ui_origin: MutOrigin, context_origin: MutOrigin]
```

A text field's caret, selection and editing, from `ui.text_editor()` right after the field. It reads where the caret and selection are, to draw beside them, and edits the field through the same methods typing uses, so a program can drive it from its own keys or buttons.

An edit reaches the field's `text` the next time the field is called,
as typing does, and `ui.changed()` reports it then.

```mojo
# In `update`, inside `with self.ui.screen(context, canvas) as ui:`, with
# a `name: String` field:
ui.text_field(self.name, Rectangle((0, 0), 320, 40))
var editor = ui.text_editor()
if ui.button("Clear", Rectangle((200, 0), 80, 40)):
    editor.select_all()
    editor.delete_backward()
```

Implements `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`.

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
