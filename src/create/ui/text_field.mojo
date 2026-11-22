"""`TextEditor`: a text field's caret, selection and editing."""

from create.core import Context
from .ui import UI


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
