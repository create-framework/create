"""`UILayer`: the handle a `ui.screen` block draws widgets with."""

from std.reflection import SourceLocation, call_location

from create.color import Color
from create.core import Context
from create.geometry import Circle, Drawable, Line, Rectangle
from create.input import GamepadButton, Key
from create.image import Image
from create.math import Point, Transform, Vector
from create.math._optional_float64 import _OptionalFloat64
from create.render import Align, Canvas, StrokeAlign, StrokeCap, Style
from create.render.canvas import _View, _ViewGuard
from ._id import _mix
from ._key import _WidgetKey
from .button import ButtonStyle, ButtonVariant
from .checkbox import CheckboxStyle
from .label import LabelStyle
from .slider import SliderStyle
from ._text_buffer import _TextBuffer
from .text_field import TextFieldResult, TextFieldStyle
from .theme import ColorScheme, FocusRing, Theme, TypeStyle, _readable_on
from .panel import PanelStyle
from .ui import UI, _Hit, _Styles


comptime _PRESSED_SHADOW = Color(0, 0, 0, 45)
"""The inset shadow a pressed filled or tonal button is drawn with."""

comptime _HANDLE_SHADOW = Color(0, 0, 0, 70)
"""The shadow a slider's handle casts with `handle_shadow=True`."""

comptime _PANEL_SHADOW = Color(0, 0, 0, 60)
"""The shadow a panel casts with `shadow=True`."""


@fieldwise_init
struct _Interaction(Copyable, ImplicitlyCopyable, Movable):
    """What the pointer did to a widget this frame."""

    var hovered: Bool
    var pressed: Bool
    """Held down with the pointer still over it: drawn pressed."""
    var clicked: Bool
    """Released over it, after being pressed on it."""
    var focused: Bool
    var activated: Bool
    """Enter or Space pressed while it has focus from the keyboard."""


struct UILayer[
    ui_origin: Origin[mut=True],
    context_origin: Origin[mut=True],
    canvas_origin: Origin[mut=True],
](ImplicitlyCopyable):
    """The handle a `with self.ui.screen(context, canvas) as ui:` or
    `ui.world` block gets: every widget is a method on it.

    It points at the `UI`, the context and the canvas, so a widget needs none
    of them passed, and the block can still use them, and the program's other
    fields, directly. A helper takes it as `ui: UILayer`, its parameters left
    to be inferred. Everything drawn through it is drawn when the block ends,
    in the order it was called.

    Every widget that reacts to the pointer takes the same three keywords:

    - `take_focus=True` gives it focus in the frame it is passed, as a click
      would; if several widgets ask in one frame, the last one called gets
      it.
    - `disabled=True` draws it faded and stops it reacting, as a
      `ui.disabled` block around it would.
    - `id=` adds a key to its ID, as a `ui.id` block around it would.
    """

    var _ui: Pointer[UI, Self.ui_origin]
    var _context: Pointer[Context, Self.context_origin]
    var _canvas: Pointer[Canvas, Self.canvas_origin]
    var _frame: Int
    var _to_local: Transform
    """Takes a screen point into the layer's space."""
    var _view: Optional[_View]
    """For a `world` layer, the camera and transform it draws through; a
    `screen` layer has none and draws in screen space."""

    def __init__(
        out self,
        *,
        ref[Self.ui_origin] _ui: UI,
        ref[Self.context_origin] _context: Context,
        ref[Self.canvas_origin] _canvas: Canvas,
        _frame: Int,
        _view: Optional[_View] = None,
    ):
        self._ui = Pointer(to=_ui)
        self._context = Pointer(to=_context)
        self._canvas = Pointer(to=_canvas)
        self._frame = _frame
        self._view = _view
        self._to_local = _view.value().to_local() if _view else Transform()

    def __enter__(self) -> Self:
        return self

    def __exit__(self) raises:
        ref ui = self._ui[]
        for ref command in ui._rings.commands:
            ui._recorder.commands.append(command.copy())
        ui._rings.commands.clear()
        if self._view:
            with _ViewGuard(_canvas=self._canvas[], _view=self._view.value()):
                self._ui[]._recorder.replay(self._canvas[])
        else:
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
        return self._ui[]._current_theme()

    def theme(self, theme: Theme) raises -> ThemeGuard[Self.ui_origin]:
        """Draw the widgets inside a `with` block in `theme`, such as one
        panel in the dark theme on a light screen.

        ```mojo
        # In `update`, inside `with self.ui.screen(context, canvas) as ui:`:
        with ui.theme(Theme.dark()):
            if ui.button("Night mode", Rectangle((0, 0), 160, 48)):
                ...
        ```
        """
        self._check_frame()
        return ThemeGuard(_ui=self._ui[], _theme=theme)

    def style(
        self,
        *,
        button: ButtonStyle = ButtonStyle(),
        label: LabelStyle = LabelStyle(),
        slider: SliderStyle = SliderStyle(),
        checkbox: CheckboxStyle = CheckboxStyle(),
        text_field: TextFieldStyle = TextFieldStyle(),
    ) raises -> WidgetStyleGuard[Self.ui_origin]:
        """Style every widget of a kind inside a `with` block. The styles
        given sit under each call's own style and over any block outside
        this one, field by field: a field a call sets wins, and a field
        nothing sets comes from the theme.

        ```mojo
        # In `update`, inside `with self.ui.screen(context, canvas) as ui:`:
        with ui.style(button=ButtonStyle(corner_radius=4)):
            _ = ui.button("Square", Rectangle((0, 0), 120, 40))
            _ = ui.button("Round", Rectangle((0, -50), 120, 40),
                          style=ButtonStyle(corner_radius=20))
        ```
        """
        self._check_frame()
        return WidgetStyleGuard(
            _ui=self._ui[],
            _styles=_Styles(button, label, slider, checkbox, text_field),
        )

    def content_color(self) -> Color:
        """The colour for text here: the innermost panel's content colour, or
        the theme's `on_surface`. A program's own widget draws its text in it
        to match the built-in ones."""
        return self._ui[]._content_color()

    @always_inline
    def panel(
        self,
        rect: Rectangle,
        *,
        style: PanelStyle = PanelStyle(),
        id: _WidgetKey = None,
    ) raises -> PanelGuard[Self.ui_origin]:
        """A surface filling `rect`, drawn beneath everything called inside
        its `with` block. Text on it takes its content colour, so a label on
        a dark panel turns light without being told, and it covers what is
        beneath it from the pointer. It doesn't place what is inside it.

        ```mojo
        # In `update`, inside `with self.ui.screen(context, canvas) as ui:`:
        with ui.panel(Rectangle((0, 0), 320, 120)):
            ui.label("Volume", Rectangle((0, 30), 280, 24))
            _ = ui.slider(self.volume, 0, 1, Rectangle((0, -15), 280, 32))
        ```
        """
        return self._panel(
            self._widget_id(call_location(), id._hash), rect, style
        )

    def _panel(
        self, id: UInt64, rect: Rectangle, style: PanelStyle
    ) raises -> PanelGuard[Self.ui_origin]:
        ref ui = self._ui[]
        var theme = ui._current_theme()
        ref colors = theme.colors
        # a surface the pointer can't reach through, nor focus
        ui._hits.append(_Hit(id, rect, self._to_local, False, False, False))
        var color = style.color.or_else(colors.surface_container)
        var content = style.content_color.or_else(_content_on(colors, color))
        ui._recorder.style = Style(
            fill=color,
            stroke=style.outline_color.or_else(Color.TRANSPARENT),
            stroke_thickness=style.outline_thickness.or_else(1.0),
            stroke_enabled=Bool(style.outline_color),
        )
        if style.shadow:
            ui._recorder.style.shadow_color = _PANEL_SHADOW
            ui._recorder.style.shadow_offset = Vector(0, -3)
            ui._recorder.style.shadow_blur = 12
            ui._recorder.style.shadow_spread = 0
            ui._recorder.style.shadow_inset = False
            ui._recorder.style.shadow_enabled = True
        ui._recorder.draw(
            Rectangle(
                rect.position,
                rect.width,
                rect.height,
                corner_radius=style.corner_radius.or_else(
                    theme.corner_radii.large
                ),
            )
        )
        return PanelGuard(_ui=ui, _content=content)

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

    # ------------------------------------------------------------ widgets

    @always_inline
    def button(
        self,
        text: String,
        rect: Rectangle,
        *,
        variant: ButtonVariant = ButtonVariant.FILLED,
        style: ButtonStyle = ButtonStyle(),
        take_focus: Bool = False,
        disabled: Bool = False,
        id: _WidgetKey = None,
    ) raises -> Bool:
        """A button showing `text`, filling `rect`. Returns whether it was
        clicked this frame: pressed and released with the pointer over it.

        ```mojo
        # In `update`, inside `with self.ui.screen(context, canvas) as ui:`:
        if ui.button("Play", Rectangle((0, 0), 160, 48)):
            self.start()
        ```
        """
        return self._button(
            self._widget_id(call_location(), id._hash),
            text,
            rect,
            variant,
            style,
            take_focus,
            disabled,
        )

    def label(
        self,
        text: String,
        rect: Rectangle,
        *,
        alignment: Align = Align.CENTER,
        style: LabelStyle = LabelStyle(),
    ) raises:
        """Text placed in `rect`, by `alignment`: in its centre unless given,
        against its left edge with `Align.LEFT`, and so on. It reacts to
        nothing, so the pointer passes through it to what is beneath.

        ```mojo
        # In `update`, inside `with self.ui.screen(context, canvas) as ui:`:
        ui.label("Volume", Rectangle((0, 40), 240, 24), alignment=Align.LEFT)
        ```
        """
        self._check_frame()
        var theme = self._ui[]._current_theme()
        var merged = style._over(self._ui[]._current_styles().label)
        var type = merged.text_style.or_else(theme.typography.body)
        self._ui[]._recorder.text(
            text,
            _anchor(rect, alignment),
            _text_style(
                type,
                merged.color.or_else(self._ui[]._content_color()),
                alignment,
            ),
        )

    def image(self, image: Image, rect: Rectangle) raises:
        """`image` stretched to fill `rect`. Like a label, it reacts to
        nothing."""
        self._check_frame()
        self._ui[]._recorder.image(
            image, rect.position, rect.width, rect.height, Style()
        )

    @always_inline
    def slider(
        self,
        mut value: Float64,
        min: Float64,
        max: Float64,
        rect: Rectangle,
        *,
        step: _OptionalFloat64 = None,
        style: SliderStyle = SliderStyle(),
        take_focus: Bool = False,
        disabled: Bool = False,
        id: _WidgetKey = None,
    ) raises -> Bool:
        """A slider across `rect` that sets `value` between `min` and `max`.
        Returns whether it changed `value` this frame.

        Pressing anywhere in `rect` moves the handle there, and dragging
        moves it on, even once the pointer leaves `rect`. `step` rounds the
        value to multiples of it from `min`. A `value` outside `min` to
        `max` is drawn at the nearer end, and left as it is until dragged.

        ```mojo
        # In `update`, inside `with self.ui.screen(context, canvas) as ui:`:
        if ui.slider(self.volume, 0, 1, Rectangle((0, 0), 240, 32)):
            self.audio.volume(self.volume)
        ```
        """
        return self._slider(
            self._widget_id(call_location(), id._hash),
            value,
            min,
            max,
            rect,
            step._value,
            style,
            take_focus,
            disabled,
        )

    @always_inline
    def checkbox(
        self,
        label: String,
        mut checked: Bool,
        rect: Rectangle,
        *,
        style: CheckboxStyle = CheckboxStyle(),
        take_focus: Bool = False,
        disabled: Bool = False,
        id: _WidgetKey = None,
    ) raises -> Bool:
        """A box against the left edge of `rect`, ticked while `checked` is
        `True`, with `label` beside it. A click anywhere in `rect` switches
        `checked`. Returns whether it changed `checked` this frame.

        ```mojo
        # In `update`, inside `with self.ui.screen(context, canvas) as ui:`:
        if ui.checkbox("Sound", self.sound_on, Rectangle((0, 0), 200, 32)):
            self.save_settings()
        ```
        """
        return self._checkbox(
            self._widget_id(call_location(), id._hash),
            label,
            checked,
            rect,
            style,
            take_focus,
            disabled,
        )

    @always_inline
    def text_field[
        text_origin: Origin[mut=True]
    ](
        self,
        ref[text_origin] text: String,
        rect: Rectangle,
        *,
        placeholder: String = "",
        max_length: Optional[Int] = None,
        style: TextFieldStyle = TextFieldStyle(),
        take_focus: Bool = False,
        disabled: Bool = False,
        id: _WidgetKey = None,
    ) raises -> TextFieldResult[
        Self.ui_origin, Self.context_origin, text_origin
    ]:
        """A field for typing into `text`, filling `rect`. Clicking it gives
        it focus and places the caret; while it has focus, typing and the
        editing keys change `text`, and Enter submits it.

        Returns a `TextFieldResult`: whether the text changed, as a `Bool`,
        `submitted` for Enter, and the caret and selection. `placeholder` is
        shown in a fainter colour while `text` is empty, and `max_length`
        caps how many characters typing and pasting can bring it to.

        ```mojo
        # In `update`, inside `with self.ui.screen(context, canvas) as ui:`,
        # with a `name: String` field:
        var field = ui.text_field(
            self.name, Rectangle((0, 0), 320, 40), placeholder="Your name"
        )
        if field.submitted:
            self.start_game(self.name)
        ```
        """
        var widget = self._widget_id(call_location(), id._hash)
        var changed = False
        var submitted = False
        self._text_field(
            widget,
            text,
            rect,
            placeholder,
            max_length,
            style,
            take_focus,
            disabled,
            changed,
            submitted,
        )
        return TextFieldResult(
            _ui=self._ui[],
            _context=self._context[],
            _text=text,
            _id=widget,
            _changed=changed,
            _submitted=submitted,
        )

    # ----------------------------------------------------------- internals

    def _text_field(
        self,
        id: UInt64,
        mut text: String,
        rect: Rectangle,
        placeholder: String,
        max_length: Optional[Int],
        call_style: TextFieldStyle,
        take_focus: Bool,
        disabled: Bool,
        mut changed: Bool,
        mut submitted: Bool,
    ) raises:
        var style = call_style._over(self._ui[]._current_styles().text_field)
        var off = self._disabled(disabled)
        var state = self._interact(id, rect, off, take_focus, takes_typing=True)
        ref ui = self._ui[]
        ui._sync_text_input(self._context[])
        var theme = ui._current_theme()
        ref colors = theme.colors
        if id not in ui._buffers:
            ui._buffers[id] = _TextBuffer(text)
        ref buffer = ui._buffers[id]
        buffer.text = text
        buffer.max_length = max_length
        var now = self._context[].time.elapsed
        var type = style.text_style.or_else(theme.typography.body)
        var text_color = style.text_color.or_else(colors.on_surface)
        var look = _text_style(type, text_color, Align.LEFT)
        var padding = style.padding.or_else(12.0)
        var left = rect.position.x - rect.width / 2 + padding
        var inner = rect.width - 2 * padding

        # a press places the caret under the pointer
        if state.hovered and self._context[].mouse.pressed():
            var typed = buffer.text  # a copy: measuring borrows the layer
            var pointer = self._to_local.apply(self._context[].mouse.position)
            buffer._place(
                self._offset_at(typed, pointer.x - left + buffer.scroll, look),
                select=False,
            )
            buffer.last_change = now
        if state.focused and self._keyboard_free():
            var before = buffer.text
            var caret = buffer.before_caret()
            buffer.update(self._context[])
            if buffer.text != before or buffer.before_caret() != caret:
                buffer.last_change = now
            submitted = self._context[].keyboard.pressed(Key.ENTER)
        if buffer.text != text:
            text = buffer.text
            changed = True

        # keep the caret inside the field while it has focus; without focus,
        # show the text from its start
        var caret_x = self._measure(buffer.before_caret(), look)
        if not state.focused:
            buffer.scroll = 0
        elif caret_x - buffer.scroll > inner:
            buffer.scroll = caret_x - inner
        elif caret_x - buffer.scroll < 0:
            buffer.scroll = caret_x
        var shown = buffer.text
        var whole = self._measure(shown, look)
        buffer.scroll = min(buffer.scroll, max(0.0, whole - inner))

        # the field
        var container = style.container_color.or_else(
            colors.surface_container_highest
        )
        var thickness = style.outline_thickness.or_else(1.0)
        var outline = style.outline_color.or_else(colors.outline)
        if state.focused and not off:
            outline = style.focused_outline_color.or_else(colors.primary)
            thickness *= 2
        var placeholder_color = style.placeholder_color.or_else(
            colors.on_surface_variant
        )
        if off:
            var states = theme.state_layers
            # the field's own colours, faded: the theme's text colour by
            # default, and a transparent one stays transparent
            text_color = _faded(text_color, states.disabled_content)
            placeholder_color = _faded(
                placeholder_color, states.disabled_content
            )
            if container.a > 0:
                container = _faded(colors.on_surface, states.disabled_container)
            outline = _faded(colors.on_surface, states.disabled_container)
        elif state.hovered and not state.focused and container.a > 0:
            container = _stepped(
                container, colors.on_surface, theme.state_layers.hovered
            )
        var shape = Rectangle(
            rect.position,
            rect.width,
            rect.height,
            corner_radius=style.corner_radius.or_else(theme.corner_radii.small),
        )
        ref recorder = ui._recorder
        if container.a > 0 or thickness > 0:
            recorder.style = Style(
                fill=container,
                fill_enabled=container.a > 0,
                stroke=outline,
                stroke_thickness=thickness,
                stroke_enabled=thickness > 0,
            )
            recorder.draw(shape)

        # the text, clipped to the inside of the field
        recorder.clip(
            Rectangle(rect.position, rect.width - padding, rect.height)
        )
        var origin_x = left - buffer.scroll
        var y = rect.position.y
        if state.focused and buffer.selected_text():
            var start = self._measure(buffer.before_selection(), look)
            var width = self._measure(buffer.selected_text(), look)
            recorder.style = Style(
                fill=style.selection_color.or_else(
                    colors.primary.with_alpha(70)
                ),
                stroke_enabled=False,
            )
            recorder.draw(
                Rectangle(
                    Point(origin_x + start + width / 2, y),
                    width,
                    type.size * 1.3,
                )
            )
        if buffer.text:
            recorder.text(
                buffer.text,
                Point(origin_x, y),
                _text_style(type, text_color, Align.LEFT),
            )
        elif placeholder:
            recorder.text(
                placeholder,
                Point(left, y),
                _text_style(type, placeholder_color, Align.LEFT),
            )
        # the caret: steady for a moment after a change, then blinking
        var since = now - buffer.last_change
        if (
            state.focused
            and not off
            and (since < 0.5 or Int(since * 2) % 2 == 1)
        ):
            var x = origin_x + caret_x
            recorder.style = Style(
                stroke=style.caret_color.or_else(colors.primary),
                stroke_thickness=2,
            )
            recorder.draw(
                Line(
                    Point(x, y - type.size * 0.65),
                    Point(x, y + type.size * 0.65),
                )
            )
        recorder.end_clip()

    def _ring_around(
        self,
        shape: Rectangle,
        state: _Interaction,
        disabled: Bool,
        ring: Optional[FocusRing],
    ):
        """Draw the focus ring around `shape`, its corners rounded by the
        shape's own radius grown by the gap, while the widget has focus from
        the keyboard or code."""
        if not self._shows_ring(state, disabled):
            return
        var look = ring.or_else(self._ui[]._current_theme().focus_ring)
        var gap = look.gap
        self._record_ring(
            Rectangle(
                shape.position,
                shape.width + 2 * gap,
                shape.height + 2 * gap,
                corner_radius=shape.corner_radius + gap,
            ),
            look,
        )

    def _ring_around(
        self,
        shape: Circle,
        state: _Interaction,
        disabled: Bool,
        ring: Optional[FocusRing],
    ):
        if not self._shows_ring(state, disabled):
            return
        var look = ring.or_else(self._ui[]._current_theme().focus_ring)
        self._record_ring(Circle(shape.position, shape.radius + look.gap), look)

    def _shows_ring(self, state: _Interaction, disabled: Bool) -> Bool:
        return state.focused and self._ui[]._focus_visible and not disabled

    def _record_ring[S: Drawable](self, shape: S, look: FocusRing):
        ref ui = self._ui[]
        ui._rings.style = Style(
            fill_enabled=False,
            stroke=look.color.or_else(ui._current_theme().colors.secondary),
            stroke_thickness=look.thickness,
            stroke_alignment=StrokeAlign.OUTSIDE,
        )
        ui._rings.draw(shape)

    def _measure(self, text: String, look: Style) raises -> Float64:
        """How wide `text` is drawn in `look`'s font, size and weight."""
        if not text:
            return 0
        with self._canvas[].style(look):
            return self._canvas[].text_width(text)

    def _offset_at(self, text: String, x: Float64, look: Style) raises -> Int:
        """The byte offset of the character boundary in `text` nearest to
        `x` units from its start."""
        var best = 0
        var best_distance = abs(x)
        var prefix = String()
        var offset = 0
        for character in text.codepoint_slices():
            prefix += character
            offset += character.byte_length()
            var distance = abs(x - self._measure(prefix, look))
            if distance < best_distance:
                best = offset
                best_distance = distance
        return best

    def _button(
        self,
        id: UInt64,
        text: String,
        rect: Rectangle,
        variant: ButtonVariant,
        call_style: ButtonStyle,
        take_focus: Bool,
        disabled: Bool,
    ) raises -> Bool:
        var style = call_style._over(self._ui[]._current_styles().button)
        var off = self._disabled(disabled)
        var state = self._interact(id, rect, off, take_focus)
        var theme = self._ui[]._current_theme()
        ref colors = theme.colors
        var container: Color
        var content: Color
        var outline: Optional[Color] = None
        if variant == ButtonVariant.TONAL:
            container = colors.secondary_container
            content = colors.on_secondary_container
        elif variant == ButtonVariant.OUTLINED:
            container = Color.TRANSPARENT
            content = colors.primary
            outline = colors.outline
        elif variant == ButtonVariant.TEXT:
            container = Color.TRANSPARENT
            content = colors.primary
        else:
            container = colors.primary
            content = colors.on_primary
        container = style.container_color.or_else(container)
        content = style.content_color.or_else(content)
        if style.outline_color:
            outline = style.outline_color
        var thickness = style.outline_thickness.or_else(1.0)
        if style.outline_thickness and not outline:
            outline = colors.outline
        if off:
            # Material's disabled look: everything in the text colour,
            # faded, whatever the variant
            var states = theme.state_layers
            content = _faded(colors.on_surface, states.disabled_content)
            if container.a > 0:
                container = _faded(colors.on_surface, states.disabled_container)
            if outline:
                outline = _faded(colors.on_surface, states.disabled_container)
        var radius = style.corner_radius.or_else(rect.height / 2)
        var shape = Rectangle(
            rect.position, rect.width, rect.height, corner_radius=radius
        )
        ref recorder = self._ui[]._recorder
        # a hovered or pressed button steps its lightness towards its text
        var step = 0.0
        if state.pressed:
            step = theme.state_layers.pressed
        elif state.hovered:
            step = theme.state_layers.hovered
        if step > 0 and container.a > 0:
            container = _stepped(container, content, step)
        if container.a > 0 or outline:
            recorder.style = Style(
                fill=container,
                fill_enabled=container.a > 0,
                stroke=outline.or_else(Color.TRANSPARENT),
                stroke_thickness=thickness,
                stroke_enabled=Bool(outline),
            )
            if state.pressed and container.a > 0:
                # pressed in: a soft shadow along the inside of the top edge
                recorder.style.shadow_color = _PRESSED_SHADOW
                recorder.style.shadow_offset = Vector(0, -2)
                recorder.style.shadow_blur = 4
                recorder.style.shadow_spread = 0
                recorder.style.shadow_inset = True
                recorder.style.shadow_enabled = True
            recorder.draw(shape)
        if step > 0 and container.a == 0:
            # no fill to step: a layer of the text colour, as strong as the
            # step would be over the surface beneath
            var opacity = _layer_opacity(colors.surface, content, step)
            recorder.style = Style(
                fill=content.with_alpha(UInt8(opacity * 255 + 0.5)),
                stroke_enabled=False,
            )
            recorder.draw(shape)
        self._ring_around(shape, state, off, style.focus_ring)
        recorder.text(
            text,
            rect.position,
            _text_style(
                style.text_style.or_else(theme.typography.label),
                content,
                Align.CENTER,
            ),
        )
        return state.clicked or state.activated

    def _slider(
        self,
        id: UInt64,
        mut value: Float64,
        min: Float64,
        max: Float64,
        rect: Rectangle,
        step: Optional[Float64],
        call_style: SliderStyle,
        take_focus: Bool,
        disabled: Bool,
    ) raises -> Bool:
        var style = call_style._over(self._ui[]._current_styles().slider)
        var off = self._disabled(disabled)
        var state = self._interact(id, rect, off, take_focus, adjusts=True)
        ref ui = self._ui[]
        var theme = ui._current_theme()
        ref colors = theme.colors
        var handle_radius = style.handle_radius.or_else(10.0)
        var thickness = style.track_thickness.or_else(4.0)
        var left = rect.position.x - rect.width / 2 + handle_radius
        var right = rect.position.x + rect.width / 2 - handle_radius
        var y = rect.position.y
        # held this frame, the frame it is let go of included
        var dragging = (
            Bool(ui._held) and ui._held.value() == id
        ) or state.clicked
        var changed = False
        if dragging and right > left and max != min:
            var pointer = self._to_local.apply(self._context[].mouse.position)
            var t = _clamp01((pointer.x - left) / (right - left))
            var new_value = min + t * (max - min)
            if step and step.value() > 0:
                var size = step.value()
                new_value = (
                    min + Float64(round((new_value - min) / size)) * size
                )
                if (max - min) * (new_value - max) > 0:
                    new_value -= size  # a step past `max` comes back inside
            if new_value != value:
                value = new_value
                changed = True
        var keys = self._keys_act(state.focused)
        var pad = state.focused and ui._focus_visible and ui._pad_move.x != 0
        if (keys or pad) and max != min:
            ref keyboard = self._context[].keyboard
            # a step, or a twentieth of the range
            var size = abs(step.value() if step else (max - min) / 20)
            if max < min:
                size = -size  # steps count from `min` towards `max`
            var low = min if min < max else max
            var high = max if min < max else min
            # Steps land on the grid of steps counted from `min`, so they
            # don't gather floating-point error: 1.0 stepped down by 0.05
            # twice is 0.9, not 0.8999999999999999.
            var steps_from_min = (value - min) / size
            var moved = value
            var towards_max = 0
            if pad:
                towards_max = 1 if ui._pad_move.x > 0 else -1
            elif keyboard.typed(Key.RIGHT) or keyboard.typed(Key.UP):
                towards_max = 1
            elif keyboard.typed(Key.LEFT) or keyboard.typed(Key.DOWN):
                towards_max = -1
            if towards_max != 0:
                var at = Float64(round(steps_from_min))
                var next = at + Float64(towards_max)
                moved = min + next * size
            elif keyboard.pressed(Key.HOME):
                moved = min
            elif keyboard.pressed(Key.END):
                moved = max
            if moved != value:
                if keys:
                    self._ui[]._key_used = True
                moved = low if moved < low else (
                    high if moved > high else moved
                )
                if moved != value:
                    value = moved
                    changed = True
        var t = 0.0
        if max != min:
            t = _clamp01((value - min) / (max - min))
        var handle_x = left + t * (right - left)
        var active = style.active_track_color.or_else(colors.primary)
        var inactive = style.inactive_track_color.or_else(
            colors.secondary_container
        )
        var handle = style.handle_color.or_else(colors.primary)
        if off:
            var states = theme.state_layers
            active = _faded(colors.on_surface, states.disabled_content)
            inactive = _faded(colors.on_surface, states.disabled_container)
            # solid, so the track doesn't show through it
            handle = colors.surface.lerp(
                colors.on_surface, states.disabled_content
            )
        ref recorder = ui._recorder
        recorder.style = Style(
            stroke=inactive,
            stroke_thickness=thickness,
            stroke_cap=StrokeCap.ROUND,
        )
        recorder.draw(Line(Point(left, y), Point(right, y)))
        if handle_x > left:
            recorder.style = Style(
                stroke=active,
                stroke_thickness=thickness,
                stroke_cap=StrokeCap.ROUND,
            )
            recorder.draw(Line(Point(left, y), Point(handle_x, y)))
        # a hovered or dragged handle is tinted, as a button is
        var tint = _readable_on(handle)
        var shown = handle
        if dragging:
            shown = _stepped(handle, tint, theme.state_layers.dragged)
        elif state.hovered:
            shown = _stepped(handle, tint, theme.state_layers.hovered)
        recorder.style = Style(
            fill=shown,
            stroke=style.handle_outline_color.or_else(Color.TRANSPARENT),
            stroke_thickness=1,
            stroke_enabled=Bool(style.handle_outline_color),
        )
        if style.handle_shadow:
            recorder.style.shadow_color = _HANDLE_SHADOW
            recorder.style.shadow_offset = Vector(0, -1)
            recorder.style.shadow_blur = 4
            recorder.style.shadow_spread = 0
            recorder.style.shadow_inset = False
            recorder.style.shadow_enabled = True
        var knob = Circle(Point(handle_x, y), handle_radius)
        recorder.draw(knob)
        self._ring_around(knob, state, off, style.focus_ring)
        return changed

    def _checkbox(
        self,
        id: UInt64,
        label: String,
        mut checked: Bool,
        rect: Rectangle,
        call_style: CheckboxStyle,
        take_focus: Bool,
        disabled: Bool,
    ) raises -> Bool:
        var style = call_style._over(self._ui[]._current_styles().checkbox)
        var off = self._disabled(disabled)
        var state = self._interact(id, rect, off, take_focus)
        if state.clicked or state.activated:
            checked = not checked
        var theme = self._ui[]._current_theme()
        ref colors = theme.colors
        comptime size = 18.0
        var left = rect.position.x - rect.width / 2
        # the box against the left edge, the label a gap after it
        var centre = Point(left + size / 2, rect.position.y)
        var box = Rectangle(
            centre, size, size, corner_radius=theme.corner_radii.small / 2
        )
        ref recorder = self._ui[]._recorder
        var accent = style.box_color.or_else(colors.primary)
        var check = style.check_color.or_else(colors.on_primary)
        var outline = style.outline_color.or_else(colors.on_surface_variant)
        var label_color = style.label_color.or_else(self._ui[]._content_color())
        if off:
            var faded = _faded(
                colors.on_surface, theme.state_layers.disabled_content
            )
            accent = faded
            check = colors.surface
            outline = faded
            label_color = faded
        # a hovered or pressed box is tinted, as a button is: a ticked one
        # towards its tick, an empty one with the text colour inside it
        var step = 0.0
        if state.pressed:
            step = theme.state_layers.pressed
        elif state.hovered:
            step = theme.state_layers.hovered
        if checked:
            var fill = accent
            if step > 0:
                fill = _stepped(accent, check, step)
            recorder.style = Style(fill=fill, stroke_enabled=False)
            recorder.draw(box)
            recorder.style = Style(
                stroke=check,
                stroke_thickness=2,
                stroke_cap=StrokeCap.ROUND,
            )
            var corner = centre + Vector(-1.5, -4.0)
            recorder.draw(Line(centre + Vector(-5.0, 0.5), corner))
            recorder.draw(Line(corner, centre + Vector(5.0, 5.0)))
        else:
            var layer = 0.0
            if step > 0:
                layer = _layer_opacity(colors.surface, colors.on_surface, step)
            recorder.style = Style(
                fill=colors.on_surface.with_alpha(UInt8(layer * 255 + 0.5)),
                fill_enabled=layer > 0,
                stroke=outline,
                stroke_thickness=2,
            )
            recorder.draw(box)
        self._ring_around(box, state, off, style.focus_ring)
        var text_left = Point(left + size + 12, rect.position.y)
        recorder.text(
            label,
            text_left,
            _text_style(
                style.text_style.or_else(theme.typography.body),
                label_color,
                Align.LEFT,
            ),
        )
        return state.clicked or state.activated

    def _interact(
        self,
        id: UInt64,
        rect: Rectangle,
        disabled: Bool,
        take_focus: Bool,
        takes_typing: Bool = False,
        adjusts: Bool = False,
    ) -> _Interaction:
        """Record that the widget `id` can be pointed at in `rect`, and work
        out what the pointer did to it. A disabled widget still covers what
        is beneath it, but nothing it does counts."""
        ref ui = self._ui[]
        ref mouse = self._context[].mouse
        ui._hits.append(
            _Hit(id, rect, self._to_local, not disabled, takes_typing, adjusts)
        )
        if disabled:
            if ui._held and ui._held.value() == id:
                ui._held = None  # disabled while held: let go of it
            if ui._focused and ui._focused.value() == id:
                ui._clear_focus()  # a disabled widget can't keep focus
            if ui._hot and ui._hot.value() == id and mouse.pressed():
                ui._clear_focus()  # a click on it is a click on no widget
            return _Interaction(False, False, False, False, False)
        if take_focus:
            ui._focus(id, visible=True, takes_typing=takes_typing)
        # while another widget is held, in this UI or another, this one
        # doesn't react to the pointer
        var free = (not ui._held or ui._held.value() == id) and not (
            mouse._claim.held_by_other(
                ui._claimant, self._context[].frame_count()
            )
        )
        var hovered = Bool(ui._hot) and ui._hot.value() == id and free
        if hovered and mouse.pressed():
            ui._held = id
            ui._focus(id, visible=False, takes_typing=takes_typing)
        var held = Bool(ui._held) and ui._held.value() == id
        var clicked = False
        if held and mouse.released():
            clicked = hovered
            ui._held = None
        ui._sync_claims(self._context[])
        var focused = Bool(ui._focused) and ui._focused.value() == id
        var activated = False
        if self._keys_act(focused):
            ref keyboard = self._context[].keyboard
            if keyboard.pressed(Key.ENTER) or keyboard.pressed(Key.SPACE):
                activated = True
                ui._key_used = True
        if (
            focused
            and ui._focus_visible
            and ui._pad_pressed(self._context[], GamepadButton.SOUTH)
        ):
            activated = True
        return _Interaction(
            hovered,
            held and hovered and not clicked,
            clicked,
            focused,
            activated,
        )

    def _keys_act(self, focused: Bool) -> Bool:
        """Whether keys act on a widget: it has focus from the keyboard or
        code, not a click or a gamepad, so a game's own keys still work after
        a button is clicked or reached with a pad."""
        ref ui = self._ui[]
        return (
            focused
            and ui._focus_visible
            and not ui._focus_from_gamepad
            and self._keyboard_free()
        )

    def _keyboard_free(self) -> Bool:
        """Whether no other UI holds the keyboard."""
        return not self._context[].keyboard._claim.held_by_other(
            self._ui[]._claimant, self._context[].frame_count()
        )

    def _disabled(self, disabled: Bool) -> Bool:
        """Whether a widget given `disabled` is disabled: by its own keyword,
        or by a `ui.disabled` block around it."""
        return disabled or self._ui[]._disabled_depth > 0

    def disabled(
        self, condition: Bool = True
    ) raises -> DisabledGuard[Self.ui_origin]:
        """Disable every widget inside a `with` block while `condition` is
        true: they are drawn faded, don't react to the pointer, and return
        `False`. With `condition` false, the block's widgets work as usual,
        so a section can be switched on and off without an `if` around each
        widget.

        ```mojo
        # In `update`, inside `with self.ui.screen(context, canvas) as ui:`:
        with ui.disabled(not self.online):
            if ui.button("Find a game", Rectangle((0, 0), 200, 48)):
                ...
        ```
        """
        self._check_frame()
        return DisabledGuard(_ui=self._ui[], _active=condition)

    def _check_frame(self) raises:
        """Raise when the handle is used after the frame it was opened in."""
        if self._context[].frame_count() != self._frame:
            raise Error(
                "UILayer: used in frame "
                + String(self._context[].frame_count())
                + ", but opened in frame "
                + String(self._frame)
                + "; open a new layer with `ui.screen` or `ui.world` every"
                + " frame"
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


def _anchor(rect: Rectangle, alignment: Align) -> Point:
    """The point of `rect` that text placed by `alignment` is anchored to:
    its centre, or the middle of the edge or the corner `alignment` names."""
    var x = rect.position.x
    var y = rect.position.y
    if (
        alignment == Align.LEFT
        or alignment == Align.TOP_LEFT
        or alignment == Align.BOTTOM_LEFT
    ):
        x -= rect.width / 2
    elif (
        alignment == Align.RIGHT
        or alignment == Align.TOP_RIGHT
        or alignment == Align.BOTTOM_RIGHT
    ):
        x += rect.width / 2
    if (
        alignment == Align.TOP
        or alignment == Align.TOP_LEFT
        or alignment == Align.TOP_RIGHT
    ):
        y += rect.height / 2
    elif (
        alignment == Align.BOTTOM
        or alignment == Align.BOTTOM_LEFT
        or alignment == Align.BOTTOM_RIGHT
    ):
        y -= rect.height / 2
    return Point(x, y)


def _text_style(type: TypeStyle, color: Color, alignment: Align) -> Style:
    """A `Style` that draws text as `type` says, in `color`."""
    return Style(
        text_color=color,
        font=type.font,
        font_size=type.size,
        font_weight=type.weight,
        text_alignment=alignment,
    )


def _stepped(base: Color, toward: Color, step: Float64) -> Color:
    """`base` with its OKLCH lightness moved `step` towards `toward`'s,
    keeping its chroma and hue: a hovered or pressed widget's colour. A step
    of lightness looks like the same change on any colour, so every widget
    shows its state about as clearly, a pale fill as much as a dark one."""
    var at = base.to_oklch()
    var target = toward.to_oklch()[0]
    var lightness = at[0] + step if target > at[0] else at[0] - step
    return Color.oklch(lightness, at[1], at[2]).with_alpha(base.a)


def _layer_opacity(base: Color, layer: Color, step: Float64) -> Float64:
    """The opacity at which `layer`, drawn over `base`, moves its OKLCH
    lightness by `step`: for a widget with no fill of its own, such as an
    outlined button, whose state is a translucent layer over the surface."""
    var start = base.to_oklch()[0]
    var reach = abs(layer.to_oklch()[0] - start)
    if reach <= step:
        return 1.0
    var low = 0.0
    var high = 1.0
    for _ in range(16):
        var middle = (low + high) / 2
        if abs(base.lerp(layer, middle).to_oklch()[0] - start) >= step:
            high = middle
        else:
            low = middle
    return high


def _clamp01(t: Float64) -> Float64:
    return 0.0 if t < 0 else (1.0 if t > 1 else t)


def _faded(color: Color, opacity: Float64) -> Color:
    """`color` at `opacity` of its own alpha."""
    return color.with_alpha(UInt8(Float64(color.a) * opacity + 0.5))


struct DisabledGuard[origin: Origin[mut=True]](Movable):
    """Ends the `ui.disabled` block it was made for, on scope exit. Only
    `ui.disabled` builds one."""

    var _ui: Pointer[UI, Self.origin]
    var _active: Bool

    def __init__(out self, *, ref[Self.origin] _ui: UI, _active: Bool):
        if _active:
            _ui._disabled_depth += 1
        self._ui = Pointer(to=_ui)
        self._active = _active

    def __enter__(mut self):
        pass

    def __exit__(mut self):
        if self._active:
            self._ui[]._disabled_depth -= 1


def _content_on(colors: ColorScheme, color: Color) -> Color:
    """The colour for text on `color`: its `on_` partner when it is one of
    the scheme's roles, otherwise black or white, whichever reads better."""
    if color == colors.primary:
        return colors.on_primary
    if color == colors.primary_container:
        return colors.on_primary_container
    if color == colors.secondary:
        return colors.on_secondary
    if color == colors.secondary_container:
        return colors.on_secondary_container
    if color == colors.tertiary:
        return colors.on_tertiary
    if color == colors.tertiary_container:
        return colors.on_tertiary_container
    if color == colors.error:
        return colors.on_error
    if color == colors.error_container:
        return colors.on_error_container
    if color == colors.background:
        return colors.on_background
    if (
        color == colors.surface
        or color == colors.surface_dim
        or color == colors.surface_bright
        or color == colors.surface_container_lowest
        or color == colors.surface_container_low
        or color == colors.surface_container
        or color == colors.surface_container_high
        or color == colors.surface_container_highest
    ):
        return colors.on_surface
    return _readable_on(color)


struct ThemeGuard[origin: Origin[mut=True]](Movable):
    """Ends the `ui.theme` block it was made for, on scope exit. Only
    `ui.theme` builds one."""

    var _ui: Pointer[UI, Self.origin]

    def __init__(out self, *, ref[Self.origin] _ui: UI, _theme: Theme):
        _ui._themes.append(_theme)
        self._ui = Pointer(to=_ui)

    def __enter__(mut self):
        pass

    def __exit__(mut self):
        _ = self._ui[]._themes.pop()


struct WidgetStyleGuard[origin: Origin[mut=True]](Movable):
    """Ends the `ui.style` block it was made for, on scope exit. Only
    `ui.style` builds one."""

    var _ui: Pointer[UI, Self.origin]

    def __init__(out self, *, ref[Self.origin] _ui: UI, _styles: _Styles):
        _ui._styles.append(_styles._over(_ui._current_styles()))
        self._ui = Pointer(to=_ui)

    def __enter__(mut self):
        pass

    def __exit__(mut self):
        _ = self._ui[]._styles.pop()


struct PanelGuard[origin: Origin[mut=True]](Movable):
    """Ends the `ui.panel` block it was made for, on scope exit. Only
    `ui.panel` builds one."""

    var _ui: Pointer[UI, Self.origin]

    def __init__(out self, *, ref[Self.origin] _ui: UI, _content: Color):
        _ui._contents.append(_content)
        self._ui = Pointer(to=_ui)

    def __enter__(mut self):
        pass

    def __exit__(mut self):
        _ = self._ui[]._contents.pop()
