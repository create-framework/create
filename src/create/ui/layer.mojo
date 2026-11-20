"""`UILayer`: the handle a `ui.screen` block draws widgets with."""

from std.reflection import SourceLocation

from create.core import Context
from create.geometry import Drawable
from create.render import Canvas, Style
from ._id import _mix
from .theme import Theme
from .ui import UI


struct UILayer[
    ui_origin: Origin[mut=True],
    context_origin: Origin[mut=True],
    canvas_origin: Origin[mut=True],
](ImplicitlyCopyable):
    """The handle a `with self.ui.screen(context, canvas) as ui:` block gets:
    every widget is a method on it.

    It points at the `UI`, the context and the canvas, so a widget needs none
    of them passed, and the block can still use them, and the program's other
    fields, directly. A helper takes it as `ui: UILayer`, its parameters left
    to be inferred. Everything drawn through it is drawn when the block ends,
    in the order it was called.
    """

    var _ui: Pointer[UI, Self.ui_origin]
    var _context: Pointer[Context, Self.context_origin]
    var _canvas: Pointer[Canvas, Self.canvas_origin]
    var _frame: Int

    def __init__(
        out self,
        *,
        ref[Self.ui_origin] _ui: UI,
        ref[Self.context_origin] _context: Context,
        ref[Self.canvas_origin] _canvas: Canvas,
        _frame: Int,
    ):
        self._ui = Pointer(to=_ui)
        self._context = Pointer(to=_context)
        self._canvas = Pointer(to=_canvas)
        self._frame = _frame

    def __enter__(self) -> Self:
        return self

    def __exit__(self) raises:
        with self._canvas[].overlay():
            self._ui[]._recorder.replay(self._canvas[])

    def draw[D: Drawable](self, shape: D, style: Style) raises:
        """Draw `shape` in `style`, in order with the layer's widgets: above
        what was drawn through the layer before it, and below what comes
        after. A plain `canvas` call inside the block draws at once, beneath
        the whole layer.

        ```mojo
        # In `update`, inside `with self.ui.screen(context, canvas) as ui:`:
        ui.draw(Circle((0, 0), 20), Style(fill=Color.ORANGE))
        ```
        """
        self._check_frame()
        ref recorder = self._ui[]._recorder
        recorder.style = style
        recorder.draw(shape)

    def theme(self) -> Theme:
        """The theme the widgets are drawn in, for a program's own widget to
        match them."""
        return self._ui[]._theme

    def id[K: Hashable](self, key: K) raises -> IDGuard[Self.ui_origin]:
        """Add `key` to the ID of every widget inside a `with` block, so a
        widget keeps its state when the items around it are reordered or
        removed.

        ```mojo
        # In `update`, inside `with self.ui.screen(context, canvas) as ui:`:
        for player in self.players:
            with ui.id(player.name):
                ...
        ```
        """
        self._check_frame()
        return IDGuard(_ui=self._ui[], _key=UInt64(hash(key)))

    def _check_frame(self) raises:
        """Raise when the handle is used after the frame it was opened in."""
        if self._context[].frame_count() != self._frame:
            raise Error(
                "UILayer: used in frame "
                + String(self._context[].frame_count())
                + ", but opened in frame "
                + String(self._frame)
                + "; open a new layer with `ui.screen` every frame"
            )

    def _widget_id(
        self, location: SourceLocation, key: Optional[UInt64] = None
    ) raises -> UInt64:
        """The ID of a widget called from `location`; see `UI._widget_id`."""
        self._check_frame()
        return self._ui[]._widget_id(location, key)


struct IDGuard[origin: Origin[mut=True]](Movable):
    """Takes the key `ui.id` added off the widget IDs again, on scope exit.
    Only `ui.id` builds one."""

    var _ui: Pointer[UI, Self.origin]

    def __init__(out self, *, ref[Self.origin] _ui: UI, _key: UInt64):
        var parent = _ui._keys[len(_ui._keys) - 1] if _ui._keys else 0
        _ui._keys.append(_mix(parent, _key))
        self._ui = Pointer(to=_ui)

    def __enter__(mut self):
        pass

    def __exit__(mut self):
        _ = self._ui[]._keys.pop()
