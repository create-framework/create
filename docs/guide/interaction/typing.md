# Typing

Reading keys tells a program which keys are held; typing is something else. A player typing their
name expects capitals when they hold Shift, accents on a French keyboard, and characters composed
with an input method when they write Japanese. This page explains how to take typed text, and how
`EditableText` turns it into a working text field with a caret, a selection and the clipboard.

## Typed text

The keyboard has two readings for typing, and both are fresh every frame:

- **`context.keyboard.text`** is the characters typed this frame, as a UTF-8 string, with Shift,
  the keyboard's layout and any input method already applied. Add it to your text as it is, and
  don't try to work characters out from key presses: a `Key` names a place on the keyboard, not the
  character it types (see [Keyboard](keyboard.md#keys-by-position)).
- **`keyboard.typed(key)`** is true when a key is pressed, and again each time it repeats while
  held, as keys do in a text editor. It is the one to use for editing keys such as Backspace and
  the arrows, so that holding Backspace keeps deleting.

These two are enough to build a simple text field yourself, but a good one takes more work than
it seems: a caret, a selection, deleting whole characters rather than bytes, copy and paste.
`EditableText`, below, does all of that.

## Switching text input off

Taking text is on by default, and while it is on, the system may open an input method's window or
a handheld's on-screen keyboard. So a game played on letter keys should switch it off with
`context.text_input(False)`, and switch it on again only while a text field is in use. Switching
it off changes only `text`, which then stays empty; `down`, `pressed` and `released` read the keys
just as before.

## Text fields

**`EditableText`** does all the editing for a text field. Keep one as a field, update it every
frame, and draw its text:

```mojo
# In `update`, with an `EditableText` field `name`:
self.name.update(context)
canvas.text(self.name.text, (0, 0))
var caret_x = canvas.text_width(self.name.before_caret())
```

`field.update(context)` takes the frame's typing and editing keys, in the order they came, so text
and keys typed within one frame land where they were typed. It keeps `text`, a caret and a
selection, and always moves and deletes whole characters, so an accented letter is never split
in half. It handles the keys people expect:

- Backspace and Delete delete, and the arrows, Home and End move the caret. Holding Shift while
  moving extends the selection.
- A word modifier (Option on macOS, Ctrl elsewhere) moves and deletes a word at a time.
- The command shortcuts (Cmd on macOS, Ctrl elsewhere) select all, copy, cut and paste. They go by
  the letter printed on the key, not its position, so they work on every layout.

Copying and pasting go through the system clipboard, which a program can also use directly:
`context.clipboard()` reads it and `context.clipboard(text)` sets it.

`EditableText(max_length=...)` caps how many characters the field can hold: typing and pasting
stop adding once it is full.

Two things are left to the program: what Enter does, such as submitting a name or starting a new
line, which only the program can decide, and clicking into the text, since only the program knows
where the text is drawn. `text` is a plain field, so the program can also set it, for example
`self.name.text = ""` to empty the field once it has been submitted.

**Drawing the caret and selection** is left to the program, since only it knows how the field
should look. Measure the text before each with `canvas.text_width`: `before_caret()` is the text
before the caret, `before_selection()` the text before the selection, and `selected_text()` the
selection itself. See [examples/typing](../../../examples/typing/main.mojo) for a complete field.
