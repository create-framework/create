"""`UI`: the widgets' state, kept from frame to frame."""

from std.reflection import SourceLocation

from create.core import Context
from create.render import Canvas
from ._id import _mix, _site
from ._recorder import _Recorder
from .layer import UILayer
from .theme import Theme


struct UI(Movable):
    """The state of a program's widgets, kept from frame to frame under each
    widget's ID.

    Keep one as a field, and open a layer on it every frame to draw widgets
    with:

    ```mojo
    # In `update`, with a `ui: UI` field:
    with self.ui.screen(context, canvas) as ui:
        ui.draw(Circle((0, 0), 20), Style(fill=Color.ORANGE))
    ```
    """

    var _frame: Int
    """The frame the per-frame state below belongs to."""
    var _site_counts: Dict[UInt64, Int]
    """How many times each call site has run this frame."""
    var _keys: List[UInt64]
    """The keys of the `ui.id` blocks open, innermost last."""
    var _recorder: _Recorder
    var _theme: Theme

    def __init__(out self, theme: Theme = Theme.light()):
        """A UI drawn in `theme`, the light theme unless given."""
        self._theme = theme
        self._frame = -1
        self._site_counts = {}
        self._keys = []
        self._recorder = _Recorder()

    def theme(self) -> Theme:
        """The theme the widgets are drawn in."""
        return self._theme

    def theme(mut self, theme: Theme):
        """Draw the widgets in `theme` from now on."""
        self._theme = theme

    def screen(
        mut self, mut context: Context, mut canvas: Canvas
    ) -> UILayer[origin_of(self), origin_of(context), origin_of(canvas)]:
        """Open a layer drawn in screen space, on top of everything drawn
        before its block ends, whatever the camera and transform.

        ```mojo
        # In `update`, with a `ui: UI` field:
        with self.ui.screen(context, canvas) as ui:
            ...
        ```
        """
        self._begin_layer(context.frame_count())
        return UILayer(
            _ui=self,
            _context=context,
            _canvas=canvas,
            _frame=context.frame_count(),
        )

    def _begin_layer(mut self, frame: Int):
        """Start a layer, resetting the per-frame state when it is the first
        layer of a new frame."""
        if frame != self._frame:
            self._frame = frame
            self._site_counts.clear()
            self._keys.clear()
        self._recorder.commands.clear()

    def _widget_id(
        mut self, location: SourceLocation, key: Optional[UInt64] = None
    ) -> UInt64:
        """The ID of a widget called from `location`: its call site inside
        the open `ui.id` blocks, and how many times that site has run this
        frame. `key`, from a widget's `id=`, is added to it as a `ui.id`
        block around the one call would be."""
        var parent = self._keys[len(self._keys) - 1] if self._keys else 0
        if key:
            parent = _mix(parent, key.value())
        var site = _site(parent, location)
        var count = self._site_counts.get(site, 0)
        self._site_counts[site] = count + 1
        return _mix(site, UInt64(count))
