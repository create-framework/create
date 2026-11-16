# GamepadButton

```mojo
struct GamepadButton
```

A gamepad button, for `Gamepad.down`/`pressed`/`released`.

Matches SDL's own button numbering. The face buttons are named by
position, not label, because the labels disagree: `SOUTH` is Xbox A,
PlayStation Cross and Nintendo B alike — the button a thumb rests on, so
the one to confirm with. `BACK`/`START` are the two small centre buttons
(View/Menu, Share/Options, -/+), `GUIDE` the logo button between them.

A wrapped button number rather than a bare `Int`, like `Key`, so a stray
number cannot be passed where a button is expected.

`NONE` is no button, what `Gamepad.button` reads before any press (SDL's
invalid button, since `SOUTH` is 0); it is never down.

Implements `Copyable`, `Deinitable`, `Equatable`, `ImplicitlyCopyable`, `Movable`, `Writable`.

## Constants

- `NONE = GamepadButton(Int(-1))`
- `SOUTH = GamepadButton(Int(0))`
- `EAST = GamepadButton(Int(1))`
- `WEST = GamepadButton(Int(2))`
- `NORTH = GamepadButton(Int(3))`
- `BACK = GamepadButton(Int(4))`
- `GUIDE = GamepadButton(Int(5))`
- `START = GamepadButton(Int(6))`
- `LEFT_STICK = GamepadButton(Int(7))`: Clicking the left stick in.
- `RIGHT_STICK = GamepadButton(Int(8))`
- `LEFT_SHOULDER = GamepadButton(Int(9))`
- `RIGHT_SHOULDER = GamepadButton(Int(10))`
- `DPAD_UP = GamepadButton(Int(11))`
- `DPAD_DOWN = GamepadButton(Int(12))`
- `DPAD_LEFT = GamepadButton(Int(13))`
- `DPAD_RIGHT = GamepadButton(Int(14))`
- `MISC_1 = GamepadButton(Int(15))`: The extra centre button: Xbox Share, PlayStation microphone, Switch capture.
- `RIGHT_PADDLE_1 = GamepadButton(Int(16))`
- `LEFT_PADDLE_1 = GamepadButton(Int(17))`
- `RIGHT_PADDLE_2 = GamepadButton(Int(18))`
- `LEFT_PADDLE_2 = GamepadButton(Int(19))`
- `TOUCHPAD = GamepadButton(Int(20))`: Pressing the PlayStation touchpad.
- `MISC_2 = GamepadButton(Int(21))`
- `MISC_3 = GamepadButton(Int(22))`
- `MISC_4 = GamepadButton(Int(23))`
- `MISC_5 = GamepadButton(Int(24))`
- `MISC_6 = GamepadButton(Int(25))`
- `LEFT_TRIGGER = GamepadButton(Int(26))`: The left trigger pulled past halfway, read as a button: not one SDL sends, but worked out from `Gamepad.left_trigger` so a pull has edges.
- `RIGHT_TRIGGER = GamepadButton(Int(27))`: The right trigger pulled past halfway, like `LEFT_TRIGGER`.

## Fields

- `value: Int`

## Constructors

```mojo
@staticmethod
def __init__(out self, value: Int)
```

## Methods

### `from_name`

```mojo
@staticmethod
def from_name(name: String) -> Optional[Self]
```

The button whose constant is `name`, case folded: `"south"`, `"start"`, `"right_trigger"`. `None` for an unknown name — for a binding read from a file, where a misspelled constant would have failed to compile.

## Special methods

### `__eq__`

```mojo
def __eq__(self, other: Self) -> Bool
```

### `__ne__`

```mojo
def __ne__(self, other: Self) -> Bool
```
