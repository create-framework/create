# Focus and navigation

A UI isn't only clicked: a player at a keyboard tabs through it, and one holding a gamepad moves
round it with the d-pad. This page explains focus, the one widget in a `UI` the keys and buttons act
on, how it moves, how it is shown, and how a game keeps its own keys and clicks apart from the UI's.

## Focus

**At most one widget in a `UI` has focus.** Keys act on it, typed text goes into it if it is a text
field, and a ring is drawn round it so the player can see where they are. Focus moves in several
ways, each worked out in `ui.update` before any widget acts:

- **A click** on a button, checkbox, slider or text field gives it focus. A click where there is no
  widget, or on a panel's background, takes focus away.
- **Tab and Shift+Tab** move it to the next or previous widget, in the order they are drawn,
  skipping disabled and hidden ones and wrapping round at the ends.
- **The arrow keys, and a gamepad's d-pad or left stick,** move it to the nearest widget in that
  direction, judged from where the widgets are on the screen rather than the order they were added.
  The arrows move it only once keys act on the focus (see [The keys and
  buttons](#the-keys-and-buttons)), so a menu that opens with `ui.focus` on its first button is
  ready for them. A direction held on a gamepad moves focus once, then again and again after a
  moment, as a held key repeats.
- **`ui.focus(handle)`** gives a widget focus from the program, with its ring showing. A dialog
  gives its first field focus as it opens.
- **Escape**, or a gamepad's east button, takes focus away, and so does `ui.clear_focus()`. So does
  disabling, hiding or removing the focused widget.

`ui.has_focus(handle)` asks whether a widget has it.

**Focus brings its widget into view.** When Tab, an arrow, a gamepad or `ui.focus` moves focus onto
a widget in a [scroll area](widgets.md#scroll-areas) that has scrolled it out of sight, the scroll
area scrolls by the least that shows all of it, its ring included, so the player never loses the
focus off the edge of a list. A click doesn't scroll, since what was clicked is in view already.

```mojo
# In `update`, with `ui: UI` and `name: WidgetHandle[TextField]` fields:
# focus the name field as the dialog opens.
if self.just_opened:
    self.ui.focus(self.name)
self.ui.update(context, canvas)
canvas.draw(self.ui)
```

A widget on its own, outside a `UI`, has no focus to move: a lone `TextField` takes focus from a
click of its own, and `field.focus()` gives it from the program (see
[Typing](../interaction/typing.md#text-fields)). In a `UI`, `ui[field].focus()` does the same as
`ui.focus(field)`, and `ui[field].focus(False)` takes focus away from the field.

## The keys and buttons

What acts on the focused widget:

| Widget | Keyboard | Gamepad |
|---|---|---|
| Button | Enter or Space presses it; the arrows move focus on | South (A on Xbox) presses it |
| Checkbox | Enter or Space ticks or unticks it; the arrows move focus on | South ticks or unticks it |
| Slider | Left and right step it, Home and End jump to its ends; up and down move focus on | Left and right step it; up and down move focus on |
| Switch | Enter or Space turns it over; the arrows move focus on | South turns it over |
| Choice group | Up and down move the choice; left and right move focus on | Up and down move the choice; left and right move focus on |
| Tabs | Left and right move the selection; up and down move focus on | Left and right move the selection; up and down move focus on |
| Text field | Typing and the editing keys, the arrows included (see [Typing](../interaction/typing.md#text-fields)); Enter submits | The d-pad moves focus on |
| Number field | As a text field, and up and down step it | Up and down step it; left and right move focus on |
| Dropdown | Enter or Space opens it; while open, up and down move the mark, Enter or Space chooses, Escape closes it, Tab closes it and moves on | South opens it; while open, up and down move the mark, south chooses, east closes it |

**An open dropdown takes every key itself.** While its list is open, the arrows and the gamepad's
push move the mark in it rather than focus, and Escape or the east button close the list rather than
taking focus away, so the player backs out one step at a time. This holds even when a click opened
it.

A button pressed with a key or the gamepad reports it as `released()`, as a click does, so one `if`
handles both. A slider steps by its `step`, or by a twentieth of its range without one, and always
lands on a whole number of steps from its `minimum`.

**Keys act only on focus from the keyboard, a gamepad or `ui.focus`, not on focus from a click.** A
button the player just clicked has focus, but Space doesn't press it again: in a game, Space usually
belongs to the game. The arrows are the same: after a click they still move the player, not the
focus. A text field is the exception, since it takes typing however it got focus.

## Focus rings

**A focused widget shows a ring round it when focus came from the keyboard, a gamepad or
`ui.focus`.** After a click, the pointer already shows where the player is, so no ring is drawn. The
ring follows the widget's shape, its corners rounded by the widget's own radius grown by the gap
between them: a rounded rectangle round a button or a slider's handle, a circle round a chosen
option. It is drawn after every widget, so nothing covers it. A text field shows focus its own way
instead, by a thicker outline in the `primary` colour and its caret.

The ring's thickness, gap and colour come from the `UI`'s `focus_ring`, a `FocusRing`; its colour is
the colours' `primary` unless it sets one; it is 2 thick, 2 away from the widget.
`self.ui.focus_ring(ring)` changes it (see [Sizes and states](themes.md#sizes-and-states)).

## Keeping the game's input apart

A game reads the same keyboard and mouse as its UI, so a click on a menu button could also fire a
weapon, and typing a name with W in it could walk the player forward. Two readings on the `UI` say
when the input is the UI's:

- **`self.ui.wants_mouse(context)`** is true while the pointer is over one of its widgets, or one is
  held, such as a slider being dragged.
- **`self.ui.wants_keyboard(context)`** is true while a text field has focus, while a widget has
  focus from the keyboard (so the keys act on it), and in the frame a key acted on the UI, such as
  the Escape that leaves a field.

Check them after `ui.update`, before reading input for the game itself. A `UI` not updated this
frame or last, such as a menu that has closed, wants neither:

```mojo
# In `update`, with a `ui: UI` field, after `self.ui.update(context, canvas)`:
if context.mouse.pressed() and not self.ui.wants_mouse(context):
    self.fire()
if context.keyboard.pressed(Key.ESCAPE) and not self.ui.wants_keyboard(context):
    self.paused = not self.paused
```

A text field also switches `context.text_input` on while it has focus, and off again when it loses
it (see [Typing](../interaction/typing.md#switching-text-input-off)).

## Several UIs

Widgets the player moves between belong in **one `UI`**: Tab, the d-pad and focus all stay within a
`UI`. A program can still have more than one, for groups that are separate, such as each player's
menu in a split-screen game. They take turns at the devices:

- **The keyboard** is held by the `UI` whose focus takes keys. Another `UI` then ignores Tab, typing
  and the other keys, and a click in it takes the keyboard over.
- **The mouse** is held by the `UI` with a widget held, so dragging a slider in one doesn't press a
  button in another.
- **Gamepads** don't take turns: `UI(player=n)` listens to one player's pad only, so each player's
  menu follows its own pad. Without `player`, any pad drives the `UI`.

```mojo
# In `create`, building two players' menus, each in its own colours:
var left = UI(player=0)
left.colors(ColorScheme.from_seed(Color.hex(0xD04040)))
var right = UI(player=1)
right.colors(ColorScheme.from_seed(Color.hex(0x4060D0)))
```
