"""`TextField`, a field the keyboard types into, and `TextEditor`, the old
`ui.text_field`'s caret, selection and editing."""

from create.core import Context
from create.geometry import Line, Rectangle
from create.input import Key
from create.math import Point
from create.render import Align, Canvas, Style, Text
from create.render.style import _ResolvedStyle
from create._optional import _OptionalFloat64
from ._pointer import _Pointer
from ._text_buffer import _TextBuffer
from ._theme import _TextFieldLook, _Theme, _fills, _text_look
from .ui import UI
from .widget import Clickable, Widget


comptime _PADDING = 12.0
"""The gap between a text field's sides and its text, unless given."""


struct TextField(Clickable, Copyable, Movable, Widget):
    """A field to type a line of text into.

    A click gives it focus and places the caret under the pointer; while it
    has focus, typing and the editing keys change its text, Enter submits
    it, and a click elsewhere or Escape takes its focus away. It switches
    `context.text_input` on while it has focus and off when it loses it.

    ```mojo
    # In `create`, building the `name` field:
    var name = TextField(Rectangle((0, 0), 320, 40), placeholder="Your name")

    # In `update`:
    self.name.update(context, canvas)
    canvas.draw(self.name)
    if self.name.submitted():
        self.start_game(self.name.text())
    ```

    `text()` is what has been typed, and `set_text` replaces it. The editing
    methods (`insert`, `delete_backward`, `select_all`, `copy`, `paste` and
    the rest) edit it as the keys do, so a program can drive it from
    buttons of its own; `changed()` reports their edits at the next
    `update`, as it does typing.

    Each part is drawn in a style of its own: `container` is the field, a
    rectangle, and `focused_container` is layered over it while it has
    focus (by default its outline turns `primary` and twice as thick);
    `text_style` is the typed text and `placeholder_style` the placeholder,
    which takes what it leaves unset from `text_style`; `caret` is a line,
    so its stroke is the caret's colour and width; and `selection` is the
    rectangle behind selected text.
    """

    var rect: Rectangle
    """Where it is, and how big."""
    var placeholder: String
    """Shown in a fainter colour while the field is empty."""
    var padding: Float64
    """The gap between the field's sides and its text."""
    var container: Style
    var focused_container: Style
    var text_style: Style
    var placeholder_style: Style
    var caret: Style
    var selection: Style
    var enabled: Bool
    """Whether it reacts to the mouse and keyboard. A disabled field is
    faded, and loses focus."""
    var _buffer: _TextBuffer
    var _pointer: _Pointer
    var _focused: Bool
    var _last_text: String
    var _changed: Bool
    var _submitted: Bool
    var _look: _TextFieldLook
    var _caret_x: Float64
    """Where the caret is, measured from the start of the text."""
    var _selection_start: Float64
    var _selection_width: Float64
    var _caret_shown: Bool

    def __init__(
        out self,
        rect: Rectangle,
        text: String = "",
        *,
        placeholder: String = "",
        max_length: Optional[Int] = None,
        padding: _OptionalFloat64 = None,
        container: Style = Style(),
        focused_container: Style = Style(),
        text_style: Style = Style(),
        placeholder_style: Style = Style(),
        caret: Style = Style(),
        selection: Style = Style(),
        enabled: Bool = True,
    ):
        self.rect = rect
        self.placeholder = placeholder
        self.padding = padding.or_else(_PADDING)
        self.container = container
        self.focused_container = focused_container
        self.text_style = text_style
        self.placeholder_style = placeholder_style
        self.caret = caret
        self.selection = selection
        self.enabled = enabled
        self._buffer = _TextBuffer(text, max_length=max_length)
        self._pointer = _Pointer()
        self._focused = False
        self._last_text = text
        self._changed = False
        self._submitted = False
        self._look = _Theme.default().text_field(
            container,
            focused_container,
            text_style,
            placeholder_style,
            caret,
            selection,
            hovered=False,
            focused=False,
            disabled=not enabled,
        )
        self._caret_x = 0
        self._selection_start = 0
        self._selection_width = 0
        self._caret_shown = False

    # ------------------------------------------------------------- update

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        """Read what the mouse and keyboard did to it this frame, taking
        focus on a click and typing while it has it, and work out its look:
        call it before drawing it."""
        self._update(context, canvas, _Theme.default(), free=True)

    def _update(
        mut self,
        mut context: Context,
        mut canvas: Canvas,
        theme: _Theme,
        *,
        free: Bool,
    ) raises:
        """`update` in `theme`, as a `UI` updates it; `free` is false when
        another widget is over it at the pointer."""
        ref mouse = context.mouse
        var pointer = canvas.to_local(mouse.position)
        var inside = self.rect.contains(pointer)
        self._pointer.update(mouse, inside, free=free, enabled=self.enabled)
        var was_focused = self._focused
        if not self.enabled:
            self._focused = False
        elif self._pointer.pressed:
            self._focused = True
        elif mouse.pressed() and not inside:
            self._focused = False
        elif self._focused and context.keyboard.pressed(Key.ESCAPE):
            self._focused = False
        if self._focused != was_focused:
            context.text_input(self._focused)
        elif self._focused and not context.text_input():
            context.text_input(True)  # another field let go after we took it

        self._look = theme.text_field(
            self.container,
            self.focused_container,
            self.text_style,
            self.placeholder_style,
            self.caret,
            self.selection,
            hovered=self._pointer.hovered,
            focused=self._focused,
            disabled=not self.enabled,
        )
        var look = _text_look(self._look.typed, Align.LEFT)
        var left = self.rect.position.x - self.rect.width / 2 + self.padding
        var inner = self.rect.width - 2 * self.padding
        var now = context.time.elapsed

        # a press places the caret under the pointer
        if self._pointer.pressed:
            var typed = self._buffer.text
            var x = pointer.x - left + self._buffer.scroll
            self._buffer._place(
                _offset_at(canvas, typed, x, look), select=False
            )
            self._buffer.last_change = now
        self._submitted = False
        if self._focused:
            var before = self._buffer.text
            var caret = self._buffer.before_caret()
            self._buffer.update(context)
            if (
                self._buffer.text != before
                or self._buffer.before_caret() != caret
            ):
                self._buffer.last_change = now
            self._submitted = context.keyboard.pressed(Key.ENTER)
        self._changed = self._buffer.text != self._last_text
        self._last_text = self._buffer.text

        # keep the caret inside the field while it has focus; without focus,
        # show the text from its start
        self._caret_x = _measure(canvas, self._buffer.before_caret(), look)
        ref buffer = self._buffer
        if not self._focused:
            buffer.scroll = 0
        elif self._caret_x - buffer.scroll > inner:
            buffer.scroll = self._caret_x - inner
        elif self._caret_x - buffer.scroll < 0:
            buffer.scroll = self._caret_x
        var whole = _measure(canvas, buffer.text, look)
        buffer.scroll = min(buffer.scroll, max(0.0, whole - inner))
        self._selection_start = 0
        self._selection_width = 0
        if self._focused and buffer.selected_text():
            self._selection_start = _measure(
                canvas, buffer.before_selection(), look
            )
            self._selection_width = _measure(
                canvas, buffer.selected_text(), look
            )
        # the caret: steady for a moment after a change, then blinking
        var since = now - buffer.last_change
        self._caret_shown = (
            self._focused
            and self.enabled
            and (since < 0.5 or Int(since * 2) % 2 == 1)
        )

    # ------------------------------------------------------------ queries

    def text(self) -> String:
        """What has been typed."""
        return self._buffer.text

    def set_text(mut self, text: String):
        """Replace what has been typed with `text`, the caret kept inside
        it. Not reported by `changed()`: the program made the change."""
        self._buffer.text = text
        self._last_text = text

    def max_length(self) -> Optional[Int]:
        """The most characters typing and pasting can bring it to; `None`
        for no limit."""
        return self._buffer.max_length

    def max_length(mut self, length: Optional[Int]):
        self._buffer.max_length = length

    def focused(self) -> Bool:
        """Whether it has focus, so typing reaches it."""
        return self._focused

    def focus(mut self, focused: Bool = True):
        """Give it focus, or take it away, as a click on it or elsewhere
        would. It switches `context.text_input` at its next `update`."""
        self._focused = focused and self.enabled

    def changed(self) -> Bool:
        """Whether its text changed between its last two `update`s, by
        typing or through the editing methods."""
        return self._changed

    def submitted(self) -> Bool:
        """Whether Enter was pressed in it at its last `update`."""
        return self._submitted

    def hovered(self) -> Bool:
        return self._pointer.hovered

    def pressed(self) -> Bool:
        return self._pointer.pressed

    def down(self) -> Bool:
        return self._pointer.held

    def released(self) -> Bool:
        return self._pointer.released

    def before_caret(self) -> String:
        """The text left of the caret: what to measure to place it."""
        return self._buffer.before_caret()

    def after_caret(self) -> String:
        """The text right of the caret."""
        return self._buffer.after_caret()

    def selected_text(self) -> String:
        """The selected text, empty when nothing is."""
        return self._buffer.selected_text()

    # ------------------------------------------------------------ editing

    def insert(mut self, typed: String):
        """Put `typed` in place of the selection, or at the caret."""
        self._buffer.insert(typed)

    def delete_backward(mut self):
        """Delete the selection, or the character left of the caret."""
        self._buffer.delete_backward()

    def delete_forward(mut self):
        """Delete the selection, or the character right of the caret."""
        self._buffer.delete_forward()

    def move_left(mut self, *, select: Bool = False):
        self._buffer.move_left(select=select)

    def move_right(mut self, *, select: Bool = False):
        self._buffer.move_right(select=select)

    def move_word_left(mut self, *, select: Bool = False):
        self._buffer.move_word_left(select=select)

    def move_word_right(mut self, *, select: Bool = False):
        self._buffer.move_word_right(select=select)

    def move_to_start(mut self, *, select: Bool = False):
        self._buffer.move_to_start(select=select)

    def move_to_end(mut self, *, select: Bool = False):
        self._buffer.move_to_end(select=select)

    def select_all(mut self):
        self._buffer.select_all()

    def copy(self, mut context: Context):
        """Put the selection on the clipboard, if there is one."""
        self._buffer.copy(context)

    def cut(mut self, mut context: Context):
        """Put the selection on the clipboard and delete it."""
        self._buffer.cut(context)

    def paste(mut self, context: Context):
        """Insert the clipboard's text, as if typed."""
        self._buffer.paste(context)

    # ------------------------------------------------------------ drawing

    def draw_to(self, mut canvas: Canvas):
        ref look = self._look
        ref field = look.container
        var rect = self.rect
        if _fills(field) or (
            field.stroke_enabled and field.stroke_thickness > 0
        ):
            var shape = rect.copy()
            shape.corner_radius = field.corner_radius
            with canvas._with_style(field):
                canvas.draw(shape)
        # the text, clipped half the padding in from each side: scrolled
        # text runs on into the padding, but stops short of the border
        var left = rect.position.x - rect.width / 2 + self.padding
        var origin_x = left - self._buffer.scroll
        var y = rect.position.y
        with canvas.clip(
            Rectangle(rect.position, rect.width - self.padding, rect.height)
        ):
            if self._selection_width > 0:
                with canvas._with_style(look.selection):
                    canvas.draw(
                        Rectangle(
                            Point(
                                origin_x
                                + self._selection_start
                                + self._selection_width / 2,
                                y,
                            ),
                            self._selection_width,
                            look.typed.font_size * 1.3,
                        )
                    )
            if self._buffer.text:
                with canvas._with_style(_text_look(look.typed, Align.LEFT)):
                    canvas.draw(Text(self._buffer.text, Point(origin_x, y)))
            elif self.placeholder:
                with canvas._with_style(_text_look(look.hint, Align.LEFT)):
                    canvas.draw(Text(self.placeholder, Point(left, y)))
            if self._caret_shown:
                var x = origin_x + self._caret_x
                var half = look.typed.font_size * 0.65
                with canvas._with_style(look.caret):
                    canvas.draw(Line(Point(x, y - half), Point(x, y + half)))


def _measure(
    mut canvas: Canvas, text: String, look: _ResolvedStyle
) raises -> Float64:
    """How wide `text` is drawn in `look`'s font, size and weight."""
    if not text:
        return 0
    with canvas._with_style(look):
        return canvas.text_width(text)


def _offset_at(
    mut canvas: Canvas, text: String, x: Float64, look: _ResolvedStyle
) raises -> Int:
    """The byte offset of the character boundary in `text` nearest to `x`
    units from its start."""
    var best = 0
    var best_distance = abs(x)
    var prefix = String()
    var offset = 0
    for character in text.codepoint_slices():
        prefix += character
        offset += character.byte_length()
        var distance = abs(x - _measure(canvas, prefix, look))
        if distance < best_distance:
            best = offset
            best_distance = distance
    return best


struct TextEditor[
    ui_origin: Origin[mut=True],
    context_origin: Origin[mut=True],
](ImplicitlyCopyable):
    """A text field's caret, selection and editing, from `ui.text_editor()`
    right after the field. It reads where the caret and selection are, to
    draw beside them, and edits the field through the same methods typing
    uses, so a program can drive it from its own keys or buttons.

    An edit reaches the field's `text` the next time the field is called,
    as typing does, and `ui.changed()` reports it then.

    ```mojo
    # In `update`, inside `with self.ui.screen(context, canvas) as ui:`, with
    # a `name: String` field:
    ui.text_field(self.name, Rectangle((0, 0), 320, 40))
    var editor = ui.text_editor()
    if ui.button("Clear", Rectangle((200, 0), 80, 40)):
        editor.select_all()
        editor.delete_backward()
    ```
    """

    var _ui: Pointer[UI, Self.ui_origin]
    var _context: Pointer[Context, Self.context_origin]
    var _id: UInt64

    def __init__(
        out self,
        *,
        ref[Self.ui_origin] _ui: UI,
        ref[Self.context_origin] _context: Context,
        _id: UInt64,
    ):
        self._ui = Pointer(to=_ui)
        self._context = Pointer(to=_context)
        self._id = _id

    # The buffer is looked up by ID on every call, never kept: other widgets
    # called later in the block can add buffers and move this one.

    def before_caret(self) raises -> String:
        """The text left of the caret: what to measure to place it."""
        return self._ui[]._buffers[self._id].before_caret()

    def after_caret(self) raises -> String:
        """The text right of the caret."""
        return self._ui[]._buffers[self._id].after_caret()

    def selected_text(self) raises -> String:
        """The selected text, empty when nothing is."""
        return self._ui[]._buffers[self._id].selected_text()

    def before_selection(self) raises -> String:
        """The text left of the selection: what to measure to place its
        highlight. The same as `before_caret` when nothing is selected."""
        return self._ui[]._buffers[self._id].before_selection()

    def insert(self, typed: String) raises:
        """Put `typed` in place of the selection, or at the caret."""
        ref buffer = self._ui[]._buffers[self._id]
        buffer.insert(typed)
        buffer.edited = True

    def delete_backward(self) raises:
        """Delete the selection, or the character left of the caret."""
        ref buffer = self._ui[]._buffers[self._id]
        buffer.delete_backward()
        buffer.edited = True

    def delete_forward(self) raises:
        """Delete the selection, or the character right of the caret."""
        ref buffer = self._ui[]._buffers[self._id]
        buffer.delete_forward()
        buffer.edited = True

    def move_left(self, *, select: Bool = False) raises:
        self._ui[]._buffers[self._id].move_left(select=select)

    def move_right(self, *, select: Bool = False) raises:
        self._ui[]._buffers[self._id].move_right(select=select)

    def move_word_left(self, *, select: Bool = False) raises:
        self._ui[]._buffers[self._id].move_word_left(select=select)

    def move_word_right(self, *, select: Bool = False) raises:
        self._ui[]._buffers[self._id].move_word_right(select=select)

    def move_to_start(self, *, select: Bool = False) raises:
        self._ui[]._buffers[self._id].move_to_start(select=select)

    def move_to_end(self, *, select: Bool = False) raises:
        self._ui[]._buffers[self._id].move_to_end(select=select)

    def select_all(self) raises:
        self._ui[]._buffers[self._id].select_all()

    def copy(self) raises:
        """Put the selection on the clipboard, if there is one."""
        self._ui[]._buffers[self._id].copy(self._context[])

    def cut(self) raises:
        """Put the selection on the clipboard and delete it."""
        ref buffer = self._ui[]._buffers[self._id]
        buffer.cut(self._context[])
        buffer.edited = True

    def paste(self) raises:
        """Insert the clipboard's text, as if typed."""
        ref buffer = self._ui[]._buffers[self._id]
        buffer.paste(self._context[])
        buffer.edited = True
