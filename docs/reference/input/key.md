# Key

```mojo
struct Key
```

A key by its position on the keyboard, what the `Keyboard` queries take: `context.keyboard.down(Key.UP)`.

**Positional.** Each constant names a key by where it sits on a US
layout, whatever the layout prints on it: `Key.W` is the key above `S`,
which an AZERTY keyboard labels Z, so WASD movement lands under the same
fingers on every keyboard. Characters are what the layout makes of those
keys, and come from `context.keyboard.text`, never from a `Key`. So read
keys for controls, and text for what the user typed.

`from_name` maps a key's name (`"up"`, `"page_up"`, `"a"`) to it, for a
binding read from a file; a misspelled constant fails to compile, where
a name could only fail to match.

A wrapped SDL scancode rather than a bare `Int`, so a stray number cannot
be passed where a key is expected. `Key(scancode)` names any key SDL can
send, the ones without a constant included.

`NONE` is no key (SDL's unknown scancode), what `Keyboard.key` reads
before any press; it is never down.

`CTRL`, `SHIFT`, `ALT` and `SUPER` are either side of a modifier: down
while the left or the right one is. They are queries only, never a key
SDL sends, so `Keyboard.key` is always the side that was pressed.

Implements `Copyable`, `Deinitable`, `Equatable`, `ImplicitlyCopyable`, `Movable`, `Writable`.

## Constants

- `NONE = Key(Int(0))`
- `LEFT_CTRL = Key(Int(224))`
- `RIGHT_CTRL = Key(Int(228))`
- `LEFT_SHIFT = Key(Int(225))`
- `RIGHT_SHIFT = Key(Int(229))`
- `LEFT_ALT = Key(Int(226))`
- `RIGHT_ALT = Key(Int(230))`
- `LEFT_SUPER = Key(Int(227))`
- `RIGHT_SUPER = Key(Int(231))`
- `CTRL = Key(Int(-1))`
- `SHIFT = Key(Int(-2))`
- `ALT = Key(Int(-3))`
- `SUPER = Key(Int(-4))`
- `UP = Key(Int(82))`
- `DOWN = Key(Int(81))`
- `LEFT = Key(Int(80))`
- `RIGHT = Key(Int(79))`
- `INSERT = Key(Int(73))`
- `HOME = Key(Int(74))`
- `PAGE_UP = Key(Int(75))`
- `PAGE_DOWN = Key(Int(78))`
- `END = Key(Int(77))`
- `ENTER = Key(Int(40))`
- `ESCAPE = Key(Int(41))`
- `BACKSPACE = Key(Int(42))`
- `TAB = Key(Int(43))`
- `SPACE = Key(Int(44))`
- `DELETE = Key(Int(76))`
- `CAPS_LOCK = Key(Int(57))`
- `F1 = Key(Int(58))`
- `F2 = Key(Int(59))`
- `F3 = Key(Int(60))`
- `F4 = Key(Int(61))`
- `F5 = Key(Int(62))`
- `F6 = Key(Int(63))`
- `F7 = Key(Int(64))`
- `F8 = Key(Int(65))`
- `F9 = Key(Int(66))`
- `F10 = Key(Int(67))`
- `F11 = Key(Int(68))`
- `F12 = Key(Int(69))`
- `A = Key(Int(4))`
- `B = Key(Int(5))`
- `C = Key(Int(6))`
- `D = Key(Int(7))`
- `E = Key(Int(8))`
- `F = Key(Int(9))`
- `G = Key(Int(10))`
- `H = Key(Int(11))`
- `I = Key(Int(12))`
- `J = Key(Int(13))`
- `K = Key(Int(14))`
- `L = Key(Int(15))`
- `M = Key(Int(16))`
- `N = Key(Int(17))`
- `O = Key(Int(18))`
- `P = Key(Int(19))`
- `Q = Key(Int(20))`
- `R = Key(Int(21))`
- `S = Key(Int(22))`
- `T = Key(Int(23))`
- `U = Key(Int(24))`
- `V = Key(Int(25))`
- `W = Key(Int(26))`
- `X = Key(Int(27))`
- `Y = Key(Int(28))`
- `Z = Key(Int(29))`
- `ONE = Key(Int(30))`
- `TWO = Key(Int(31))`
- `THREE = Key(Int(32))`
- `FOUR = Key(Int(33))`
- `FIVE = Key(Int(34))`
- `SIX = Key(Int(35))`
- `SEVEN = Key(Int(36))`
- `EIGHT = Key(Int(37))`
- `NINE = Key(Int(38))`
- `ZERO = Key(Int(39))`
- `MINUS = Key(Int(45))`
- `EQUALS = Key(Int(46))`
- `LEFT_BRACKET = Key(Int(47))`
- `RIGHT_BRACKET = Key(Int(48))`
- `BACKSLASH = Key(Int(49))`
- `SEMICOLON = Key(Int(51))`
- `APOSTROPHE = Key(Int(52))`
- `GRAVE = Key(Int(53))`
- `COMMA = Key(Int(54))`
- `PERIOD = Key(Int(55))`
- `SLASH = Key(Int(56))`

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

The key whose constant is `name`, case folded: `"up"`, `"page_up"`, `"f1"`, `"left_ctrl"`, `"a"`, `"zero"`, `"slash"`. A single character is the key that types it unshifted on a US layout, so `"/"`, `"7"` and `"A"` work too. `None` for an unknown name.

## Special methods

### `__eq__`

```mojo
def __eq__(self, other: Self) -> Bool
```

### `__ne__`

```mojo
def __ne__(self, other: Self) -> Bool
```
