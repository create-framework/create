# Gamepad

```mojo
struct Gamepad
```

One gamepad's state for one frame, read as `context.gamepad(player)`.

Buttons follow the vocabulary every device shares: *down* is held right now,
*pressed*/*released* are the edges, true only in the frame the button
went down or came up. Name buttons through `GamepadButton`.

Sticks are `Vector2D`s in screen orientation — y up, like every other
direction in the library — inside the unit circle, so
`position += pad.left_stick * speed * context.time.delta` moves at
`speed` at full tilt and never faster on a diagonal. Each has a radial
dead zone of `STICK_DEAD_ZONE`, rescaled so the stick still eases up
from zero past it: a resting stick reads exactly `Vector2D.ZERO` rather
than drifting. Triggers are 0 (released) to 1 (pulled all the way), and
also buttons, `GamepadButton.LEFT_TRIGGER`/`RIGHT_TRIGGER`, so "fire on
pull" is `pad.pressed(GamepadButton.RIGHT_TRIGGER)`: down from
`TRIGGER_PRESS` and up again below `TRIGGER_RELEASE`, so a trigger held
near halfway doesn't flicker between the two.

A slot that holds no gamepad reads all zero and `connected` False, so a
program can read player two's pad before one is plugged in.
`connected_this_frame` and `disconnected_this_frame` are the edges of
`connected`, true only in the frame the pad arrived or left — the frame
to show "Player 2 joined" or to pause. In the frame a pad leaves, its
slot still has its `name`, so the message can say which.

Implements `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `Writable`.

## Constants

- `STICK_DEAD_ZONE = 0.20000000000000001`: How far a stick moves before it reads anything, as a fraction of full tilt. A resting stick sits up to about a quarter of the way off centre on a worn pad; 0.2 hides that on most without making small moves sluggish.
- `TRIGGER_PRESS = 0.5`: How far a trigger is pulled before it reads as its button down.
- `TRIGGER_RELEASE = 0.40000000000000002`: How far a trigger falls back before its button reads up again: below `TRIGGER_PRESS`, so a pull resting near the line stays one press.

## Fields

- `connected: Bool`
- `connected_this_frame: Bool`
- `disconnected_this_frame: Bool`
- `name: String`
- `left_stick: Vector2D`
- `right_stick: Vector2D`
- `left_trigger: Float64`
- `right_trigger: Float64`
- `button: GamepadButton`

## Constructors

```mojo
@staticmethod
def __init__(out self)
```

## Methods

### `down`

```mojo
def down(self, button: GamepadButton) -> Bool
```

Whether `button` is held right now.

### `pressed`

```mojo
def pressed(self, button: GamepadButton) -> Bool
```

Whether `button` went down this frame: true once per press.

### `released`

```mojo
def released(self, button: GamepadButton) -> Bool
```

Whether `button` came up this frame: true once per release.
