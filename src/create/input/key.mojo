struct Key(Copyable, Equatable, ImplicitlyCopyable, Movable, Writable):
    """A key by its position on the keyboard, what the `Keyboard` queries
    take: `context.keyboard.down(Key.UP)`.

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
    """

    var value: Int

    comptime NONE = Key(0)

    # Modifier keys
    comptime LEFT_CTRL = Key(224)
    comptime RIGHT_CTRL = Key(228)
    comptime LEFT_SHIFT = Key(225)
    comptime RIGHT_SHIFT = Key(229)
    comptime LEFT_ALT = Key(226)
    comptime RIGHT_ALT = Key(230)
    comptime LEFT_SUPER = Key(227)
    comptime RIGHT_SUPER = Key(231)

    # Either side of a modifier. Negative, so no SDL scancode collides.
    comptime CTRL = Key(-1)
    comptime SHIFT = Key(-2)
    comptime ALT = Key(-3)
    comptime SUPER = Key(-4)

    # Arrow keys
    comptime UP = Key(82)
    comptime DOWN = Key(81)
    comptime LEFT = Key(80)
    comptime RIGHT = Key(79)

    # Navigation
    comptime INSERT = Key(73)
    comptime HOME = Key(74)
    comptime PAGE_UP = Key(75)
    comptime PAGE_DOWN = Key(78)
    comptime END = Key(77)

    # Common keys
    comptime ENTER = Key(40)
    comptime ESCAPE = Key(41)
    comptime BACKSPACE = Key(42)
    comptime TAB = Key(43)
    comptime SPACE = Key(44)
    comptime DELETE = Key(76)
    comptime CAPS_LOCK = Key(57)

    # Function keys
    comptime F1 = Key(58)
    comptime F2 = Key(59)
    comptime F3 = Key(60)
    comptime F4 = Key(61)
    comptime F5 = Key(62)
    comptime F6 = Key(63)
    comptime F7 = Key(64)
    comptime F8 = Key(65)
    comptime F9 = Key(66)
    comptime F10 = Key(67)
    comptime F11 = Key(68)
    comptime F12 = Key(69)

    # Letter keys, by their place on a US layout
    comptime A = Key(4)
    comptime B = Key(5)
    comptime C = Key(6)
    comptime D = Key(7)
    comptime E = Key(8)
    comptime F = Key(9)
    comptime G = Key(10)
    comptime H = Key(11)
    comptime I = Key(12)
    comptime J = Key(13)
    comptime K = Key(14)
    comptime L = Key(15)
    comptime M = Key(16)
    comptime N = Key(17)
    comptime O = Key(18)
    comptime P = Key(19)
    comptime Q = Key(20)
    comptime R = Key(21)
    comptime S = Key(22)
    comptime T = Key(23)
    comptime U = Key(24)
    comptime V = Key(25)
    comptime W = Key(26)
    comptime X = Key(27)
    comptime Y = Key(28)
    comptime Z = Key(29)

    # Digits on the main row, named in words as the punctuation keys are.
    comptime ONE = Key(30)
    comptime TWO = Key(31)
    comptime THREE = Key(32)
    comptime FOUR = Key(33)
    comptime FIVE = Key(34)
    comptime SIX = Key(35)
    comptime SEVEN = Key(36)
    comptime EIGHT = Key(37)
    comptime NINE = Key(38)
    comptime ZERO = Key(39)

    # Punctuation, named for what a US layout types unshifted there, so
    # `MINUS` is also `_` with shift held.
    comptime MINUS = Key(45)
    comptime EQUALS = Key(46)
    comptime LEFT_BRACKET = Key(47)
    comptime RIGHT_BRACKET = Key(48)
    comptime BACKSLASH = Key(49)
    comptime SEMICOLON = Key(51)
    comptime APOSTROPHE = Key(52)
    comptime GRAVE = Key(53)
    comptime COMMA = Key(54)
    comptime PERIOD = Key(55)
    comptime SLASH = Key(56)

    def __init__(out self, value: Int):
        self.value = value

    def __eq__(self, other: Key) -> Bool:
        return self.value == other.value

    def __ne__(self, other: Key) -> Bool:
        return self.value != other.value

    def write_to[W: Writer](self, mut writer: W):
        comptime for i in range(len(_NAMED_KEYS)):
            comptime entry = _NAMED_KEYS[i]
            if self == entry[0]:
                writer.write("Key.", entry[1])
                return
        writer.write("Key(", self.value, ")")

    @staticmethod
    def from_name(name: String) -> Optional[Key]:
        """The key whose constant is `name`, case folded: `"up"`,
        `"page_up"`, `"f1"`, `"left_ctrl"`, `"a"`, `"zero"`, `"slash"`.
        A single character is the key that types it unshifted on a US
        layout, so `"/"`, `"7"` and `"A"` work too. `None` for an unknown
        name.
        """
        var upper = name.upper()
        comptime for i in range(len(_NAMED_KEYS)):
            comptime entry = _NAMED_KEYS[i]
            if upper == entry[1]:
                return entry[0]
        if name.byte_length() == 1:
            var character = ord(name.lower())
            if ord("1") <= character <= ord("9"):
                return Key(Key.ONE.value + character - ord("1"))
            comptime for i in range(len(_CHARACTER_KEYS)):
                comptime entry = _CHARACTER_KEYS[i]
                if character == entry[0]:
                    return entry[1]
        return None


# Every `Key` constant with its name, for printing and `from_name`.
comptime _NAMED_KEYS = [
    (Key.NONE, StaticString("NONE")),
    (Key.LEFT_CTRL, StaticString("LEFT_CTRL")),
    (Key.RIGHT_CTRL, StaticString("RIGHT_CTRL")),
    (Key.LEFT_SHIFT, StaticString("LEFT_SHIFT")),
    (Key.RIGHT_SHIFT, StaticString("RIGHT_SHIFT")),
    (Key.LEFT_ALT, StaticString("LEFT_ALT")),
    (Key.RIGHT_ALT, StaticString("RIGHT_ALT")),
    (Key.LEFT_SUPER, StaticString("LEFT_SUPER")),
    (Key.RIGHT_SUPER, StaticString("RIGHT_SUPER")),
    (Key.CTRL, StaticString("CTRL")),
    (Key.SHIFT, StaticString("SHIFT")),
    (Key.ALT, StaticString("ALT")),
    (Key.SUPER, StaticString("SUPER")),
    (Key.UP, StaticString("UP")),
    (Key.DOWN, StaticString("DOWN")),
    (Key.LEFT, StaticString("LEFT")),
    (Key.RIGHT, StaticString("RIGHT")),
    (Key.INSERT, StaticString("INSERT")),
    (Key.HOME, StaticString("HOME")),
    (Key.PAGE_UP, StaticString("PAGE_UP")),
    (Key.PAGE_DOWN, StaticString("PAGE_DOWN")),
    (Key.END, StaticString("END")),
    (Key.ENTER, StaticString("ENTER")),
    (Key.ESCAPE, StaticString("ESCAPE")),
    (Key.BACKSPACE, StaticString("BACKSPACE")),
    (Key.TAB, StaticString("TAB")),
    (Key.SPACE, StaticString("SPACE")),
    (Key.DELETE, StaticString("DELETE")),
    (Key.CAPS_LOCK, StaticString("CAPS_LOCK")),
    (Key.F1, StaticString("F1")),
    (Key.F2, StaticString("F2")),
    (Key.F3, StaticString("F3")),
    (Key.F4, StaticString("F4")),
    (Key.F5, StaticString("F5")),
    (Key.F6, StaticString("F6")),
    (Key.F7, StaticString("F7")),
    (Key.F8, StaticString("F8")),
    (Key.F9, StaticString("F9")),
    (Key.F10, StaticString("F10")),
    (Key.F11, StaticString("F11")),
    (Key.F12, StaticString("F12")),
    (Key.A, StaticString("A")),
    (Key.B, StaticString("B")),
    (Key.C, StaticString("C")),
    (Key.D, StaticString("D")),
    (Key.E, StaticString("E")),
    (Key.F, StaticString("F")),
    (Key.G, StaticString("G")),
    (Key.H, StaticString("H")),
    (Key.I, StaticString("I")),
    (Key.J, StaticString("J")),
    (Key.K, StaticString("K")),
    (Key.L, StaticString("L")),
    (Key.M, StaticString("M")),
    (Key.N, StaticString("N")),
    (Key.O, StaticString("O")),
    (Key.P, StaticString("P")),
    (Key.Q, StaticString("Q")),
    (Key.R, StaticString("R")),
    (Key.S, StaticString("S")),
    (Key.T, StaticString("T")),
    (Key.U, StaticString("U")),
    (Key.V, StaticString("V")),
    (Key.W, StaticString("W")),
    (Key.X, StaticString("X")),
    (Key.Y, StaticString("Y")),
    (Key.Z, StaticString("Z")),
    (Key.ZERO, StaticString("ZERO")),
    (Key.ONE, StaticString("ONE")),
    (Key.TWO, StaticString("TWO")),
    (Key.THREE, StaticString("THREE")),
    (Key.FOUR, StaticString("FOUR")),
    (Key.FIVE, StaticString("FIVE")),
    (Key.SIX, StaticString("SIX")),
    (Key.SEVEN, StaticString("SEVEN")),
    (Key.EIGHT, StaticString("EIGHT")),
    (Key.NINE, StaticString("NINE")),
    (Key.MINUS, StaticString("MINUS")),
    (Key.EQUALS, StaticString("EQUALS")),
    (Key.LEFT_BRACKET, StaticString("LEFT_BRACKET")),
    (Key.RIGHT_BRACKET, StaticString("RIGHT_BRACKET")),
    (Key.BACKSLASH, StaticString("BACKSLASH")),
    (Key.SEMICOLON, StaticString("SEMICOLON")),
    (Key.APOSTROPHE, StaticString("APOSTROPHE")),
    (Key.GRAVE, StaticString("GRAVE")),
    (Key.COMMA, StaticString("COMMA")),
    (Key.PERIOD, StaticString("PERIOD")),
    (Key.SLASH, StaticString("SLASH")),
]


# The keys `from_name` reads from a single character: what a US layout
# types on each unshifted. Letters match their constants' names, and `1`-`9`
# are a run, so neither needs listing.
comptime _CHARACTER_KEYS = [
    (ord(" "), Key.SPACE),
    (ord("-"), Key.MINUS),
    (ord("="), Key.EQUALS),
    (ord("["), Key.LEFT_BRACKET),
    (ord("]"), Key.RIGHT_BRACKET),
    (ord("\\"), Key.BACKSLASH),
    (ord(";"), Key.SEMICOLON),
    (ord("'"), Key.APOSTROPHE),
    (ord("`"), Key.GRAVE),
    (ord(","), Key.COMMA),
    (ord("."), Key.PERIOD),
    (ord("/"), Key.SLASH),
    (ord("0"), Key.ZERO),
]


struct _KeySet(Copyable, Movable):
    """A set of keys, held as a short list.

    SDL3 scancodes run to 511, AltGr's `MODE` among them, while only a
    handful of keys are ever down at once — so a linear scan over a short
    list is cheaper than clearing a 512-bit mask every frame, and accepts
    every scancode SDL can send.
    """

    var _keys: List[Key]

    def __init__(out self):
        self._keys = []

    def set(mut self, key: Key):
        if not self._has(key):
            self._keys.append(key)

    def clear(mut self, key: Key):
        for i in range(len(self._keys)):
            if self._keys[i] == key:
                _ = self._keys.pop(i)
                return

    def test(self, key: Key) -> Bool:
        """Whether `key` is in the set; an either-side modifier is if
        either of its sides is."""
        if key == Key.CTRL:
            return self._has(Key.LEFT_CTRL) or self._has(Key.RIGHT_CTRL)
        if key == Key.SHIFT:
            return self._has(Key.LEFT_SHIFT) or self._has(Key.RIGHT_SHIFT)
        if key == Key.ALT:
            return self._has(Key.LEFT_ALT) or self._has(Key.RIGHT_ALT)
        if key == Key.SUPER:
            return self._has(Key.LEFT_SUPER) or self._has(Key.RIGHT_SUPER)
        return self._has(key)

    def _has(self, key: Key) -> Bool:
        for held in self._keys:
            if held == key:
                return True
        return False

    def clear_all(mut self):
        self._keys.clear()
