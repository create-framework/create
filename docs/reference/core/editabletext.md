# EditableText

```mojo
struct EditableText
```

A line of text being typed into, with a caret and a selection: the state of a text field, without its look.

The program owns one per field and feeds it the frame each `update`,
then draws `text` itself — measuring with `canvas.text_width` puts the
caret after the right character and the selection behind the right
ones:

```mojo
self.name.update(context)                       # in update
canvas.text_alignment(Align.LEFT)
var selected_x = left + canvas.text_width(self.name.before_selection())
canvas.rectangle(...)  # from selected_x, text_width(selected_text()) wide
canvas.text(self.name.text, (left, 0))
var caret_x = left + canvas.text_width(self.name.before_caret())
canvas.line((caret_x, -20), (caret_x, 20))
```

`update` replays the frame's typing in the order it came, so text and
editing keys typed within one frame land where they were typed:

| Keys | Does |
|---|---|
| Typed text | Replaces the selection, or goes in at the caret |
| Backspace, Delete | Delete the selection, or one character either side |
| Left, Right | Move one character, or to a selection's edge |
| Home, End | Move to the start or the end |
| *word* + Left/Right/Backspace/Delete | The same, a word at a time |
| Shift + any move | Extends the selection instead |
| *command* + A, C, X, V | Select all, copy, cut, paste |

*Command* is Cmd on macOS and Ctrl elsewhere; *word* is Option on macOS
and Ctrl elsewhere, and on macOS Cmd+Left/Right go to the start and the
end, as the system's own fields do. The command shortcuts follow the
letter printed on the key, so they are where the user expects on any
layout. Moves and deletes repeat while held; Enter is left to the
program, which decides what submitting means. Clicking into the text is
the program's: it knows where the text is drawn.

`max_length`, if set, is the most characters typing and pasting can
bring the text to. Every edit and move is by whole characters, so a
multi-byte UTF-8 character is never split. `text` is a plain field:
reading it is the point, and assigning it (`self.name.text = ""`) is
safe, since the caret and the selection are kept inside it and on
character boundaries.

Implements `Copyable`, `Deinitable`, `Movable`, `Writable`.

## Fields

- `text: String`: What has been typed so far, UTF-8.
- `max_length: Optional[Int]`: The most characters typing and pasting can bring `text` to; `None` for no limit. Text assigned directly is kept as it is.

## Constructors

```mojo
@staticmethod
def __init__(out self, text: String = "", *, max_length: Optional[Int] = None)
```

Start with `text` already typed, the caret after it.

## Methods

### `update`

```mojo
def update(mut self, mut context: Context)
```

Apply one frame's typing, in the order it was typed. Takes the whole `Context` for its clipboard, which copy, cut and paste use.

### `before_caret`

```mojo
def before_caret(self) -> String
```

The text left of the caret — what to measure to place it.

### `after_caret`

```mojo
def after_caret(self) -> String
```

The text right of the caret.

### `selected_text`

```mojo
def selected_text(self) -> String
```

The selected text, empty when nothing is.

### `before_selection`

```mojo
def before_selection(self) -> String
```

The text left of the selection — what to measure to place its highlight. The same as `before_caret` when nothing is selected.

### `insert`

```mojo
def insert(mut self, typed: String)
```

Put `typed` in place of the selection, or at the caret, and move the caret past it. Cut short at `max_length`.

### `delete_backward`

```mojo
def delete_backward(mut self)
```

Delete the selection, or the character left of the caret, as Backspace does.

### `delete_forward`

```mojo
def delete_forward(mut self)
```

Delete the selection, or the character right of the caret, as Delete does.

### `delete_word_backward`

```mojo
def delete_word_backward(mut self)
```

Delete the selection, or back to the start of the word left of the caret.

### `delete_word_forward`

```mojo
def delete_word_forward(mut self)
```

Delete the selection, or on to the end of the word right of the caret.

### `move_left`

```mojo
def move_left(mut self, *, select: Bool = False)
```

Move the caret one character left, stopping at the start. With a selection and not `select`, go to its start instead.

### `move_right`

```mojo
def move_right(mut self, *, select: Bool = False)
```

Move the caret one character right, stopping at the end. With a selection and not `select`, go to its end instead.

### `move_word_left`

```mojo
def move_word_left(mut self, *, select: Bool = False)
```

Move the caret to the start of the word on its left.

### `move_word_right`

```mojo
def move_word_right(mut self, *, select: Bool = False)
```

Move the caret to the end of the word on its right.

### `move_to_start`

```mojo
def move_to_start(mut self, *, select: Bool = False)
```

### `move_to_end`

```mojo
def move_to_end(mut self, *, select: Bool = False)
```

### `select_all`

```mojo
def select_all(mut self)
```

### `cut`

```mojo
def cut(mut self, mut context: Context)
```

Put the selection on the clipboard and delete it.

### `paste`

```mojo
def paste(mut self, context: Context)
```

Insert the clipboard's text, as if typed. A line field takes one line, so a newline pastes as a space.
