# Typing

Reading keys tells a program which keys are held; typing is something else. A player typing their
name expects capitals when they hold Shift, accents on a French keyboard and characters composed
with an input method when they write Japanese. This page explains how to take typed text and how a
`TextField` turns it into a working text field with a caret, a selection and the clipboard.

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
`TextField`, below, does all of that.

## Switching text input off

Taking text is on by default, and while it is on, the system may open an input method's window or a
handheld's on-screen keyboard. So a game played on letter keys should switch it off with
`context.text_input(False)`. A `TextField` switches it on while it has focus and off again when it
loses it, and leaves it alone otherwise. Switching it off changes only `text`, which then stays
empty; `down`, `pressed` and `released` read the keys as before.

## Text fields

**A `TextField`** is a complete text field: a box to type in, with a caret, a selection and the
clipboard. Like every widget, it is a value the program keeps, updates and draws (see
[Widgets](../ui/widgets.md)), and it holds the text typed into it:

```mojo
# In `create`, building the `name` field:
var name = TextField(Rectangle((0, 0), 320, 40), placeholder="Your name")

# In `update`:
self.name.update(context, canvas)
canvas.draw(self.name)
if self.name.submitted():  # Enter was pressed
    self.start_game(self.name.text())
```

Clicking the field gives it focus and puts the caret where it was clicked; a click elsewhere, or
Escape, takes focus away. In a `UI`, Tab reaches it from the keyboard too (see [Focus and
navigation](../ui/focus.md)). While it has focus, it takes the frame's typing and editing keys in
the order they came, so text and keys typed within one frame land where they were typed. It always
moves and deletes whole characters, so an accented letter is never split in half, and it handles the
keys people expect:

- Backspace and Delete delete, and the arrows, Home and End move the caret. Holding Shift while
  moving extends the selection.
- A word modifier (Option on macOS, Ctrl elsewhere) moves and deletes a word at a time.
- The command shortcuts (Cmd on macOS, Ctrl elsewhere) select all, copy, cut and paste. They go by
  the letter printed on the key, not its position, so they work on every layout.
- Enter submits the field: `submitted()` is true in that frame, and what it means is the program's
  to decide. Escape leaves the field.

Copying and pasting go through the system clipboard, which a program can also use directly:
`context.clipboard()` reads it and `context.clipboard(text)` sets it.

`text()` is what has been typed, and `changed()` is true in the frame typing changed it.
`set_text(text)` replaces it from the program, such as `self.name.set_text("")` to empty the field
once it has been submitted; that isn't reported as a change. `max_length=` caps how many characters
the field can hold: typing and pasting stop adding once it is full. In a `UI`, while a field has
focus, `self.ui.wants_keyboard(context)` is true, so a game can leave the keys alone while the
player types.

**Focus from the program.** `field.focus()` gives a field on its own focus, as a click would, and
`field.focus(False)` takes it away; `field.focused()` reads it. A typing game gives its field focus
every frame, so typing keeps going to it even after a click elsewhere. In a `UI`, the `UI` decides
focus instead: `ui.focus(handle)` gives it.

**Drawing the text yourself.** The field says where its caret and selection are: `before_caret()` is
the text before the caret, `before_selection()` the text before the selection, and `selected_text()`
the selection itself, to measure with `canvas.text_width`. A field whose `container` has neither
fill nor outline, and whose `text_style` makes the text transparent, draws nothing but the caret and
the selection, so the program can draw the letters its own way. See
[examples/typing](../../../examples/typing/main.mojo), which colours each typed letter by whether it
is right.

**Editing from the program.** The field's editing methods are the ones typing uses: `insert`,
`delete_backward`, `delete_forward`, the moves, `select_all`, `copy`, `cut` and `paste`. So the
program's own keys or buttons can drive the field. `changed()` reports their edits at the next
`update`, as it does typing.
