"""`UI`: the widgets' state, kept from frame to frame."""

from std.reflection import SourceLocation

from create.color import Color
from create.core import Context
from create.geometry import Rectangle
from create.input import Gamepad, GamepadButton, Key, Keyboard, Mouse
from create.math import Point, Transform, Vector
from create.render import Canvas, Style
from ._id import _mix, _site
from ._layout import _Layout
from ._recorder import _Recorder
from ._text_buffer import _TextBuffer
from .layer import UILayer
from .colors import ColorScheme, FocusRing, StateLayers


@fieldwise_init
struct _Styles(Copyable, ImplicitlyCopyable, Movable):
    """What the open `ui.style` blocks set, merged: each widget's call style
    sits over these."""

    var button: Style
    var label: Style
    var panel: Style
    var slider_track: Style
    var slider_active_track: Style
    var slider_handle: Style
    var slider_handle_outline: Style
    var checkbox_box: Style
    var checkbox_checked_box: Style
    var checkbox_tick: Style
    var checkbox_label: Style
    var text_field_container: Style
    var text_field_focused: Style
    var text_field_text: Style
    var text_field_placeholder: Style
    var text_field_caret: Style
    var text_field_selection: Style

    def __init__(out self):
        self.button = Style()
        self.label = Style()
        self.panel = Style()
        self.slider_track = Style()
        self.slider_active_track = Style()
        self.slider_handle = Style()
        self.slider_handle_outline = Style()
        self.checkbox_box = Style()
        self.checkbox_checked_box = Style()
        self.checkbox_tick = Style()
        self.checkbox_label = Style()
        self.text_field_container = Style()
        self.text_field_focused = Style()
        self.text_field_text = Style()
        self.text_field_placeholder = Style()
        self.text_field_caret = Style()
        self.text_field_selection = Style()

    def _over(self, under: Self) -> Self:
        return _Styles(
            self.button.over(under.button),
            self.label.over(under.label),
            self.panel.over(under.panel),
            self.slider_track.over(under.slider_track),
            self.slider_active_track.over(under.slider_active_track),
            self.slider_handle.over(under.slider_handle),
            self.slider_handle_outline.over(under.slider_handle_outline),
            self.checkbox_box.over(under.checkbox_box),
            self.checkbox_checked_box.over(under.checkbox_checked_box),
            self.checkbox_tick.over(under.checkbox_tick),
            self.checkbox_label.over(under.checkbox_label),
            self.text_field_container.over(under.text_field_container),
            self.text_field_focused.over(under.text_field_focused),
            self.text_field_text.over(under.text_field_text),
            self.text_field_placeholder.over(under.text_field_placeholder),
            self.text_field_caret.over(under.text_field_caret),
            self.text_field_selection.over(under.text_field_selection),
        )


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
    var adjusts: Bool
    """Whether left and right on a gamepad change it, as they step a
    slider, rather than move focus away from it."""

    def contains(self, screen: Point) -> Bool:
        return self.rect.contains(self.to_local.apply(screen))

    def centre(self) -> Point:
        """Its rectangle's centre, on the screen."""
        return self.to_local.inverse().apply(self.rect.position)


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
    var _rings: _Recorder
    """The focus ring, drawn on top of the layer it is in, so a neighbour
    never covers it."""
    var _colors: ColorScheme
    """The colours the layer open now was given."""
    var _color_blocks: List[ColorScheme]
    """The colours of the open `ui.colors` blocks, innermost last."""
    var _corner_radius: Float64
    var _spacing: Float64
    var _control_height: Float64
    var _state_layers: StateLayers
    var _focus_ring: FocusRing
    var _styles: List[_Styles]
    """The open `ui.style` blocks, each merged over the ones outside it."""
    var _contents: List[Color]
    """The content colours of the open panels, innermost last."""
    var _layouts: List[_Layout]
    """The open panels, columns and rows, innermost last: what a widget
    called without a rect is placed by."""
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
    var _claimant: Int
    """This UI's number for claiming the keyboard and mouse, so several UIs
    in one program take turns at them; 0 until its first layer opens."""
    var _typing_was: Bool
    """Whether a widget that takes typing had focus when `text_input` was
    last switched: the UI switches it only when that changes."""
    var _player: Optional[Int]
    """The one gamepad that drives this UI, or `None` for any."""
    var _focus_from_gamepad: Bool
    """Whether focus came from a gamepad: it then doesn't claim the keyboard,
    so two split-screen UIs with their own pads keep their own focus."""
    var _stick_was: Vector
    """Which way the left stick pointed last frame, so a push moves focus
    once rather than every frame."""
    var _pad_move: Vector
    """This frame's push on the d-pad or the left stick: up, down, left or
    right, or zero."""
    var _key_used: Bool
    """Whether a key was the UI's this frame: Tab moving focus, Escape
    taking it away, or a key acting on the focused widget."""
    var _last_changed: Bool
    """Whether the widget called last changed its value: what
    `ui.changed()` reports."""
    var _last_submitted: Bool
    """Whether Enter was pressed in the widget called last: what
    `ui.submitted()` reports."""
    var _last_text_field: Optional[UInt64]
    """The ID of the widget called last when it is a text field, for
    `ui.text_editor()`; `None` when it is any other widget."""

    def __init__(out self, *, player: Optional[Int] = None):
        """A UI whose focus any gamepad moves, unless `player` names one, as
        each player's menu in a split-screen game would."""
        self._player = player
        self._focus_from_gamepad = False
        self._stick_was = Vector.ZERO
        self._pad_move = Vector.ZERO
        self._colors = ColorScheme.light()
        self._color_blocks = []
        self._corner_radius = 16
        self._spacing = 8
        self._control_height = 40
        self._state_layers = StateLayers()
        self._focus_ring = FocusRing()
        self._styles = []
        self._contents = []
        self._layouts = []
        self._frame = -1
        self._site_counts = {}
        self._keys = []
        self._recorder = _Recorder()
        self._rings = _Recorder()
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
        self._claimant = 0
        self._last_changed = False
        self._last_submitted = False
        self._last_text_field = None

    def corner_radius(self) -> Float64:
        """How round the widgets' corners are: a panel's radius, 16 unless
        set. Smaller parts are rounded in proportion: a text field's by a
        quarter of it, a checkbox's box by an eighth."""
        return self._corner_radius

    def corner_radius(mut self, radius: Float64):
        """Round the widgets' corners by `radius` from now on; 0 squares
        them."""
        self._corner_radius = radius

    def spacing(self) -> Float64:
        """The gap between the widgets in a `ui.column` or `ui.row`, 8 unless
        set. A panel is inset by twice it, and `ui.space()` leaves twice it
        empty."""
        return self._spacing

    def spacing(mut self, spacing: Float64):
        """Space the widgets by `spacing` from now on."""
        self._spacing = spacing

    def control_height(self) -> Float64:
        """How tall a button, slider, checkbox or text field is in a
        `ui.column`, and how tall a `ui.row` is, unless told otherwise: 40
        unless set."""
        return self._control_height

    def control_height(mut self, height: Float64):
        """Make the controls `height` tall from now on."""
        self._control_height = height

    def state_layers(self) -> StateLayers:
        """How strongly a widget shows that it is hovered, focused, pressed,
        dragged or disabled."""
        return self._state_layers

    def state_layers(mut self, layers: StateLayers):
        """Show the widgets' states as `layers` says from now on."""
        self._state_layers = layers

    def focus_ring(self) -> FocusRing:
        """The ring drawn around a widget focused from the keyboard, a
        gamepad or `take_focus`."""
        return self._focus_ring

    def focus_ring(mut self, ring: FocusRing):
        """Draw the focus ring as `ring` from now on."""
        self._focus_ring = ring

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
        keyboard, Tab say, rather than from a click or a gamepad, since the
        keys then act on it: Enter and Space press a button, the arrows move a slider. It
        is also in the frame a key moved or took away focus, such as Escape
        leaving a text field. A game checks it before reading keys itself,
        so typing a name with W in it doesn't move the player.

        ```mojo
        # In `update`, before or after the UI's `with` block:
        if context.keyboard.pressed(Key.ESCAPE) and not self.ui.wants_keyboard():
            context.quit()
        ```
        """
        return self._holds_keys() or self._key_used

    def screen(
        mut self,
        mut context: Context,
        mut canvas: Canvas,
        colors: ColorScheme = ColorScheme.light(),
    ) -> UILayer[origin_of(self), origin_of(context), origin_of(canvas)]:
        """Open a layer drawn in screen space, on top of everything drawn
        before its block ends, whatever the camera and transform. Its widgets
        are drawn in `colors`, the light scheme unless given.

        ```mojo
        # In `update`, with `ui: UI` and `colors: ColorScheme` fields:
        canvas.background(self.colors.background)
        with self.ui.screen(context, canvas, self.colors) as ui:
            ...
        ```
        """
        self._begin_layer(context)
        self._colors = colors
        return UILayer(
            _ui=self,
            _context=context,
            _canvas=canvas,
            _frame=context.frame_count(),
        )

    def world(
        mut self,
        mut context: Context,
        mut canvas: Canvas,
        colors: ColorScheme = ColorScheme.light(),
    ) -> UILayer[origin_of(self), origin_of(context), origin_of(canvas)]:
        """Open a layer drawn in the space that is current when the block
        opens, the camera and any transform included: for a button above a
        chest, a health bar over an enemy, or a label that turns with a ship.

        Its widgets move and zoom with the camera, and the pointer is taken
        into the same space to find what is under it. They are drawn when the
        block ends, beneath whatever is drawn after it, so where the block
        sits decides what covers what. Its widgets are drawn in `colors`, the
        light scheme unless given.

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
        self._colors = colors
        return UILayer(
            _ui=self,
            _context=context,
            _canvas=canvas,
            _frame=context.frame_count(),
            _view=canvas._current_view(),
        )

    def _called(
        mut self,
        *,
        changed: Bool,
        submitted: Bool = False,
        text_field: Optional[UInt64] = None,
    ):
        """Record what the widget just called did, for `ui.changed()`,
        `ui.submitted()` and `ui.text_editor()` to report."""
        self._last_changed = changed
        self._last_submitted = submitted
        self._last_text_field = text_field

    def _begin_layer(mut self, mut context: Context):
        """Start a layer, resetting the per-frame state when it is the first
        layer of a new frame."""
        var frame = context.frame_count()
        if self._claimant == 0:
            self._claimant = context._new_claimant()
        ref mouse = context.mouse
        ref keyboard = context.keyboard
        # another UI holding a device: this one leaves it alone
        var keyboard_taken = keyboard._claim.held_by_other(
            self._claimant, frame
        )
        var mouse_taken = mouse._claim.held_by_other(self._claimant, frame)
        if frame != self._frame:
            self._frame = frame
            self._site_counts.clear()
            self._keys.clear()
            self._color_blocks.clear()
            self._styles.clear()
            self._contents.clear()
            self._layouts.clear()
            self._disabled_depth = 0
            self._called(changed=False)
            swap(self._last_hits, self._hits)
            self._hits.clear()
            self._hot = None
            if not mouse_taken:
                for i in reversed(range(len(self._last_hits))):
                    if self._last_hits[i].contains(mouse.position):
                        self._hot = self._last_hits[i].id
                        break
            if mouse_taken or (not mouse.down() and not mouse.released()):
                self._held = None
            self._key_used = False
            if keyboard_taken and self._holds_keys():
                self._clear_focus()  # another UI has taken the keyboard
            if self._focused:
                var still_there = False
                for hit in self._last_hits:
                    if hit.id == self._focused.value():
                        still_there = True
                        break
                if not still_there:
                    self._clear_focus()  # its widget wasn't called last frame
                elif keyboard.pressed(Key.ESCAPE) and not keyboard_taken:
                    self._clear_focus()
                    self._key_used = True
            if mouse.pressed() and not self._hot_focusable():
                self._clear_focus()  # a click on no widget, or on a panel
            if keyboard.typed(Key.TAB) and not keyboard_taken:
                self._tab(
                    backwards=keyboard.down(Key.LEFT_SHIFT)
                    or keyboard.down(Key.RIGHT_SHIFT)
                )
            var push = self._pad_push(context)
            self._pad_move = push
            if self._pad_pressed(context, GamepadButton.EAST):
                self._clear_focus()  # back out, as Escape does
            elif push != Vector.ZERO and not self._steps_focused(push):
                self._move_focus(push)
            self._drop_unseen_buffers()
            self._sync_text_input(context)
        self._sync_claims(context)
        self._recorder.commands.clear()
        self._rings.commands.clear()

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

    def _focus(
        mut self,
        id: UInt64,
        visible: Bool,
        takes_typing: Bool = False,
        from_gamepad: Bool = False,
    ):
        self._focused = id
        self._focus_visible = visible
        self._focused_takes_typing = takes_typing
        self._focus_from_gamepad = from_gamepad

    def _current_colors(self) -> ColorScheme:
        """The colours widgets are drawn in here: the innermost `ui.colors`
        block's, or the layer's."""
        if self._color_blocks:
            return self._color_blocks[len(self._color_blocks) - 1]
        return self._colors

    def _current_styles(self) -> _Styles:
        if self._styles:
            return self._styles[len(self._styles) - 1]
        return _Styles()

    def _content_color(self) -> Color:
        """The colour for text here: the innermost panel's, or the colours'
        `on_surface`."""
        if self._contents:
            return self._contents[len(self._contents) - 1]
        return self._current_colors().on_surface

    def _hot_focusable(self) -> Bool:
        """Whether the widget under the pointer can take focus: not a panel,
        nor a disabled widget."""
        if not self._hot:
            return False
        for hit in self._last_hits:
            if hit.id == self._hot.value():
                return hit.focusable
        return False

    def _holds_keys(self) -> Bool:
        """Whether this UI's focus takes keys: from the keyboard or code, or
        on a widget that takes typing. Focus from a gamepad doesn't."""
        return Bool(self._focused) and (
            (self._focus_visible and not self._focus_from_gamepad)
            or self._focused_takes_typing
        )

    def _pads(self, context: Context) -> List[Gamepad]:
        """The gamepads that drive this UI: its player's, or every one."""
        if self._player:
            return [context.gamepad(self._player.value())]
        return context._gamepads._slots.copy()

    def _pad_pressed(self, context: Context, button: GamepadButton) -> Bool:
        """Whether `button` went down this frame on a pad that drives this
        UI."""
        for pad in self._pads(context):
            if pad.connected and pad.pressed(button):
                return True
        return False

    def _pad_push(mut self, context: Context) -> Vector:
        """This frame's push on the d-pad, or the left stick tipped past
        halfway: up, down, left or right, once per push."""
        if self._pad_pressed(context, GamepadButton.DPAD_UP):
            return Vector.UP
        if self._pad_pressed(context, GamepadButton.DPAD_DOWN):
            return Vector.DOWN
        if self._pad_pressed(context, GamepadButton.DPAD_LEFT):
            return Vector.LEFT
        if self._pad_pressed(context, GamepadButton.DPAD_RIGHT):
            return Vector.RIGHT
        var stick = Vector.ZERO
        for pad in self._pads(context):
            if pad.connected and pad.left_stick.magnitude() > 0.5:
                var s = pad.left_stick
                if abs(s.x) > abs(s.y):
                    stick = Vector.RIGHT if s.x > 0 else Vector.LEFT
                else:
                    stick = Vector.UP if s.y > 0 else Vector.DOWN
                break
        var push = stick if stick != self._stick_was else Vector.ZERO
        self._stick_was = stick
        return push

    def _steps_focused(self, push: Vector) -> Bool:
        """Whether `push` changes the focused widget rather than moving
        focus: left or right on a slider."""
        if not self._focused or push.y != 0:
            return False
        for hit in self._last_hits:
            if hit.id == self._focused.value():
                return hit.adjusts
        return False

    def _move_focus(mut self, direction: Vector):
        """Move focus to the nearest widget in `direction`, judged from where
        the widgets were drawn last frame; from no focus, to the first one.
        A widget straight ahead beats a nearer one off to the side."""
        var at = Optional[Point](None)
        for hit in self._last_hits:
            if self._focused and hit.id == self._focused.value():
                at = hit.centre()
        var best = -1
        var best_score = 0.0
        for i in range(len(self._last_hits)):
            ref hit = self._last_hits[i]
            if not hit.focusable:
                continue
            if not at:
                best = i  # nothing focused: the first that can be
                break
            var offset = hit.centre() - at.value()
            var ahead = offset.dot(direction)
            if ahead <= 1:
                continue
            var aside = abs(offset.x * direction.y - offset.y * direction.x)
            var score = ahead + 2 * aside
            if best == -1 or score < best_score:
                best = i
                best_score = score
        if best != -1:
            ref hit = self._last_hits[best]
            self._focus(
                hit.id,
                visible=True,
                takes_typing=hit.takes_typing,
                from_gamepad=True,
            )

    def _sync_claims(self, mut context: Context):
        """Claim the keyboard while this UI's focus takes keys, and the mouse
        while one of its widgets is held, renewing the claims every frame;
        let go of them otherwise."""
        var frame = context.frame_count()
        if self._holds_keys():
            context.keyboard._claim.claim(self._claimant, frame)
        else:
            context.keyboard._claim.release(self._claimant)
        if self._held:
            context.mouse._claim.claim(self._claimant, frame)
        else:
            context.mouse._claim.release(self._claimant)

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
        self._focus_from_gamepad = False
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
