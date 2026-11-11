from .key import Key, _KeySet


struct Keyboard(Copyable, Movable, Writable):
    """The keyboard's state for one frame, read as `context.keyboard`.

    Every device answers the same three questions about its buttons:
    *down* is held right now, true every frame it stays held; *pressed* and
    *released* are the edges, true only in the frame the key went down or
    came up. Unlike Processing, where `keyPressed` means held, *pressed* is
    only ever the edge. Keys add *typed*: pressed, or auto-repeated while
    held — what an editing key like Backspace acts on.

    `text` is what those keys wrote, as characters rather than keys: shift,
    the keyboard layout and any IME already applied. A text field appends
    `text` and handles Backspace and the arrows through `typed`; an
    `EditableText` does both.

    It is the loop's own `Keyboard`, not a copy: held keys persist in it
    from frame to frame, and only the edges and `text` clear. So read it
    and don't write it.
    """

    var key: Key
    """The most recent key pressed (`Key.NONE` before any). Kept until the
    next press; auto-repeat of a held key does not count as one."""
    var text: String
    """The text typed this frame, UTF-8: empty on most frames, several
    characters when typing outpaces the frame rate."""
    var _held: _KeySet
    var _pressed: _KeySet
    var _released: _KeySet
    var _typed: _KeySet

    def __init__(out self):
        self.key = Key.NONE
        self.text = ""
        self._held = _KeySet()
        self._pressed = _KeySet()
        self._released = _KeySet()
        self._typed = _KeySet()

    def down(self, key: Key) -> Bool:
        """Whether `key` is held right now: true every frame it stays down."""
        return self._held.test(key)

    def pressed(self, key: Key) -> Bool:
        """Whether `key` went down this frame: true once per press."""
        return self._pressed.test(key)

    def released(self, key: Key) -> Bool:
        """Whether `key` came up this frame: true once per release."""
        return self._released.test(key)

    def typed(self, key: Key) -> Bool:
        """Whether `key` went down or auto-repeated this frame: true once
        per press, then at the system's repeat rate while held."""
        return self._typed.test(key)

    def write_to[W: Writer](self, mut writer: W):
        writer.write("Keyboard(key=", self.key, ", text=", repr(self.text), ")")

    def _new_frame(mut self):
        """Clear the edges and the typed text, keeping what is held. Called
        once a frame, before that frame's events."""
        self._pressed.clear_all()
        self._released.clear_all()
        self._typed.clear_all()
        self.text = ""

    def _key_down(mut self, key: Key):
        # A KeyDown for a key already held is SDL's auto-repeat: typed, but
        # not a new press.
        self._typed.set(key)
        if not self.down(key):
            self.key = key
            self._held.set(key)
            self._pressed.set(key)

    def _key_up(mut self, key: Key):
        self._held.clear(key)
        self._released.set(key)

    def _release_all(mut self):
        """Let go of every held key, each with its released edge: the window
        lost focus, and keys let go while it is away send it nothing."""
        for key in self._held._keys:
            self._released.set(key)
        self._held.clear_all()

    def _type_text(mut self, text: String):
        self.text += text
