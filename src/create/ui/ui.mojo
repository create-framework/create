"""`UI`: the widgets' state, kept from frame to frame."""

from std.reflection import SourceLocation

from create.core import Context
from create.geometry import Rectangle
from create.input import Mouse
from create.math import Point, Transform
from create.render import Canvas
from ._id import _mix, _site
from ._recorder import _Recorder
from .layer import UILayer
from .theme import Theme


@fieldwise_init
struct _Hit(Copyable, ImplicitlyCopyable, Movable):
    """Where a widget can be pointed at: its rectangle in its layer's space,
    and the transform that takes a screen point into that space."""

    var id: UInt64
    var rect: Rectangle
    var to_local: Transform

    def contains(self, screen: Point) -> Bool:
        return self.rect.contains(self.to_local.apply(screen))


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
    var _hits: List[_Hit]
    """The widgets that can be pointed at, this frame, in drawing order."""
    var _last_hits: List[_Hit]
    """The same, last frame: what is under the pointer is decided from
    these, since this frame's widgets haven't all been called yet."""
    var _hot: Optional[UInt64]
    """The topmost widget under the pointer this frame."""
    var _held: Optional[UInt64]
    """The widget the left button went down on, until it comes up."""
    var _disabled_depth: Int
    """How many `ui.disabled` blocks that disable are open."""

    def __init__(out self, theme: Theme = Theme.light()):
        """A UI drawn in `theme`, the light theme unless given."""
        self._theme = theme
        self._frame = -1
        self._site_counts = {}
        self._keys = []
        self._recorder = _Recorder()
        self._hits = []
        self._last_hits = []
        self._hot = None
        self._held = None
        self._disabled_depth = 0

    def theme(self) -> Theme:
        """The theme the widgets are drawn in."""
        return self._theme

    def theme(mut self, theme: Theme):
        """Draw the widgets in `theme` from now on."""
        self._theme = theme

    def wants_mouse(self) -> Bool:
        """Whether the mouse is the UI's this frame: the pointer is over a
        widget, or a widget is held. A game checks it before using the mouse
        itself, so a click on a button doesn't also fire a weapon.

        ```mojo
        # In `update`, before or after the UI's `with` block:
        if context.mouse.pressed() and not self.ui.wants_mouse():
            self.fire()
        ```
        """
        return Bool(self._hot) or Bool(self._held)

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
        self._begin_layer(context.frame_count(), context.mouse)
        return UILayer(
            _ui=self,
            _context=context,
            _canvas=canvas,
            _frame=context.frame_count(),
        )

    def _begin_layer(mut self, frame: Int, mouse: Mouse):
        """Start a layer, resetting the per-frame state when it is the first
        layer of a new frame."""
        if frame != self._frame:
            self._frame = frame
            self._site_counts.clear()
            self._keys.clear()
            self._disabled_depth = 0
            swap(self._last_hits, self._hits)
            self._hits.clear()
            self._hot = None
            for i in reversed(range(len(self._last_hits))):
                if self._last_hits[i].contains(mouse.position):
                    self._hot = self._last_hits[i].id
                    break
            if not mouse.down() and not mouse.released():
                self._held = None
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
