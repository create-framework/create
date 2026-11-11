from create.math.vector2d import Vector2D
from .gamepad_button import GamepadButton

# SDL's axis numbering, as `GamepadAxisMoved` carries it.
comptime _LEFT_X = 0
comptime _LEFT_Y = 1
comptime _RIGHT_X = 2
comptime _RIGHT_Y = 3
comptime _LEFT_TRIGGER = 4
comptime _RIGHT_TRIGGER = 5


struct Gamepad(Copyable, ImplicitlyCopyable, Movable, Writable):
    """One gamepad's state for one frame, read as `context.gamepad(player)`.

    Buttons follow the vocabulary every device shares: *down* is held right now,
    *pressed*/*released* are the edges, true only in the frame the button
    went down or came up. Name buttons through `GamepadButton`.

    Sticks are `Vector2D`s in screen orientation — y up, like every other
    direction in the library — inside the unit circle, so
    `position += pad.left_stick * speed * context.time.delta` moves at
    `speed` at full tilt and never faster on a diagonal. Each has a radial
    dead zone of `STICK_DEAD_ZONE`, rescaled so the stick still eases up
    from zero past it: a resting stick reads exactly `Vector2D.ZERO` rather
    than drifting. Triggers are 0 (released) to 1 (pulled all the way).

    A slot that holds no gamepad reads all zero and `connected` False, so a
    program can read player two's pad before one is plugged in.
    `connected_this_frame` and `disconnected_this_frame` are the edges of
    `connected`, true only in the frame the pad arrived or left — the frame
    to show "Player 2 joined" or to pause. In the frame a pad leaves, its
    slot still has its `name`, so the message can say which.
    """

    comptime STICK_DEAD_ZONE = 0.2
    """How far a stick moves before it reads anything, as a fraction of full
    tilt. A resting stick sits up to about a quarter of the way off centre on
    a worn pad; 0.2 hides that on most without making small moves sluggish.
    """

    var connected: Bool
    var connected_this_frame: Bool
    var disconnected_this_frame: Bool
    # The product name, e.g. "Xbox Series X Controller" — for showing, not
    # for telling layouts apart. Empty when SDL knows none.
    var name: String
    var left_stick: Vector2D
    var right_stick: Vector2D
    var left_trigger: Float64
    var right_trigger: Float64
    # The most recent button pressed, compared against `GamepadButton`
    # (`GamepadButton.NONE` before any). Kept until the next press.
    var button: GamepadButton
    # SDL's id for the pad in this slot, matched against each event's.
    var _id: Int
    # Stick positions as reported, before the dead zone, y up. The dead zone
    # needs both axes of a stick and each event brings one.
    var _left_raw: Vector2D
    var _right_raw: Vector2D
    # 26 buttons, one bit each.
    var _held_buttons: Int
    var _pressed_buttons: Int
    var _released_buttons: Int

    def __init__(out self):
        self.connected = False
        self.connected_this_frame = False
        self.disconnected_this_frame = False
        self.name = ""
        self.left_stick = Vector2D.ZERO
        self.right_stick = Vector2D.ZERO
        self.left_trigger = 0.0
        self.right_trigger = 0.0
        self.button = GamepadButton.NONE
        self._id = -1
        self._left_raw = Vector2D.ZERO
        self._right_raw = Vector2D.ZERO
        self._held_buttons = 0
        self._pressed_buttons = 0
        self._released_buttons = 0

    def write_to[W: Writer](self, mut writer: W):
        writer.write(
            "Gamepad(connected=",
            self.connected,
            ", connected_this_frame=",
            self.connected_this_frame,
            ", disconnected_this_frame=",
            self.disconnected_this_frame,
            ", name=",
            repr(self.name),
            ", left_stick=",
            self.left_stick,
            ", right_stick=",
            self.right_stick,
            ", left_trigger=",
            self.left_trigger,
            ", right_trigger=",
            self.right_trigger,
            ", button=",
            self.button,
            ")",
        )

    def down(self, button: GamepadButton) -> Bool:
        """Whether `button` is held right now."""
        return (self._held_buttons & button._bit()) != 0

    def pressed(self, button: GamepadButton) -> Bool:
        """Whether `button` went down this frame: true once per press."""
        return (self._pressed_buttons & button._bit()) != 0

    def released(self, button: GamepadButton) -> Bool:
        """Whether `button` came up this frame: true once per release."""
        return (self._released_buttons & button._bit()) != 0

    def _new_frame(mut self):
        self._pressed_buttons = 0
        self._released_buttons = 0
        self.connected_this_frame = False
        self.disconnected_this_frame = False
        # Kept through the frame the pad left in, for saying which one.
        if not self.connected:
            self.name = ""

    def _press(mut self, button: GamepadButton):
        if not self.down(button):
            self.button = button
            self._held_buttons |= button._bit()
            self._pressed_buttons |= button._bit()

    def _release_all(mut self):
        """Let go of every held button, each with its released edge."""
        self._released_buttons |= self._held_buttons
        self._held_buttons = 0

    def _release(mut self, button: GamepadButton):
        self._held_buttons &= ~button._bit()
        self._released_buttons |= button._bit()

    def _set_axis(mut self, axis: Int, value: Float64):
        """Record one axis reading, `value` as `GamepadAxisMoved` carries it:
        y positive down, which is flipped here."""
        if axis == _LEFT_X:
            self._left_raw.x = value
        elif axis == _LEFT_Y:
            self._left_raw.y = -value
        elif axis == _RIGHT_X:
            self._right_raw.x = value
        elif axis == _RIGHT_Y:
            self._right_raw.y = -value
        elif axis == _LEFT_TRIGGER:
            self.left_trigger = value
        elif axis == _RIGHT_TRIGGER:
            self.right_trigger = value
        self.left_stick = _dead_zone(self._left_raw)
        self.right_stick = _dead_zone(self._right_raw)


def _dead_zone(raw: Vector2D) -> Vector2D:
    """`raw` with the inner `STICK_DEAD_ZONE` cut out and the rest stretched
    back over 0..1, capped at the unit circle — a square-gated stick reaches
    past it on the diagonals."""
    var length = raw.magnitude()
    if length <= Gamepad.STICK_DEAD_ZONE:
        return Vector2D.ZERO
    var scaled = min(
        (length - Gamepad.STICK_DEAD_ZONE) / (1.0 - Gamepad.STICK_DEAD_ZONE),
        1.0,
    )
    return raw * (scaled / length)


struct _Gamepads(Copyable, Movable):
    """Every player's pad, by slot: what `context.gamepad(player)` reads.

    Each pad takes the lowest free slot as it connects and keeps it until it
    disconnects, so unplugging player one leaves player two where they were.
    A disconnected pad leaves a `Gamepad()` behind for the next one.
    """

    var _slots: List[Gamepad]

    def __init__(out self):
        self._slots = []

    def get(self, player: Int) -> Gamepad:
        """The pad in slot `player`, or a disconnected `Gamepad()`."""
        if 0 <= player < len(self._slots):
            return self._slots[player]
        return Gamepad()

    def _new_frame(mut self):
        for i in range(len(self._slots)):
            self._slots[i]._new_frame()

    def _slot(self, id: Int) -> Int:
        """The slot of the connected pad SDL calls `id`, or -1."""
        for i in range(len(self._slots)):
            if self._slots[i].connected and self._slots[i]._id == id:
                return i
        return -1

    def _connect(mut self, id: Int, name: String):
        if self._slot(id) != -1:
            return
        var pad = Gamepad()
        pad.connected = True
        pad.connected_this_frame = True
        pad.name = name
        pad._id = id
        for i in range(len(self._slots)):
            if not self._slots[i].connected:
                # A pad that left this same frame still gets its edge.
                pad.disconnected_this_frame = self._slots[
                    i
                ].disconnected_this_frame
                self._slots[i] = pad^
                return
        self._slots.append(pad^)

    def _disconnect(mut self, id: Int):
        var slot = self._slot(id)
        if slot != -1:
            var pad = Gamepad()
            pad.disconnected_this_frame = True
            pad.name = self._slots[slot].name
            # What it held comes up with it, so a "fire on release" sees the
            # release rather than a button that silently stopped being down.
            pad._released_buttons = self._slots[slot]._held_buttons
            self._slots[slot] = pad^

    def _release_all(mut self):
        for i in range(len(self._slots)):
            self._slots[i]._release_all()

    def _axis_moved(mut self, id: Int, axis: Int, value: Float64):
        var slot = self._slot(id)
        if slot != -1:
            self._slots[slot]._set_axis(axis, value)

    def _button_down(mut self, id: Int, button: GamepadButton):
        var slot = self._slot(id)
        if slot != -1:
            self._slots[slot]._press(button)

    def _button_up(mut self, id: Int, button: GamepadButton):
        var slot = self._slot(id)
        if slot != -1:
            self._slots[slot]._release(button)
