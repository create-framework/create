"""`UILayer`: the handle a `ui.screen` block draws widgets with."""

from std.reflection import SourceLocation, call_location

from create.color import Color
from create.core import Context
from create.geometry import Circle, Drawable, Line, Rectangle
from create.image import Image
from create.math import Point, Transform, Vector
from create.math._optional_float64 import _OptionalFloat64
from create.render import Align, Canvas, StrokeCap, Style
from create.render.canvas import _View, _ViewGuard
from ._id import _mix
from ._key import _WidgetKey
from .button import ButtonStyle, ButtonVariant
from .checkbox import CheckboxStyle
from .label import LabelStyle
from .slider import SliderStyle
from .theme import Theme, TypeStyle, _contrast, _readable_on
from .ui import UI, _Hit


comptime _PRESSED_SHADOW = Color(0, 0, 0, 45)
"""The inset shadow a pressed filled or tonal button is drawn with."""

comptime _HANDLE_SHADOW = Color(0, 0, 0, 70)
"""The shadow a slider's handle casts with `handle_shadow=True`."""

comptime _HOVERED_CONTRAST = 1.4
comptime _PRESSED_CONTRAST = 1.8
"""The least contrast a hovered or pressed widget has with itself at rest.
A dark tint on a light colour changes it less visibly than a light tint on a
dark one, so where the theme's opacity falls short of these, the state layer
is drawn stronger, and every widget shows its state about as clearly."""


@fieldwise_init
struct _Interaction(Copyable, ImplicitlyCopyable, Movable):
    """What the pointer did to a widget this frame."""

    var hovered: Bool
    var pressed: Bool
    """Held down with the pointer still over it: drawn pressed."""
    var clicked: Bool
    """Released over it, after being pressed on it."""
    var focused: Bool


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
        ref theme = self._ui[]._theme
        var type = style.text_style.or_else(theme.typography.body)
        self._ui[]._recorder.text(
            text,
            _anchor(rect, alignment),
            _text_style(
                type, style.color.or_else(theme.colors.on_surface), alignment
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

    # ----------------------------------------------------------- internals

    def _button(
        self,
        id: UInt64,
        text: String,
        rect: Rectangle,
        variant: ButtonVariant,
        style: ButtonStyle,
        take_focus: Bool,
        disabled: Bool,
    ) raises -> Bool:
        var off = self._disabled(disabled)
        var state = self._interact(id, rect, off, take_focus)
        ref theme = self._ui[]._theme
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
            var states = theme.state_opacities
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
        if container.a > 0 or outline:
            recorder.style = Style(
                fill=container,
                fill_enabled=container.a > 0,
                stroke=outline.or_else(Color.TRANSPARENT),
                stroke_thickness=thickness,
                stroke_enabled=Bool(outline),
            )
            recorder.draw(shape)
        var layer_opacity = 0.0
        # what the state layer is drawn over: the fill, or the surface
        # showing through a button without one
        var base = container if container.a > 0 else colors.surface
        if state.pressed:
            layer_opacity = _state_opacity(
                base, content, theme.state_opacities.pressed, _PRESSED_CONTRAST
            )
        elif state.hovered:
            layer_opacity = _state_opacity(
                base, content, theme.state_opacities.hovered, _HOVERED_CONTRAST
            )
        if layer_opacity > 0:
            recorder.style = Style(
                fill=content.with_alpha(UInt8(layer_opacity * 255 + 0.5)),
                stroke_enabled=False,
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
        recorder.text(
            text,
            rect.position,
            _text_style(
                style.text_style.or_else(theme.typography.label),
                content,
                Align.CENTER,
            ),
        )
        return state.clicked

    def _slider(
        self,
        id: UInt64,
        mut value: Float64,
        min: Float64,
        max: Float64,
        rect: Rectangle,
        step: Optional[Float64],
        style: SliderStyle,
        take_focus: Bool,
        disabled: Bool,
    ) raises -> Bool:
        var off = self._disabled(disabled)
        var state = self._interact(id, rect, off, take_focus)
        ref ui = self._ui[]
        ref theme = ui._theme
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
            var states = theme.state_opacities
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
            shown = handle.lerp(
                tint,
                _state_opacity(
                    handle,
                    tint,
                    theme.state_opacities.dragged,
                    _PRESSED_CONTRAST,
                ),
            )
        elif state.hovered:
            shown = handle.lerp(
                tint,
                _state_opacity(
                    handle,
                    tint,
                    theme.state_opacities.hovered,
                    _HOVERED_CONTRAST,
                ),
            )
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
        recorder.draw(Circle(Point(handle_x, y), handle_radius))
        return changed

    def _checkbox(
        self,
        id: UInt64,
        label: String,
        mut checked: Bool,
        rect: Rectangle,
        style: CheckboxStyle,
        take_focus: Bool,
        disabled: Bool,
    ) raises -> Bool:
        var off = self._disabled(disabled)
        var state = self._interact(id, rect, off, take_focus)
        if state.clicked:
            checked = not checked
        ref theme = self._ui[]._theme
        ref colors = theme.colors
        comptime size = 18.0
        var left = rect.position.x - rect.width / 2
        var centre = Point(left + 20, rect.position.y)
        var box = Rectangle(
            centre, size, size, corner_radius=theme.corner_radii.small / 2
        )
        ref recorder = self._ui[]._recorder
        var accent = style.box_color.or_else(colors.primary)
        var check = style.check_color.or_else(colors.on_primary)
        var outline = style.outline_color.or_else(colors.on_surface_variant)
        var label_color = style.label_color.or_else(colors.on_surface)
        if off:
            var faded = _faded(
                colors.on_surface, theme.state_opacities.disabled_content
            )
            accent = faded
            check = colors.surface
            outline = faded
            label_color = faded
        # a hovered or pressed box is tinted, as a button is: a ticked one
        # towards its tick, an empty one with the text colour inside it
        var opacity = 0.0
        var least_contrast = 1.0
        if state.pressed:
            opacity = theme.state_opacities.pressed
            least_contrast = _PRESSED_CONTRAST
        elif state.hovered:
            opacity = theme.state_opacities.hovered
            least_contrast = _HOVERED_CONTRAST
        if checked:
            var fill = accent
            if opacity > 0:
                fill = accent.lerp(
                    check,
                    _state_opacity(accent, check, opacity, least_contrast),
                )
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
            if opacity > 0:
                layer = _state_opacity(
                    colors.surface, colors.on_surface, opacity, least_contrast
                )
            recorder.style = Style(
                fill=colors.on_surface.with_alpha(UInt8(layer * 255 + 0.5)),
                fill_enabled=layer > 0,
                stroke=outline,
                stroke_thickness=2,
            )
            recorder.draw(box)
        var text_left = Point(left + 40, rect.position.y)
        recorder.text(
            label,
            text_left,
            _text_style(
                style.text_style.or_else(theme.typography.body),
                label_color,
                Align.LEFT,
            ),
        )
        return state.clicked

    def _interact(
        self, id: UInt64, rect: Rectangle, disabled: Bool, take_focus: Bool
    ) -> _Interaction:
        """Record that the widget `id` can be pointed at in `rect`, and work
        out what the pointer did to it. A disabled widget still covers what
        is beneath it, but nothing it does counts."""
        ref ui = self._ui[]
        ref mouse = self._context[].mouse
        ui._hits.append(_Hit(id, rect, self._to_local))
        if disabled:
            if ui._held and ui._held.value() == id:
                ui._held = None  # disabled while held: let go of it
            if ui._focused and ui._focused.value() == id:
                ui._clear_focus()  # a disabled widget can't keep focus
            if ui._hot and ui._hot.value() == id and mouse.pressed():
                ui._clear_focus()  # a click on it is a click on no widget
            return _Interaction(False, False, False, False)
        if take_focus:
            ui._focus(id, visible=True)
        # while another widget is held, this one doesn't react to the pointer
        var free = not ui._held or ui._held.value() == id
        var hovered = Bool(ui._hot) and ui._hot.value() == id and free
        if hovered and mouse.pressed():
            ui._held = id
            ui._focus(id, visible=False)
        var held = Bool(ui._held) and ui._held.value() == id
        var clicked = False
        if held and mouse.released():
            clicked = hovered
            ui._held = None
        return _Interaction(
            hovered,
            held and hovered and not clicked,
            clicked,
            Bool(ui._focused) and ui._focused.value() == id,
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


def _state_opacity(
    base: Color, content: Color, opacity: Float64, least_contrast: Float64
) -> Float64:
    """The opacity to draw a state layer of `content` over `base` at: the
    theme's `opacity`, raised until the result contrasts with `base` by at
    least `least_contrast`, and to no more than 0.5."""
    if _contrast(base, base.lerp(content, opacity)) >= least_contrast:
        return opacity
    var low = opacity
    var high = 0.5
    if _contrast(base, base.lerp(content, high)) < least_contrast:
        return high
    for _ in range(12):
        var middle = (low + high) / 2
        if _contrast(base, base.lerp(content, middle)) >= least_contrast:
            high = middle
        else:
            low = middle
    return high


def _clamp01(t: Float64) -> Float64:
    return 0.0 if t < 0 else (1.0 if t > 1 else t)


def _faded(color: Color, opacity: Float64) -> Color:
    return color.with_alpha(UInt8(opacity * 255 + 0.5))


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
