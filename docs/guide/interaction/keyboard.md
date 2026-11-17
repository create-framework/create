# Keyboard

`context.keyboard` tells a program which keys are held, and which went down or came up this
frame. This page explains how keys are named, and why. Reading what the player types, as text, is
a separate job, explained in [Typing](typing.md). What every device has in common, `down`,
`pressed` and `released`, is in [Input](input.md#down-pressed-and-released).

## Reading keys

`context.keyboard.down(key)` is true while a key is held, and `pressed(key)` and `released(key)`
only in the frame it goes down or comes up:

```mojo
# In `update`: walk while an arrow is held, jump once per press of Space.
var step = 200 * context.time.delta
if context.keyboard.down(Key.LEFT):
    self.position = self.position - Vector2D(step, 0)
if context.keyboard.down(Key.RIGHT):
    self.position = self.position + Vector2D(step, 0)
if context.keyboard.pressed(Key.SPACE):
    self.jump()
```

`context.keyboard.key` is the most recently pressed key, or `Key.NONE` before any.

## Keys by position

A `Key` names a key **by where it sits**, not by the letter printed on it. Each constant names
the key in that place on a US keyboard, so `Key.W` is the key above `S` on every keyboard, even a
French one, where that key is labelled Z. This is what games want: movement on W, A, S and D lands
under the same fingers whatever keyboard the player has.

Because a `Key` is a place on the keyboard, it never tells you which character the player meant to
type. Characters come from `context.keyboard.text` instead, which applies Shift, the keyboard's
layout and everything else that turns key presses into text (see [Typing](typing.md)).

## Modifier keys

`Key.CTRL`, `Key.SHIFT`, `Key.ALT` and `Key.SUPER` match the key on either side of the keyboard,
so `down(Key.SHIFT)` is true while either Shift is held. To tell the two sides apart, use
`LEFT_SHIFT` and `RIGHT_SHIFT`, and likewise for the others. (`SUPER` is the Windows key on a PC
and Command on a Mac.)

## Key bindings

`Key.from_name(name)` turns a name into a key. The names are those of the constants, in upper
or lower case, such as `"a"`, `"up"`, `"page_up"` or `"left_ctrl"`, and a single character
names the key that types it on a US keyboard, such as `"/"` or `"7"`. This lets a program keep its
controls in a settings file the player can edit. A name that isn't a key gives `None`, so a
mistyped setting can fall back to a default:

```mojo
# In `create`: the jump key, read from a settings file, Space if it isn't a key.
var settings = JSON.load("settings.json")
var jump_key = Key.from_name(settings["jump"].string()).or_else(Key.SPACE)
```
