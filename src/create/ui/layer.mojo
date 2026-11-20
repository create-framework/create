"""`UILayer`: the handle a `ui.screen` block draws widgets with."""

from std.reflection import SourceLocation, call_location

from create.color import Color
from create.core import Context
from create.geometry import Drawable, Rectangle
from create.image import Image
from create.math import Point, Transform, Vector
from create.render import Align, Canvas, Style
from ._id import _mix
from ._key import _WidgetKey
from .button import ButtonStyle, ButtonVariant
from .label import LabelStyle
from .theme import Theme, TypeStyle, _contrast
from .ui import UI, _Hit


comptime _PRESSED_SHADOW = Color(0, 0, 0, 45)
"""The inset shadow a pressed filled or tonal button is drawn with."""

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
    var _to_local: Transform
    """Takes a screen point into the layer's space."""

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
        self._to_local = Transform()

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

    # ------------------------------------------------------------ widgets

    @always_inline
    def button(
        self,
        text: String,
        rect: Rectangle,
        *,
        variant: ButtonVariant = ButtonVariant.FILLED,
        style: ButtonStyle = ButtonStyle(),
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

    # ----------------------------------------------------------- internals

    def _button(
        self,
        id: UInt64,
        text: String,
        rect: Rectangle,
        variant: ButtonVariant,
        style: ButtonStyle,
    ) raises -> Bool:
        var state = self._interact(id, rect)
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

    def _interact(self, id: UInt64, rect: Rectangle) -> _Interaction:
        """Record that the widget `id` can be pointed at in `rect`, and work
        out what the pointer did to it."""
        ref ui = self._ui[]
        ref mouse = self._context[].mouse
        ui._hits.append(_Hit(id, rect, self._to_local))
        var hovered = Bool(ui._hot) and ui._hot.value() == id
        if hovered and mouse.pressed():
            ui._held = id
        var held = Bool(ui._held) and ui._held.value() == id
        var clicked = False
        if held and mouse.released():
            clicked = hovered
            ui._held = None
        return _Interaction(hovered, held and hovered and not clicked, clicked)

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
