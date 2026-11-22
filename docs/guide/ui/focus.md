# Focus and navigation

A UI isn't only clicked: a player at a keyboard tabs through it, and one holding a gamepad moves
round it with the d-pad. This page explains focus, the one widget the keys and buttons act on, how
it moves, how it is shown, and how a game keeps its own keys and clicks apart from the UI's.

## Focus

**At most one widget has focus.** Keys act on it, typed text goes into it if it is a text field, and
a ring is drawn round it so the player can see where they are. Focus moves in several ways:

- **A click** on a widget gives it focus. A click where there is no widget, or on a panel's
  background, takes focus away.
- **Tab and Shift+Tab** move it to the next or previous widget, in the order the widgets were
  called, skipping disabled ones and wrapping round at the ends.
- **A gamepad's d-pad or left stick** moves it to the nearest widget in that direction, judged from
  where the widgets are on the screen rather than the order they were called.
- **`take_focus=True`** on a call gives that widget focus in the frame it is passed, which every
  widget that reacts accepts. A dialog passes it to its first field in the frame it opens; a typing
  game passes it every frame, so its field keeps focus even after a click elsewhere.
- **Escape**, or a gamepad's east button, takes focus away. So does disabling the focused widget, or
  no longer calling it.

```mojo
# In `update`, inside `with self.ui.screen(context, canvas) as ui:`: focus
# the name field as the dialog opens.
ui.text_field(self.name, Rectangle((0, 40), 320, 40), take_focus=self.just_opened)
```

## The keys and buttons

What acts on the focused widget:

| Widget | Keyboard | Gamepad |
|---|---|---|
| Button | Enter or Space presses it | South (A on Xbox) presses it |
| Checkbox | Enter or Space switches it | South switches it |
| Slider | The arrows step it, Home and End jump to its ends | Left and right step it |
| Text field | Typing and the editing keys (see [Typing](../interaction/typing.md#text-fields)); Enter submits | The d-pad moves focus on |

A slider steps by its `step`, or by a twentieth of its range without one, and always lands on a
whole number of steps from `min`.

**Keys act only on focus from the keyboard, a gamepad or `take_focus`, not on focus from a click.**
A button the player just clicked has focus, but Space doesn't press it again: in a game, Space
usually belongs to the game. A text field is the exception, since it takes typing however it got
focus.

## Focus rings

**A focused widget shows a ring round it when focus came from the keyboard, a gamepad or
`take_focus`.** After a click, the pointer already shows where the player is, so no ring is drawn.
The ring follows the widget's shape, its corners rounded by the widget's own radius grown by the gap
between them: a pill round a round-ended button, a circle round a slider's handle. A text field
shows focus its own way instead, by a thicker outline in the theme's `primary` colour and its caret.

The ring's thickness, gap and colour come from the theme's `focus_ring`, and `focus_ring=` on a
widget's style changes it for that widget (see [Themes and styling](themes.md)).

## Keeping the game's input apart

A game reads the same keyboard and mouse as its UI, so a click on a menu button could also fire a
weapon, and typing a name with W in it could walk the player forward. Two readings on the `UI` say
when the input is the UI's:

- **`ui.wants_mouse()`** is true while the pointer is over a widget, or a widget is held, such as a
  slider being dragged.
- **`ui.wants_keyboard()`** is true while a text field has focus, while a widget has focus from the
  keyboard (so the keys act on it), and in the frame a key took focus away, such as the Escape that
  leaves a field.

Check them before reading input for the game itself. They are read on the `UI` field, so they work
before or after the UI's block:

```mojo
# In `update`, with a `ui: UI` field:
if context.mouse.pressed() and not self.ui.wants_mouse():
    self.fire()
if context.keyboard.pressed(Key.ESCAPE) and not self.ui.wants_keyboard():
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
- **Gamepads** don't take turns: `UI(theme, player=n)` listens to one player's pad only, so each
  player's menu follows its own pad. Without `player`, any pad drives the `UI`.

```mojo
# In `create`, building two players' menus:
var left = UI(Theme.from_seed(Color.hex(0xD04040)), player=0)
var right = UI(Theme.from_seed(Color.hex(0x4060D0)), player=1)
```
