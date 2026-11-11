from std.sys.info import CompilationTarget

from create.input.key import Key
from create.input.keyboard import _Stroke

from .context import Context


struct EditableText(Copyable, Movable, Writable):
    """A line of text being typed into, with a caret and a selection: the
    state of a text field, without its look.

    The program owns one per field and feeds it the frame each `update`,
    then draws `text` itself — measuring with `canvas.text_width` puts the
    caret after the right character and the selection behind the right
    ones:

    ```mojo
    self.name.update(context)                       # in update
    canvas.text_alignment(Align.LEFT)
    var selected_x = left + canvas.text_width(self.name.before_selection())
    canvas.rectangle(...)  # from selected_x, text_width(selected_text()) wide
    canvas.text(self.name.text, (left, 0))
    var caret_x = left + canvas.text_width(self.name.before_caret())
    canvas.line((caret_x, -20), (caret_x, 20))
    ```

    `update` replays the frame's typing in the order it came, so text and
    editing keys typed within one frame land where they were typed:

    | Keys | Does |
    |---|---|
    | Typed text | Replaces the selection, or goes in at the caret |
    | Backspace, Delete | Delete the selection, or one character either side |
    | Left, Right | Move one character, or to a selection's edge |
    | Home, End | Move to the start or the end |
    | *word* + Left/Right/Backspace/Delete | The same, a word at a time |
    | Shift + any move | Extends the selection instead |
    | *command* + A, C, X, V | Select all, copy, cut, paste |

    *Command* is Cmd on macOS and Ctrl elsewhere; *word* is Option on macOS
    and Ctrl elsewhere, and on macOS Cmd+Left/Right go to the start and the
    end, as the system's own fields do. The command shortcuts follow the
    letter printed on the key, so they are where the user expects on any
    layout. Moves and deletes repeat while held; Enter is left to the
    program, which decides what submitting means. Clicking into the text is
    the program's: it knows where the text is drawn.

    `max_length`, if set, is the most characters typing and pasting can
    bring the text to. Every edit and move is by whole characters, so a
    multi-byte UTF-8 character is never split. `text` is a plain field:
    reading it is the point, and assigning it (`self.name.text = ""`) is
    safe, since the caret and the selection are kept inside it and on
    character boundaries.
    """

    var text: String
    """What has been typed so far, UTF-8."""
    var max_length: Optional[Int]
    """The most characters typing and pasting can bring `text` to; `None`
    for no limit. Text assigned directly is kept as it is."""
    var _caret: Int
    """Byte offset of the caret into `text`. Read through `_clamp`, because
    `text` can be reassigned under it."""
    var _anchor: Int
    """Byte offset of the selection's other end: the selection runs between
    it and the caret, and is empty when they meet."""

    def __init__(
        out self, text: String = "", *, max_length: Optional[Int] = None
    ):
        """Start with `text` already typed, the caret after it."""
        self.text = text
        self.max_length = max_length
        self._caret = text.byte_length()
        self._anchor = self._caret

    # ------------------------------------------------------------- update

    def update(mut self, mut context: Context):
        """Apply one frame's typing, in the order it was typed. Takes the
        whole `Context` for its clipboard, which copy, cut and paste use."""
        # Copied, since copy and cut write to the context it lives on.
        var strokes = context.keyboard._strokes.copy()
        for stroke in strokes:
            if stroke.text:
                self.insert(stroke.text)
            else:
                self._apply(stroke, context)

    def _apply(mut self, stroke: _Stroke, mut context: Context):
        comptime macos = CompilationTarget.is_macos()
        var command = stroke.super_key if macos else stroke.ctrl
        var word = stroke.alt if macos else stroke.ctrl
        var select = stroke.shift
        var key = stroke.key
        if command and not macos and self._shortcut(stroke, context):
            return
        if command and macos:
            if key == Key.LEFT:
                self.move_to_start(select=select)
            elif key == Key.RIGHT:
                self.move_to_end(select=select)
            else:
                _ = self._shortcut(stroke, context)
            return
        if key == Key.BACKSPACE:
            if word:
                self.delete_word_backward()
            else:
                self.delete_backward()
        elif key == Key.DELETE:
            if word:
                self.delete_word_forward()
            else:
                self.delete_forward()
        elif key == Key.LEFT:
            if word:
                self.move_word_left(select=select)
            else:
                self.move_left(select=select)
        elif key == Key.RIGHT:
            if word:
                self.move_word_right(select=select)
            else:
                self.move_right(select=select)
        elif key == Key.HOME:
            self.move_to_start(select=select)
        elif key == Key.END:
            self.move_to_end(select=select)

    def _shortcut(mut self, stroke: _Stroke, mut context: Context) -> Bool:
        """Select all, copy, cut or paste, if `stroke` is one; whether it
        was. By the key's label, falling back to its position where no label
        came with it."""
        if _is_letter(stroke, "a", Key.A):
            self.select_all()
        elif _is_letter(stroke, "c", Key.C):
            self.copy(context)
        elif _is_letter(stroke, "x", Key.X):
            self.cut(context)
        elif _is_letter(stroke, "v", Key.V):
            self.paste(context)
        else:
            return False
        return True

    # ------------------------------------------------------------ reading

    def before_caret(self) -> String:
        """The text left of the caret — what to measure to place it."""
        return String(self.text[byte = 0 : self._clamp(self._caret)])

    def after_caret(self) -> String:
        """The text right of the caret."""
        return String(self.text[byte = self._clamp(self._caret) :])

    def selected_text(self) -> String:
        """The selected text, empty when nothing is."""
        var start, end = self._selection()
        return String(self.text[byte=start:end])

    def before_selection(self) -> String:
        """The text left of the selection — what to measure to place its
        highlight. The same as `before_caret` when nothing is selected."""
        var start, _ = self._selection()
        return String(self.text[byte=0:start])

    # ------------------------------------------------------------ editing

    def insert(mut self, typed: String):
        """Put `typed` in place of the selection, or at the caret, and move
        the caret past it. Cut short at `max_length`."""
        var start, end = self._selection()
        var fitting = typed
        if self.max_length:
            var kept = (
                self.text.count_codepoints()
                - String(self.text[byte=start:end]).count_codepoints()
            )
            fitting = _first_characters(typed, self.max_length.value() - kept)
        self._replace(start, end, fitting)

    def delete_backward(mut self):
        """Delete the selection, or the character left of the caret, as
        Backspace does."""
        if not self._delete_selection():
            var end = self._clamp(self._caret)
            self._replace(self._previous_boundary(end), end, "")

    def delete_forward(mut self):
        """Delete the selection, or the character right of the caret, as
        Delete does."""
        if not self._delete_selection():
            var start = self._clamp(self._caret)
            self._replace(start, self._next_boundary(start), "")

    def delete_word_backward(mut self):
        """Delete the selection, or back to the start of the word left of
        the caret."""
        if not self._delete_selection():
            var end = self._clamp(self._caret)
            self._replace(self._previous_word(end), end, "")

    def delete_word_forward(mut self):
        """Delete the selection, or on to the end of the word right of the
        caret."""
        if not self._delete_selection():
            var start = self._clamp(self._caret)
            self._replace(start, self._next_word(start), "")

    # ------------------------------------------------------------- moving

    def move_left(mut self, *, select: Bool = False):
        """Move the caret one character left, stopping at the start. With
        a selection and not `select`, go to its start instead."""
        var start, end = self._selection()
        if start != end and not select:
            self._place(start, select=False)
        else:
            self._place(
                self._previous_boundary(self._clamp(self._caret)), select
            )

    def move_right(mut self, *, select: Bool = False):
        """Move the caret one character right, stopping at the end. With a
        selection and not `select`, go to its end instead."""
        var start, end = self._selection()
        if start != end and not select:
            self._place(end, select=False)
        else:
            self._place(self._next_boundary(self._clamp(self._caret)), select)

    def move_word_left(mut self, *, select: Bool = False):
        """Move the caret to the start of the word on its left."""
        self._place(self._previous_word(self._clamp(self._caret)), select)

    def move_word_right(mut self, *, select: Bool = False):
        """Move the caret to the end of the word on its right."""
        self._place(self._next_word(self._clamp(self._caret)), select)

    def move_to_start(mut self, *, select: Bool = False):
        self._place(0, select)

    def move_to_end(mut self, *, select: Bool = False):
        self._place(self.text.byte_length(), select)

    def select_all(mut self):
        self._anchor = 0
        self._caret = self.text.byte_length()

    # ---------------------------------------------------------- clipboard

    def copy(self, mut context: Context):
        """Put the selection on the clipboard, if there is one."""
        var selected = self.selected_text()
        if selected:
            context.clipboard(selected)

    def cut(mut self, mut context: Context):
        """Put the selection on the clipboard and delete it."""
        self.copy(context)
        _ = self._delete_selection()

    def paste(mut self, context: Context):
        """Insert the clipboard's text, as if typed. A line field takes one
        line, so a newline pastes as a space."""
        var pasted = context.clipboard().replace("\r\n", " ")
        self.insert(pasted.replace("\n", " ").replace("\r", " "))

    def write_to[W: Writer](self, mut writer: W):
        # The caret and the selection are left out: private, and byte
        # offsets besides.
        writer.write('EditableText(text="', self.text, '"')
        if self.max_length:
            writer.write(", max_length=", self.max_length.value())
        writer.write(")")

    # ----------------------------------------------------------- internal

    def _selection(self) -> Tuple[Int, Int]:
        var caret = self._clamp(self._caret)
        var anchor = self._clamp(self._anchor)
        return (min(caret, anchor), max(caret, anchor))

    def _place(mut self, offset: Int, select: Bool):
        """Move the caret to `offset`; the anchor follows unless `select`,
        which leaves it behind to stretch the selection."""
        if not select:
            self._anchor = offset
        else:
            self._anchor = self._clamp(self._anchor)
        self._caret = offset

    def _delete_selection(mut self) -> Bool:
        var start, end = self._selection()
        if start == end:
            return False
        self._replace(start, end, "")
        return True

    def _replace(mut self, start: Int, end: Int, replacement: String):
        self.text = (
            String(self.text[byte=0:start])
            + replacement
            + String(self.text[byte=end:])
        )
        self._caret = start + replacement.byte_length()
        self._anchor = self._caret

    def _clamp(self, offset: Int) -> Int:
        """`offset` clamped into `text` and moved back onto the start of a
        character, whatever `text` was reassigned to."""
        var clamped = min(max(offset, 0), self.text.byte_length())
        while clamped > 0 and self._continues(clamped):
            clamped -= 1
        return clamped

    def _continues(self, offset: Int) -> Bool:
        """Whether the byte at `offset` continues a character rather than
        starting one: UTF-8 continuation bytes are 0b10xxxxxx."""
        if offset >= self.text.byte_length():
            return False
        return (self.text.as_bytes()[offset] & 0xC0) == 0x80

    def _previous_boundary(self, offset: Int) -> Int:
        if offset == 0:
            return 0
        var previous = offset - 1
        while previous > 0 and self._continues(previous):
            previous -= 1
        return previous

    def _next_boundary(self, offset: Int) -> Int:
        var end = self.text.byte_length()
        if offset >= end:
            return end
        var following = offset + 1
        while following < end and self._continues(following):
            following += 1
        return following

    def _in_word(self, start: Int) -> Bool:
        """Whether the character starting at `start` belongs to a word: a
        letter, digit or underscore. Every non-ASCII character counts as a
        letter, so accented and non-Latin words move as one."""
        var byte = Int(self.text.as_bytes()[start])
        if byte >= 0x80:
            return True
        return (
            (ord("a") <= byte <= ord("z"))
            or (ord("A") <= byte <= ord("Z"))
            or (ord("0") <= byte <= ord("9"))
            or byte == ord("_")
        )

    def _previous_word(self, offset: Int) -> Int:
        """The start of the word left of `offset`, past any spaces and
        punctuation between."""
        var at = offset
        while at > 0 and not self._in_word(self._previous_boundary(at)):
            at = self._previous_boundary(at)
        while at > 0 and self._in_word(self._previous_boundary(at)):
            at = self._previous_boundary(at)
        return at

    def _next_word(self, offset: Int) -> Int:
        """The end of the word right of `offset`, past any spaces and
        punctuation between."""
        var end = self.text.byte_length()
        var at = offset
        while at < end and not self._in_word(at):
            at = self._next_boundary(at)
        while at < end and self._in_word(at):
            at = self._next_boundary(at)
        return at


def _is_letter(stroke: _Stroke, letter: StringLiteral, position: Key) -> Bool:
    """Whether `stroke` is the key labelled `letter`: by its label where it
    came with one, by its US-layout position where not."""
    if stroke.label != 0:
        return stroke.label == ord(letter)
    return stroke.key == position


def _first_characters(text: String, count: Int) -> String:
    """`text` cut to its first `count` characters."""
    if count <= 0:
        return ""
    var kept = String()
    var taken = 0
    for character in text.codepoint_slices():
        if taken == count:
            break
        kept += character
        taken += 1
    return kept^
