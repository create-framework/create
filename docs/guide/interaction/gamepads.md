# Gamepads

Create reads game controllers, such as Xbox and PlayStation pads, for one player or several. This
page explains how pads are numbered, how to read their sticks, triggers and buttons, and how to make
one rumble. What every device has in common (`down`, `pressed` and `released`) is in
[Input](input.md#down-pressed-and-released).

## Reading a pad

`context.gamepad(player)` is a copy of player `player`'s pad, and `context.gamepad()` is player 0's:

```mojo
# In `update`:
var pad = context.gamepad()
self.position = self.position + pad.left_stick * 300 * context.time.delta
if pad.pressed(GamepadButton.SOUTH):  # Xbox A, PlayStation Cross
    context.rumble(0.2)
```

The copy is a snapshot of the pad for this frame, so read it once at the start of `update` and use
it from there.

## Players and connecting

A pad takes the lowest free player number when it connects, and keeps it until it disconnects. So
the first pad plugged in is player 0, the second player 1, and if player 0's pad is unplugged, the
next pad to connect takes its place.

A player with no pad reads `connected` as `False`, with every stick, trigger and button at zero, so
a program can read any player without checking first; an empty slot simply does nothing.
`connected_this_frame` and `disconnected_this_frame` are true only in the frame the pad connects or
disconnects, as `pressed` and `released` are for a button. Use them for a "controller disconnected"
message, for example. `name` is the pad's name as the system reports it, and still holds it in the
frame the pad disconnects.

## Sticks

The sticks, `left_stick` and `right_stick`, are `Vector2D`s, with **y increasing upwards** like
everything else in Create, and never longer than 1: pushed fully in any direction, a stick's length
is 1.

A stick at rest seldom sits exactly at its centre, which would make a character drift on its own. So
a small dead zone round the centre (`Gamepad.STICK_DEAD_ZONE`, the inner 0.2 of the way out) reads
as zero. Past it, the reading starts again from zero and still reaches 1 at the rim, so a slight
push gives a slight value rather than a jump.

## Triggers

The triggers, `left_trigger` and `right_trigger`, run from 0 (released) to 1 (pulled fully), for an
accelerator that can be pressed partway.

Each trigger is also a button, `GamepadButton.LEFT_TRIGGER` and `RIGHT_TRIGGER`, for when only
"pulled or not" matters. It goes down once pulled past `Gamepad.TRIGGER_PRESS` (0.5), and only comes
up again once released below `Gamepad.TRIGGER_RELEASE` (0.4). The gap between the two keeps a
trigger held near halfway from flickering between down and up, so
`pad.pressed(GamepadButton.RIGHT_TRIGGER)` fires exactly once per pull.

## Buttons

The face buttons are named by **position**, because their labels differ from one brand of pad to the
next: `SOUTH` is the bottom button (A on an Xbox pad, Cross on a PlayStation pad), and `EAST`,
`WEST` and `NORTH` are the others. So the same code works on every pad, as `Key` does on every
keyboard.

The other buttons are named for what they are:

- the d-pad: `DPAD_UP`, `DPAD_DOWN`, `DPAD_LEFT` and `DPAD_RIGHT`;
- the shoulder buttons above the triggers: `LEFT_SHOULDER` and `RIGHT_SHOULDER`;
- the sticks, which click when pressed in: `LEFT_STICK` and `RIGHT_STICK`;
- the buttons in the middle: `START`, `BACK` and `GUIDE` (the button with the brand's logo).

`pad.button` is the most recently pressed button, or `GamepadButton.NONE` before any.

## Rumble

`context.rumble(seconds)` makes player 0's pad rumble for that long. Optional `low_frequency=` and
`high_frequency=` set the strengths of the pad's heavy and light motors, from 0 to 1 and both full
by default, and `player=` picks another pad. A new rumble replaces one that is still running.

Rumbling is something the program does to a pad rather than something it reads from one, so it lives
on the `Context`, not on the `Gamepad` copy. It takes effect when `update` returns.

See [examples/gamepad](../../../examples/gamepad/main.mojo).
