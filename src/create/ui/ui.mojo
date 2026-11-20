"""`UI`: the widgets' state, kept from frame to frame."""

from std.reflection import SourceLocation

from create.core import Context
from create.geometry import Rectangle
from create.input import Key, Keyboard, Mouse
from create.math import Point, Transform
from create.render import Canvas
from ._id import _mix, _site
from ._recorder import _Recorder
from ._text_buffer import _TextBuffer
from .layer import UILayer
from .theme import Theme


@fieldwise_init
struct _Hit(Copyable, ImplicitlyCopyable, Movable):
    """Where a widget can be pointed at: its rectangle in its layer's space,
    and the transform that takes a screen point into that space."""

    var id: UInt64
    var rect: Rectangle
    var to_local: Transform
    var focusable: Bool
    """Whether Tab can move focus to it: not while it is disabled."""
    var takes_typing: Bool
    """Whether it takes typed text, as a text field does."""

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
    var _focused: Optional[UInt64]
    """The widget with focus: at most one at a time."""
    var _focus_visible: Bool
    """Whether focus came from the keyboard, a gamepad or `take_focus`,
    rather than a click: only then is a focus ring drawn."""
    var _focused_takes_typing: Bool
    """Whether the focused widget takes typed text, as a text field does."""
    var _buffers: Dict[UInt64, _TextBuffer]
    """Each text field's text, caret and selection, under its ID."""
    var _typing_was: Bool
    """Whether a widget that takes typing had focus when `text_input` was
    last switched: the UI switches it only when that changes."""
    var _key_used: Bool
    """Whether a key was the UI's this frame: Tab moving focus, Escape
    taking it away, or a key acting on the focused widget."""

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
        self._focused = None
        self._focus_visible = False
        self._focused_takes_typing = False
        self._key_used = False
        self._buffers = {}
        self._typing_was = False

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

    def wants_keyboard(self) -> Bool:
        """Whether the keyboard is the UI's this frame. It is while a widget
        that takes typing has focus, and while a widget has focus from the
        keyboard, Tab say, rather than from a click, since the keys then act
        on it: Enter and Space press a button, the arrows move a slider. It
        is also in the frame a key moved or took away focus, such as Escape
        leaving a text field. A game checks it before reading keys itself,
        so typing a name with W in it doesn't move the player.

        ```mojo
        # In `update`, before or after the UI's `with` block:
        if context.keyboard.pressed(Key.ESCAPE) and not self.ui.wants_keyboard():
            context.quit()
        ```
        """
        return (
            Bool(self._focused)
            and (self._focused_takes_typing or self._focus_visible)
        ) or self._key_used

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
        self._begin_layer(context)
        return UILayer(
            _ui=self,
            _context=context,
            _canvas=canvas,
            _frame=context.frame_count(),
        )

    def world(
        mut self, mut context: Context, mut canvas: Canvas
    ) -> UILayer[origin_of(self), origin_of(context), origin_of(canvas)]:
        """Open a layer drawn in the space that is current when the block
        opens, the camera and any transform included: for a button above a
        chest, a health bar over an enemy, or a label that turns with a ship.

        Its widgets move and zoom with the camera, and the pointer is taken
        into the same space to find what is under it. They are drawn when the
        block ends, beneath whatever is drawn after it, so where the block
        sits decides what covers what.

        ```mojo
        # In `update`, with `ui: UI`, `camera: Camera` and `chest: Point`
        # fields:
        canvas.camera(self.camera)
        with self.ui.world(context, canvas) as ui:
            if ui.button("Open", Rectangle(self.chest + Vector(0, 40), 80, 32)):
                self.open_chest()
        ```
        """
        self._begin_layer(context)
        return UILayer(
            _ui=self,
            _context=context,
            _canvas=canvas,
            _frame=context.frame_count(),
            _view=canvas._current_view(),
        )

    def _begin_layer(mut self, mut context: Context):
        """Start a layer, resetting the per-frame state when it is the first
        layer of a new frame."""
        var frame = context.frame_count()
        ref mouse = context.mouse
        ref keyboard = context.keyboard
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
            self._key_used = False
            if self._focused:
                var still_there = False
                for hit in self._last_hits:
                    if hit.id == self._focused.value():
                        still_there = True
                        break
                if not still_there:
                    self._clear_focus()  # its widget wasn't called last frame
                elif keyboard.pressed(Key.ESCAPE):
                    self._clear_focus()
                    self._key_used = True
            if mouse.pressed() and not self._hot:
                self._clear_focus()  # a click on no widget
            if keyboard.typed(Key.TAB):
                self._tab(
                    backwards=keyboard.down(Key.LEFT_SHIFT)
                    or keyboard.down(Key.RIGHT_SHIFT)
                )
            self._drop_unseen_buffers()
            self._sync_text_input(context)
        self._recorder.commands.clear()

    def _tab(mut self, backwards: Bool):
        """Move focus to the next widget Tab can reach, in the order they were
        called last frame, or the previous one `backwards`; from no focus, to
        the first or the last. The order wraps round."""
        var order = List[_Hit]()
        for hit in self._last_hits:
            if hit.focusable:
                order.append(hit)
        if not order:
            return
        var at = -1
        if self._focused:
            for i in range(len(order)):
                if order[i].id == self._focused.value():
                    at = i
                    break
        var next: Int
        if at == -1:
            next = len(order) - 1 if backwards else 0
        elif backwards:
            next = (at - 1 + len(order)) % len(order)
        else:
            next = (at + 1) % len(order)
        self._focus(
            order[next].id, visible=True, takes_typing=order[next].takes_typing
        )
        self._key_used = True

    def _focus(mut self, id: UInt64, visible: Bool, takes_typing: Bool = False):
        self._focused = id
        self._focus_visible = visible
        self._focused_takes_typing = takes_typing

    def _sync_text_input(mut self, mut context: Context):
        """Switch `context.text_input` on when a widget that takes typing
        gains focus, and off when it loses it, and leave it alone otherwise,
        so a program that turns typing on for its own use keeps it."""
        var typing = Bool(self._focused) and self._focused_takes_typing
        if typing != self._typing_was:
            context.text_input(typing)
            self._typing_was = typing

    def _drop_unseen_buffers(mut self):
        """Forget the text fields not called last frame: their text is the
        program's, and only the caret and selection go."""
        if not self._buffers:
            return
        var gone = List[UInt64]()
        for id in self._buffers.keys():
            var seen = False
            for hit in self._last_hits:
                if hit.id == id:
                    seen = True
                    break
            if not seen:
                gone.append(id)
        for id in gone:
            try:
                _ = self._buffers.pop(id)
            except:
                pass  # listed from the keys a moment ago: always there

    def _clear_focus(mut self):
        self._focused = None
        self._focus_visible = False
        self._focused_takes_typing = False

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
