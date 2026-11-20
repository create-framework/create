"""`TextFieldStyle` and `TextFieldResult`: how a text field looks, and what
it reports back."""

from create.color import Color
from create.core import Context
from create.math._optional_float64 import _OptionalFloat64
from .theme import TypeStyle
from .ui import UI


struct TextFieldStyle(Copyable, ImplicitlyCopyable, Movable, Writable):
    """How one text field looks, where it differs from the theme. Every field
    left unset is worked out from the theme when the text field is drawn.

    A field drawn by the program itself keeps only what it wants: with
    `container_color=Color.TRANSPARENT` and `outline_thickness=0` it draws
    nothing but the text, caret and selection.
    """

    var container_color: Optional[Color]
    """The fill behind the text: `surface_container_highest`."""
    var outline_color: Optional[Color]
    """The border while unfocused: `outline`."""
    var focused_outline_color: Optional[Color]
    """The border while focused: `primary`, and twice as thick."""
    var outline_thickness: Optional[Float64]
    """1 unless given; 0 for no border."""
    var text_color: Optional[Color]
    """The typed text: `on_surface`."""
    var placeholder_color: Optional[Color]
    """The placeholder, shown while the field is empty: `on_surface_variant`."""
    var caret_color: Optional[Color]
    """The caret: `primary`."""
    var selection_color: Optional[Color]
    """The highlight behind selected text: `primary`, faded."""
    var corner_radius: Optional[Float64]
    """The theme's small corner radius unless given."""
    var padding: Optional[Float64]
    """The gap between the field's edges and its text: 12 unless given."""
    var text_style: Optional[TypeStyle]
    """The theme's `body` text unless given."""

    def __init__(
        out self,
        *,
        container_color: Optional[Color] = None,
        outline_color: Optional[Color] = None,
        focused_outline_color: Optional[Color] = None,
        outline_thickness: _OptionalFloat64 = None,
        text_color: Optional[Color] = None,
        placeholder_color: Optional[Color] = None,
        caret_color: Optional[Color] = None,
        selection_color: Optional[Color] = None,
        corner_radius: _OptionalFloat64 = None,
        padding: _OptionalFloat64 = None,
        text_style: Optional[TypeStyle] = None,
    ):
        self.container_color = container_color
        self.outline_color = outline_color
        self.focused_outline_color = focused_outline_color
        self.outline_thickness = outline_thickness._value
        self.text_color = text_color
        self.placeholder_color = placeholder_color
        self.caret_color = caret_color
        self.selection_color = selection_color
        self.corner_radius = corner_radius._value
        self.padding = padding._value
        self.text_style = text_style

    def _over(self, under: Self) -> Self:
        """This style, with every field it leaves unset taken from `under`:
        how a call's style sits over a `ui.style` block's, and an inner block
        over an outer one."""
        var merged = self.copy()
        if not merged.container_color:
            merged.container_color = under.container_color
        if not merged.outline_color:
            merged.outline_color = under.outline_color
        if not merged.focused_outline_color:
            merged.focused_outline_color = under.focused_outline_color
        if not merged.outline_thickness:
            merged.outline_thickness = under.outline_thickness
        if not merged.text_color:
            merged.text_color = under.text_color
        if not merged.placeholder_color:
            merged.placeholder_color = under.placeholder_color
        if not merged.caret_color:
            merged.caret_color = under.caret_color
        if not merged.selection_color:
            merged.selection_color = under.selection_color
        if not merged.corner_radius:
            merged.corner_radius = under.corner_radius
        if not merged.padding:
            merged.padding = under.padding
        if not merged.text_style:
            merged.text_style = under.text_style
        return merged^


struct TextFieldResult[
    ui_origin: Origin[mut=True],
    context_origin: Origin[mut=True],
    text_origin: Origin[mut=True],
](Boolable, ImplicitlyCopyable):
    """What a text field reports back: whether it changed the text, whether
    Enter was pressed in it, and where its caret and selection are. As a
    `Bool`, it is whether the text changed, so `if ui.text_field(...):`
    works like every other widget.

    For the rest of its layer's block it also edits the field, through the
    same methods typing uses, so a program can drive it from its own keys or
    buttons:

    ```mojo
    # In `update`, inside `with self.ui.screen(context, canvas) as ui:`, with
    # a `name: String` field:
    var field = ui.text_field(self.name, Rectangle((0, 0), 320, 40))
    if field.submitted:
        self.start_game(self.name)
    if ui.button("Clear", Rectangle((200, 0), 80, 40)):
        field.select_all()
        field.delete_backward()
    ```
    """

    var _ui: Pointer[UI, Self.ui_origin]
    var _context: Pointer[Context, Self.context_origin]
    var _text: Pointer[String, Self.text_origin]
    var _id: UInt64
    var changed: Bool
    """Whether the text changed this frame."""
    var submitted: Bool
    """Whether Enter was pressed in the field this frame."""

    def __init__(
        out self,
        *,
        ref[Self.ui_origin] _ui: UI,
        ref[Self.context_origin] _context: Context,
        ref[Self.text_origin] _text: String,
        _id: UInt64,
        _changed: Bool,
        _submitted: Bool,
    ):
        self._ui = Pointer(to=_ui)
        self._context = Pointer(to=_context)
        self._text = Pointer(to=_text)
        self._id = _id
        self.changed = _changed
        self.submitted = _submitted

    def __bool__(self) -> Bool:
        return self.changed

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
        self._text[] = buffer.text

    def delete_backward(self) raises:
        """Delete the selection, or the character left of the caret."""
        ref buffer = self._ui[]._buffers[self._id]
        buffer.delete_backward()
        self._text[] = buffer.text

    def delete_forward(self) raises:
        """Delete the selection, or the character right of the caret."""
        ref buffer = self._ui[]._buffers[self._id]
        buffer.delete_forward()
        self._text[] = buffer.text

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
        self._text[] = buffer.text

    def paste(self) raises:
        """Insert the clipboard's text, as if typed."""
        ref buffer = self._ui[]._buffers[self._id]
        buffer.paste(self._context[])
        self._text[] = buffer.text
