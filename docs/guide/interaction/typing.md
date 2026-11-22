# Typing

Reading keys tells a program which keys are held; typing is something else. A player typing their
name expects capitals when they hold Shift, accents on a French keyboard and characters composed
with an input method when they write Japanese. This page explains how to take typed text and how a
`text_field` turns it into a working text field with a caret, a selection and the clipboard.

## Typed text

The keyboard has two readings for typing, and both are fresh every frame:

- **`context.keyboard.text`** is the characters typed this frame, as a UTF-8 string, with Shift, the
  keyboard's layout and any input method already applied. Add it to your text as it is, and don't
  try to work characters out from key presses: a `Key` names a place on the keyboard, not the
  character it types (see [Keyboard](keyboard.md#keys-by-position)).
- **`keyboard.typed(key)`** is true when a key is pressed, and again each time it repeats while
  held, as keys do in a text editor. It is the one to use for editing keys such as Backspace and the
  arrows, so that holding Backspace keeps deleting.

These two are enough to build a simple text field yourself, but a good one takes more work than it
seems: a caret, a selection, deleting whole characters rather than bytes, copy and paste. A
`text_field`, below, does all of that.

## Switching text input off

Taking text is on by default, and while it is on, the system may open an input method's window or a
handheld's on-screen keyboard. So a game played on letter keys should switch it off with
`context.text_input(False)`. A `text_field` switches it on while it has focus and off again when it
loses it, and leaves it alone otherwise. Switching it off changes only `text`, which then stays
empty; `down`, `pressed` and `released` read the keys as before.

## Text fields

**`ui.text_field`** is a complete text field: a box to type in, with a caret, a selection and the
clipboard. Like every widget, it is called each frame inside a `UI`'s layer, and edits a `String`
the program keeps:

```mojo
# In `update`, with `ui: UI` and `name: String` fields:
with self.ui.screen(context, canvas) as ui:
    ui.text_field(self.name, Rectangle((0, 0), 320, 40), placeholder="Your name")
    if ui.submitted():  # Enter was pressed
        self.start_game(self.name)
```

Clicking the field gives it focus and puts the caret where it was clicked, and Tab reaches it from
the keyboard. While it has focus, it takes the frame's typing and editing keys in the order they
came, so text and keys typed within one frame land where they were typed. It always moves and
deletes whole characters, so an accented letter is never split in half, and it handles the keys
people expect:

- Backspace and Delete delete, and the arrows, Home and End move the caret. Holding Shift while
  moving extends the selection.
- A word modifier (Option on macOS, Ctrl elsewhere) moves and deletes a word at a time.
- The command shortcuts (Cmd on macOS, Ctrl elsewhere) select all, copy, cut and paste. They go by
  the letter printed on the key, not its position, so they work on every layout.
- Enter submits the field: `ui.submitted()`, right after the field, is true in that frame, and what
  it means is the program's to decide. Escape leaves the field.

Copying and pasting go through the system clipboard, which a program can also use directly:
`context.clipboard()` reads it and `context.clipboard(text)` sets it.

`max_length=` caps how many characters the field can hold: typing and pasting stop adding once it is
full. The text is the program's own `String`, so the program can set it at any time, for example
`self.name = ""` to empty the field once it has been submitted. While a field has focus,
`self.ui.wants_keyboard()` is true, so a game can leave the keys alone while the player types.

**Drawing the text yourself.** `ui.text_editor()`, right after the field, gives its `TextEditor`,
which says where its caret and selection are: `before_caret()` is the text before the caret,
`before_selection()` the text before the selection, and `selected_text()` the selection itself, to
measure with `canvas.text_width`. A `TextFieldStyle` with a transparent container, text colour and
no outline draws nothing but the caret and the selection, so the program can draw the letters its
own way, and `take_focus=True` keeps the field focused without a click. See
[examples/typing](../../../examples/typing/main.mojo), which colours each typed letter by whether it
is right.

**Editing from the program.** The same `TextEditor` edits the field through the methods typing uses:
`insert`, `delete_backward`, `delete_forward`, the moves, `select_all`, `copy`, `cut` and `paste`.
So the program's own keys or buttons can drive the field. An edit reaches `text` the next time the
field is called, as typing does, and `ui.changed()` reports it then.
