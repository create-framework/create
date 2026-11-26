"""Internal: `_Theme`, everything that decides how a widget looks, and the
looks it resolves for each kind of widget.

A widget's look depends on the colours, the `ui.style` styles, the settings
and the surface it sits on, and on its state: hovered, pressed, dragged,
focused or disabled. `_Theme` holds the first four as one value, and each of
its widget methods turns a widget's own styles and state into the resolved
styles its parts are drawn in. So a look needs no `UI` to be worked out: a
`UI` builds its theme with `UI._theme()`, and a widget on its own draws in
`_Theme.default()`.
"""

from std.memory import ArcPointer

from create.color import Color
from create.math import Vector, clamp
from create.text import FontWeight
from create.render import Align, StrokeAlign, StrokeCap, StrokeDash, Style
from create.render.style import _ResolvedStyle
from .button_variant import ButtonVariant
from .color_scheme import ColorScheme, _readable_on
from .focus_ring import FocusRing
from .state_layers import StateLayers


comptime _CORNER_RADIUS = 16.0
"""The `corner_radius` setting unless set, at which a button is a pill."""

comptime _SPACING = 8.0
"""The `spacing` setting unless set."""

comptime _CONTROL_HEIGHT = 40.0
"""The `control_height` setting unless set."""

comptime _PRESSED_SHADOW = Color(0, 0, 0, 45)
"""The inset shadow a pressed filled or tonal button is drawn with."""


@fieldwise_init
struct _Styles(Copyable, ImplicitlyCopyable, Movable):
    """What `ui.style` sets for every widget of a kind: each widget's own style
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
    var checkbox_label_style: Style
    var text_field_container: Style
    var text_field_focused: Style
    var text_field_text_style: Style
    var text_field_placeholder_style: Style
    var text_field_caret: Style
    var text_field_selection: Style
    var scroll_area_track: Style
    var scroll_area_thumb: Style
    var progress_bar_track: Style
    var progress_bar_indicator: Style
    var switch_track: Style
    var switch_on_track: Style
    var switch_handle: Style
    var switch_text_style: Style
    var choice_group_circle: Style
    var choice_group_selected_circle: Style
    var choice_group_dot: Style
    var choice_group_text_style: Style
    var tabs_tab: Style
    var tabs_selected_tab: Style
    var tabs_indicator: Style
    var number_field_container: Style
    var number_field_text_style: Style
    var number_field_buttons: Style

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
        self.checkbox_label_style = Style()
        self.text_field_container = Style()
        self.text_field_focused = Style()
        self.text_field_text_style = Style()
        self.text_field_placeholder_style = Style()
        self.text_field_caret = Style()
        self.text_field_selection = Style()
        self.scroll_area_track = Style()
        self.scroll_area_thumb = Style()
        self.progress_bar_track = Style()
        self.progress_bar_indicator = Style()
        self.switch_track = Style()
        self.switch_on_track = Style()
        self.switch_handle = Style()
        self.switch_text_style = Style()
        self.choice_group_circle = Style()
        self.choice_group_selected_circle = Style()
        self.choice_group_dot = Style()
        self.choice_group_text_style = Style()
        self.tabs_tab = Style()
        self.tabs_selected_tab = Style()
        self.tabs_indicator = Style()
        self.number_field_container = Style()
        self.number_field_text_style = Style()
        self.number_field_buttons = Style()

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
            self.checkbox_label_style.over(under.checkbox_label_style),
            self.text_field_container.over(under.text_field_container),
            self.text_field_focused.over(under.text_field_focused),
            self.text_field_text_style.over(under.text_field_text_style),
            self.text_field_placeholder_style.over(
                under.text_field_placeholder_style
            ),
            self.text_field_caret.over(under.text_field_caret),
            self.text_field_selection.over(under.text_field_selection),
            self.scroll_area_track.over(under.scroll_area_track),
            self.scroll_area_thumb.over(under.scroll_area_thumb),
            self.progress_bar_track.over(under.progress_bar_track),
            self.progress_bar_indicator.over(under.progress_bar_indicator),
            self.switch_track.over(under.switch_track),
            self.switch_on_track.over(under.switch_on_track),
            self.switch_handle.over(under.switch_handle),
            self.switch_text_style.over(under.switch_text_style),
            self.choice_group_circle.over(under.choice_group_circle),
            self.choice_group_selected_circle.over(
                under.choice_group_selected_circle
            ),
            self.choice_group_dot.over(under.choice_group_dot),
            self.choice_group_text_style.over(under.choice_group_text_style),
            self.tabs_tab.over(under.tabs_tab),
            self.tabs_selected_tab.over(under.tabs_selected_tab),
            self.tabs_indicator.over(under.tabs_indicator),
            self.number_field_container.over(under.number_field_container),
            self.number_field_text_style.over(under.number_field_text_style),
            self.number_field_buttons.over(under.number_field_buttons),
        )


@fieldwise_init
struct _ButtonLook(Copyable, Movable):
    """A button's parts, resolved for its state."""

    var body: Optional[_ResolvedStyle]
    """Its shape's style, or `None` when it paints neither fill nor
    stroke."""
    var layer: Optional[_ResolvedStyle]
    """A translucent layer over its shape, for a hovered or pressed button
    with no solid fill to step."""
    var text: _ResolvedStyle
    """Its text's style, centred."""
    var corner_radius: Float64
    """Its shape's corner radius."""


@fieldwise_init
struct _PanelLook(Copyable, Movable):
    """A panel's style, and what the widgets on it sit on."""

    var style: _ResolvedStyle
    var surface: Color
    """The colour the widgets on it sit on: its fill, or what is beneath a
    panel with none."""
    var content: Color
    """The colour for text on it."""


@fieldwise_init
struct _SliderLook(Copyable, Movable):
    """A slider's parts, resolved for its state. The handle is a point: a
    zero-length line whose stroke thickness is its diameter."""

    var track: _ResolvedStyle
    var active: _ResolvedStyle
    var handle: _ResolvedStyle
    var outline: _ResolvedStyle


@fieldwise_init
struct _ProgressBarLook(Copyable, Movable):
    """A progress bar's parts, resolved: two lines."""

    var track: _ResolvedStyle
    var indicator: _ResolvedStyle


@fieldwise_init
struct _SwitchLook(Copyable, Movable):
    """A switch's parts, resolved for its state. The handle is a point."""

    var track: _ResolvedStyle
    var handle: _ResolvedStyle
    var text: _ResolvedStyle
    """Its text's style, aligned left."""


@fieldwise_init
struct _ChoiceGroupLook(Copyable, Movable):
    """A choice group's parts, resolved for its state. The dot is a point,
    and the halo is drawn behind the option under the pointer."""

    var circle: _ResolvedStyle
    var selected_circle: _ResolvedStyle
    var dot: _ResolvedStyle
    var text: _ResolvedStyle
    """Its options' style, aligned left."""
    var halo: _ResolvedStyle


@fieldwise_init
struct _TabsLook(Copyable, Movable):
    """Tabs' parts, resolved for their state: each tab's shape and its
    text, the selected one's, the indicator beneath it, and the layer over
    the tab under the pointer."""

    var tab: _ResolvedStyle
    var selected_tab: _ResolvedStyle
    var text: _ResolvedStyle
    var selected_text: _ResolvedStyle
    var indicator: _ResolvedStyle
    var layer: _ResolvedStyle


@fieldwise_init
struct _ScrollAreaLook(Copyable, Movable):
    """A scroll area's bar, resolved for its state: two lines."""

    var track: _ResolvedStyle
    var thumb: _ResolvedStyle


@fieldwise_init
struct _CheckboxLook(Copyable, Movable):
    """A checkbox's parts, resolved for its state."""

    var box: _ResolvedStyle
    var tick: _ResolvedStyle
    var text: _ResolvedStyle
    """Its label's style, aligned left."""


@fieldwise_init
struct _TextFieldLook(Copyable, Movable):
    """A text field's parts, resolved for its state."""

    var container: _ResolvedStyle
    var typed: _ResolvedStyle
    """The typed text's style."""
    var hint: _ResolvedStyle
    """The placeholder's style."""
    var selection: _ResolvedStyle
    var caret: _ResolvedStyle


@fieldwise_init
struct _Theme(Copyable, Movable):
    """Everything that decides how a widget looks but its own style and
    state: the colours, the `ui.style` styles, the settings, and the
    surface it sits on with the colour for text there."""

    var colors: ColorScheme
    var styles: ArcPointer[_Styles]
    """What `ui.style` sets, shared rather than copied: the styles are
    large, and a theme is copied for every panel and widget a `UI`
    updates."""
    var corner_radius: Float64
    var spacing: Float64
    var control_height: Float64
    var state_layers: StateLayers
    var focus_ring: FocusRing
    var surface: Color
    """What the widgets sit on: the innermost panel's fill, or the colours'
    `surface`."""
    var content: Color
    """The colour for text here: the innermost panel's, or the colours'
    `on_surface`."""

    @staticmethod
    def default(colors: ColorScheme = ColorScheme.light()) -> Self:
        """`colors`, the light ones unless given, and the settings'
        defaults, outside any panel: what a widget is drawn in on its own.
        """
        return Self(
            colors=colors,
            styles=ArcPointer(_Styles()),
            corner_radius=_CORNER_RADIUS,
            spacing=_SPACING,
            control_height=_CONTROL_HEIGHT,
            state_layers=StateLayers(),
            focus_ring=FocusRing(),
            surface=colors.surface,
            content=colors.on_surface,
        )

    def _step(self, hovered: Bool, pressed: Bool) -> Float64:
        """How far a hovered or pressed widget's lightness steps: 0 when
        neither."""
        if pressed:
            return self.state_layers.pressed
        if hovered:
            return self.state_layers.hovered
        return 0.0

    def button(
        self,
        call: Style,
        variant: ButtonVariant,
        height: Float64,
        *,
        hovered: Bool,
        pressed: Bool,
        disabled: Bool,
    ) -> _ButtonLook:
        """A button `height` tall, styled `call`, in its state."""
        var colors = self.colors
        var look = call.over(self.styles[].button).over(
            _variant_look(variant, colors).over(_label_text())
        )
        var resolved = _ResolvedStyle()
        resolved.apply(look)
        if disabled:
            # Material's disabled look: everything in the text colour,
            # faded, whatever the variant
            var states = self.state_layers
            resolved.text_color = _faded(
                colors.on_surface, states.disabled_content
            )
            if _fills(resolved):
                resolved.fill_color = _faded(
                    colors.on_surface, states.disabled_container
                )
                resolved.fill_gradient = None
            if resolved.stroke_enabled:
                resolved.stroke_color = _faded(
                    colors.on_surface, states.disabled_container
                )
        # a pill at the default corner radius, squaring as it shrinks
        var roundness = clamp(self.corner_radius / _CORNER_RADIUS, 0.0, 1.0)
        var radius = look.corner_radius.or_else(roundness * height / 2)
        # a hovered or pressed button steps its fill's lightness towards its
        # text
        var step = self._step(hovered, pressed)
        var solid = _fills(resolved) and not resolved.fill_gradient
        if step > 0 and solid:
            resolved.fill_color = _stepped(
                resolved.fill_color, resolved.text_color, step
            )
        var body: Optional[_ResolvedStyle] = None
        if _fills(resolved) or resolved.stroke_enabled:
            var shape = resolved
            if pressed and _fills(resolved):
                # pressed in: a soft shadow along the inside of the top edge
                shape.shadow_color = _PRESSED_SHADOW
                shape.shadow_offset = Vector(0, -2)
                shape.shadow_blur = 4
                shape.shadow_spread = 0
                shape.shadow_inset = True
                shape.shadow_enabled = True
            body = shape
        var layer: Optional[_ResolvedStyle] = None
        if step > 0 and not solid:
            # no solid fill to step: a layer of the text colour, as strong as
            # the step would be over the surface beneath
            var opacity = _layer_opacity(
                self.surface, resolved.text_color, step
            )
            layer = _ResolvedStyle(
                fill=resolved.text_color.with_alpha(UInt8(opacity * 255 + 0.5)),
                stroke_enabled=False,
            )
        return _ButtonLook(
            body, layer, _text_look(resolved, Align.CENTER), radius
        )

    def panel(self, call: Style) -> _PanelLook:
        """A panel styled `call`."""
        var look = call.over(self.styles[].panel).over(
            Style(
                fill=self.colors.surface_container,
                stroke_enabled=False,
                corner_radius=self.corner_radius,
            )
        )
        var resolved = _ResolvedStyle()
        resolved.apply(look)
        # a panel with no fill shows what is beneath it
        var surface = (
            resolved.fill_color if resolved.fill_enabled else self.surface
        )
        var content = look.text_color.or_else(_content_on(self.colors, surface))
        return _PanelLook(resolved, surface, content)

    def label(
        self, call: Style, alignment: Optional[Align], *, disabled: Bool
    ) -> _ResolvedStyle:
        """A label's text styled `call`, aligned by `alignment`, else by its
        style's `text_alignment`, else centred."""
        var look = call.over(self.styles[].label).over(
            Style(text_color=self.content).over(_body_text())
        )
        var resolved = _ResolvedStyle()
        resolved.apply(look)
        resolved.text_alignment = alignment.or_else(
            look.text_alignment.or_else(Align.CENTER)
        )
        if disabled:
            resolved.text_color = _faded(
                resolved.text_color, self.state_layers.disabled_content
            )
        return resolved

    def slider(
        self,
        call_track: Style,
        call_active_track: Style,
        call_handle: Style,
        call_handle_outline: Style,
        *,
        hovered: Bool,
        dragging: Bool,
        disabled: Bool,
    ) -> _SliderLook:
        """A slider's parts, styled by the call's styles for each."""
        var colors = self.colors
        ref block = self.styles[]
        var track_look = call_track.over(block.slider_track).over(
            Style(
                stroke=colors.secondary_container,
                stroke_thickness=4,
                stroke_cap=StrokeCap.ROUND,
            )
        )
        var track = _ResolvedStyle()
        track.apply(track_look)
        var active = _ResolvedStyle()
        active.apply(
            call_active_track.over(block.slider_active_track).over(
                Style(stroke=colors.primary).over(track_look)
            )
        )
        var handle = _ResolvedStyle()
        handle.apply(
            call_handle.over(block.slider_handle).over(
                Style(stroke=colors.primary, stroke_thickness=20)
            )
        )
        var outline = _ResolvedStyle()
        outline.apply(
            call_handle_outline.over(block.slider_handle_outline).over(
                Style(fill_enabled=False, stroke_enabled=False)
            )
        )
        if disabled:
            var states = self.state_layers
            active.stroke_color = _faded(
                colors.on_surface, states.disabled_content
            )
            track.stroke_color = _faded(
                colors.on_surface, states.disabled_container
            )
            # solid, so the track doesn't show through it
            handle.stroke_color = self.surface.lerp(
                colors.on_surface, states.disabled_content
            )
        # a hovered or dragged handle is tinted, as a button is
        var tint = _readable_on(handle.stroke_color)
        if dragging:
            handle.stroke_color = _stepped(
                handle.stroke_color, tint, self.state_layers.dragged
            )
        elif hovered:
            handle.stroke_color = _stepped(
                handle.stroke_color, tint, self.state_layers.hovered
            )
        # a point, as `canvas.point` draws one: round unless square, and
        # never dashed
        if handle.stroke_cap != StrokeCap.SQUARE:
            handle.stroke_cap = StrokeCap.ROUND
        handle.stroke_dash = StrokeDash.SOLID
        return _SliderLook(track, active, handle, outline)

    def progress_bar(
        self, call_track: Style, call_indicator: Style, *, disabled: Bool
    ) -> _ProgressBarLook:
        """A progress bar's parts, styled by the call's styles for each: a
        slider's track, and its active track as the indicator."""
        var colors = self.colors
        ref block = self.styles[]
        var track_look = call_track.over(block.progress_bar_track).over(
            Style(
                stroke=colors.secondary_container,
                stroke_thickness=8,
                stroke_cap=StrokeCap.ROUND,
            )
        )
        var track = _ResolvedStyle()
        track.apply(track_look)
        var indicator = _ResolvedStyle()
        indicator.apply(
            call_indicator.over(block.progress_bar_indicator).over(
                Style(stroke=colors.primary).over(track_look)
            )
        )
        if disabled:
            var states = self.state_layers
            indicator.stroke_color = _faded(
                colors.on_surface, states.disabled_content
            )
            track.stroke_color = _faded(
                colors.on_surface, states.disabled_container
            )
        return _ProgressBarLook(track, indicator)

    def switch(
        self,
        call_track: Style,
        call_on_track: Style,
        call_handle: Style,
        call_text: Style,
        *,
        on: Bool,
        hovered: Bool,
        pressed: Bool,
        disabled: Bool,
    ) -> _SwitchLook:
        """A switch's parts, styled by the call's styles for each: while
        off, an outlined track with a small handle in the outline's colour;
        while on, a filled track with a larger handle on it."""
        var colors = self.colors
        ref block = self.styles[]
        var track_look = call_track.over(block.switch_track).over(
            Style(
                fill=colors.surface_container_highest,
                stroke=colors.outline,
                stroke_thickness=2,
            )
        )
        var track = _ResolvedStyle()
        if on:
            track.apply(
                call_on_track.over(block.switch_on_track).over(
                    Style(fill=colors.primary, stroke_enabled=False).over(
                        track_look
                    )
                )
            )
        else:
            track.apply(track_look)
        var handle = _ResolvedStyle()
        handle.apply(
            call_handle.over(block.switch_handle).over(
                Style(
                    stroke=colors.on_primary if on else colors.outline,
                    stroke_thickness=18 if on else 14,
                )
            )
        )
        var text = _ResolvedStyle()
        text.apply(
            call_text.over(block.switch_text_style).over(
                Style(text_color=self.content).over(_body_text())
            )
        )
        if disabled:
            var states = self.state_layers
            var faded = _faded(colors.on_surface, states.disabled_content)
            track.fill_color = _faded(
                colors.on_surface, states.disabled_container
            )
            track.fill_gradient = None
            track.stroke_color = faded
            handle.stroke_color = self.surface if on else faded
            text.text_color = faded
        else:
            # a hovered or pressed handle is tinted, as a slider's is
            var step = self._step(hovered, pressed)
            if step > 0:
                handle.stroke_color = _stepped(
                    handle.stroke_color,
                    _readable_on(handle.stroke_color),
                    step,
                )
        # a point, as `canvas.point` draws one: round unless square
        if handle.stroke_cap != StrokeCap.SQUARE:
            handle.stroke_cap = StrokeCap.ROUND
        handle.stroke_dash = StrokeDash.SOLID
        return _SwitchLook(track, handle, _text_look(text, Align.LEFT))

    def choice_group(
        self,
        call_circle: Style,
        call_selected_circle: Style,
        call_dot: Style,
        call_text: Style,
        *,
        hovered: Bool,
        pressed: Bool,
        disabled: Bool,
    ) -> _ChoiceGroupLook:
        """A choice group's parts, styled by the call's styles for each:
        outlined circles, the chosen one in `primary` with a dot, and a
        halo behind the option under the pointer, as deep as a checkbox's
        state layer."""
        var colors = self.colors
        ref block = self.styles[]
        var circle_look = call_circle.over(block.choice_group_circle).over(
            Style(
                fill_enabled=False,
                stroke=colors.on_surface_variant,
                stroke_thickness=2,
            )
        )
        var circle = _ResolvedStyle()
        circle.apply(circle_look)
        var selected = _ResolvedStyle()
        selected.apply(
            call_selected_circle.over(block.choice_group_selected_circle).over(
                Style(stroke=colors.primary).over(circle_look)
            )
        )
        var dot = _ResolvedStyle()
        dot.apply(
            call_dot.over(block.choice_group_dot).over(
                Style(stroke=colors.primary, stroke_thickness=10)
            )
        )
        var text = _ResolvedStyle()
        text.apply(
            call_text.over(block.choice_group_text_style).over(
                Style(text_color=self.content).over(_body_text())
            )
        )
        var halo = _ResolvedStyle(fill=Color(0, 0, 0, 0), stroke_enabled=False)
        if disabled:
            var faded = _faded(
                colors.on_surface, self.state_layers.disabled_content
            )
            circle.stroke_color = faded
            selected.stroke_color = faded
            dot.stroke_color = faded
            text.text_color = faded
        else:
            var step = self._step(hovered, pressed)
            if step > 0:
                var layer = _layer_opacity(
                    self.surface, colors.on_surface, step
                )
                halo.fill_color = colors.on_surface.with_alpha(
                    UInt8(layer * 255 + 0.5)
                )
        # a point, as `canvas.point` draws one: round unless square
        if dot.stroke_cap != StrokeCap.SQUARE:
            dot.stroke_cap = StrokeCap.ROUND
        dot.stroke_dash = StrokeDash.SOLID
        return _ChoiceGroupLook(
            circle, selected, dot, _text_look(text, Align.LEFT), halo
        )

    def tabs(
        self,
        call_tab: Style,
        call_selected_tab: Style,
        call_indicator: Style,
        *,
        hovered: Bool,
        pressed: Bool,
        disabled: Bool,
    ) -> _TabsLook:
        """Tabs' parts, styled by the call's styles for each: bare tabs with
        their text in `on_surface_variant`, the selected one's in `primary`
        with a `primary` line beneath it, and a state layer over the tab
        under the pointer."""
        var colors = self.colors
        ref block = self.styles[]
        var tab_look = call_tab.over(block.tabs_tab).over(
            Style(
                fill_enabled=False,
                stroke_enabled=False,
                text_color=colors.on_surface_variant,
            ).over(_label_text())
        )
        var tab = _ResolvedStyle()
        tab.apply(tab_look)
        var selected = _ResolvedStyle()
        selected.apply(
            call_selected_tab.over(block.tabs_selected_tab).over(
                Style(text_color=colors.primary).over(tab_look)
            )
        )
        var indicator = _ResolvedStyle()
        indicator.apply(
            call_indicator.over(block.tabs_indicator).over(
                Style(stroke=colors.primary, stroke_thickness=3)
            )
        )
        var layer = _ResolvedStyle(fill=Color(0, 0, 0, 0), stroke_enabled=False)
        if disabled:
            var faded = _faded(
                colors.on_surface, self.state_layers.disabled_content
            )
            tab.text_color = faded
            selected.text_color = faded
            indicator.stroke_color = faded
        else:
            var step = self._step(hovered, pressed)
            if step > 0:
                var opacity = _layer_opacity(
                    self.surface, colors.on_surface, step
                )
                layer.fill_color = colors.on_surface.with_alpha(
                    UInt8(opacity * 255 + 0.5)
                )
        return _TabsLook(
            tab,
            selected,
            _text_look(tab, Align.CENTER),
            _text_look(selected, Align.CENTER),
            indicator,
            layer,
        )

    def ring_reach(self) -> Float64:
        """How far the focus ring reaches outside a widget: its gap and its
        thickness. A scroll area leaves this much room round its column, so
        a ring isn't cut at its edges."""
        return self.focus_ring.gap + self.focus_ring.thickness

    def scroll_bar_width(self) -> Float64:
        """How wide a scroll area's bar is: a share of `control_height`, so
        the bar grows with the controls."""
        return 0.3 * self.control_height

    def scroll_area(
        self,
        call_track: Style,
        call_thumb: Style,
        *,
        hovered: Bool,
        dragging: Bool,
        disabled: Bool,
    ) -> _ScrollAreaLook:
        """A scroll area's bar, styled by the call's styles for each part:
        a faint track, which shows on any surface, and a thumb that steps
        when hovered or dragged."""
        var colors = self.colors
        ref block = self.styles[]
        var thickness = self.scroll_bar_width() / 2
        var track = _ResolvedStyle()
        track.apply(
            call_track.over(block.scroll_area_track).over(
                Style(
                    # translucent, so it shows on any surface
                    stroke=_faded(colors.on_surface, 0.12),
                    stroke_thickness=thickness,
                    stroke_cap=StrokeCap.ROUND,
                )
            )
        )
        var thumb = _ResolvedStyle()
        thumb.apply(
            call_thumb.over(block.scroll_area_thumb).over(
                Style(
                    stroke=colors.outline,
                    stroke_thickness=thickness,
                    stroke_cap=StrokeCap.ROUND,
                )
            )
        )
        if disabled:
            var states = self.state_layers
            track.stroke_color = _faded(
                track.stroke_color, states.disabled_container
            )
            thumb.stroke_color = _faded(
                thumb.stroke_color, states.disabled_content
            )
        else:
            var tint = _readable_on(thumb.stroke_color)
            if dragging:
                thumb.stroke_color = _stepped(
                    thumb.stroke_color, tint, self.state_layers.dragged
                )
            elif hovered:
                thumb.stroke_color = _stepped(
                    thumb.stroke_color, tint, self.state_layers.hovered
                )
        return _ScrollAreaLook(track, thumb)

    def checkbox(
        self,
        call_box: Style,
        call_checked_box: Style,
        call_tick: Style,
        call_label: Style,
        *,
        checked: Bool,
        hovered: Bool,
        pressed: Bool,
        disabled: Bool,
    ) -> _CheckboxLook:
        """A checkbox's parts, styled by the call's styles for each."""
        var colors = self.colors
        ref block = self.styles[]
        var box_look = call_box.over(block.checkbox_box).over(
            Style(
                fill_enabled=False,
                stroke=colors.on_surface_variant,
                stroke_thickness=2,
                corner_radius=self.corner_radius / 8,
            )
        )
        var box = _ResolvedStyle()
        if checked:
            box.apply(
                call_checked_box.over(block.checkbox_checked_box).over(
                    Style(fill=colors.primary, stroke_enabled=False).over(
                        box_look
                    )
                )
            )
        else:
            box.apply(box_look)
        var tick = _ResolvedStyle()
        tick.apply(
            call_tick.over(block.checkbox_tick).over(
                Style(
                    stroke=colors.on_primary,
                    stroke_thickness=2,
                    stroke_cap=StrokeCap.ROUND,
                )
            )
        )
        var text = _ResolvedStyle()
        text.apply(
            call_label.over(block.checkbox_label_style).over(
                Style(text_color=self.content).over(_body_text())
            )
        )
        if disabled:
            var faded = _faded(
                colors.on_surface, self.state_layers.disabled_content
            )
            if _fills(box):
                box.fill_color = faded
                box.fill_gradient = None
            box.stroke_color = faded
            tick.stroke_color = self.surface
            text.text_color = faded
        # a hovered or pressed box is tinted, as a button is: a filled one
        # towards its tick, an empty one with the text colour inside it
        var step = self._step(hovered, pressed)
        if step > 0:
            if _fills(box) and not box.fill_gradient:
                box.fill_color = _stepped(
                    box.fill_color, tick.stroke_color, step
                )
            elif not _fills(box):
                var layer = _layer_opacity(
                    self.surface, colors.on_surface, step
                )
                box.fill_color = colors.on_surface.with_alpha(
                    UInt8(layer * 255 + 0.5)
                )
                box.fill_gradient = None
                box.fill_enabled = True
        return _CheckboxLook(box, tick, _text_look(text, Align.LEFT))

    def text_field(
        self,
        call_container: Style,
        call_focused: Style,
        call_text: Style,
        call_placeholder: Style,
        call_caret: Style,
        call_selection: Style,
        *,
        hovered: Bool,
        focused: Bool,
        disabled: Bool,
    ) -> _TextFieldLook:
        """A text field's parts, styled by the call's styles for each."""
        var colors = self.colors
        ref block = self.styles[]
        var text_look = call_text.over(block.text_field_text_style).over(
            Style(text_color=colors.on_surface).over(_body_text())
        )
        var typed = _ResolvedStyle()
        typed.apply(text_look)
        var hint = _ResolvedStyle()
        hint.apply(
            call_placeholder.over(block.text_field_placeholder_style).over(
                Style(text_color=colors.on_surface_variant).over(text_look)
            )
        )
        var container_look = call_container.over(
            block.text_field_container
        ).over(
            Style(
                fill=colors.surface_container_highest,
                stroke=colors.outline,
                stroke_thickness=1,
                corner_radius=self.corner_radius / 4,
            )
        )
        var field = _ResolvedStyle()
        field.apply(container_look)
        if focused and not disabled:
            # by default, the outline turns `primary` and twice as thick,
            # and a field with no outline stays without one
            var outlined = Style()
            if field.stroke_enabled:
                outlined = Style(
                    stroke=colors.primary,
                    stroke_thickness=field.stroke_thickness * 2,
                )
            field = _ResolvedStyle()
            field.apply(
                call_focused.over(block.text_field_focused)
                .over(outlined)
                .over(container_look)
            )
        if disabled:
            var states = self.state_layers
            # the field's own colours, faded: the colours' text colour by
            # default, and a transparent one stays transparent
            typed.text_color = _faded(typed.text_color, states.disabled_content)
            hint.text_color = _faded(hint.text_color, states.disabled_content)
            if _fills(field):
                field.fill_color = _faded(
                    colors.on_surface, states.disabled_container
                )
                field.fill_gradient = None
            field.stroke_color = _faded(
                colors.on_surface, states.disabled_container
            )
        elif (
            hovered
            and not focused
            and _fills(field)
            and not field.fill_gradient
        ):
            field.fill_color = _stepped(
                field.fill_color, colors.on_surface, self.state_layers.hovered
            )
        var selection = _ResolvedStyle()
        selection.apply(
            call_selection.over(block.text_field_selection).over(
                Style(fill=colors.primary.with_alpha(70), stroke_enabled=False)
            )
        )
        var caret = _ResolvedStyle()
        caret.apply(
            call_caret.over(block.text_field_caret).over(
                Style(stroke=colors.primary, stroke_thickness=2)
            )
        )
        return _TextFieldLook(field, typed, hint, selection, caret)

    def ring(self) -> _ResolvedStyle:
        """The focus ring's style: an outline outside the widget's shape."""
        return _ResolvedStyle(
            fill_enabled=False,
            stroke=self.focus_ring.color.or_else(self.colors.secondary),
            stroke_thickness=self.focus_ring.thickness,
            stroke_alignment=StrokeAlign.OUTSIDE,
        )


def _body_text() -> Style:
    """The text of labels, checkboxes and text fields, unless styled."""
    return Style(font_size=16, font_weight=FontWeight.REGULAR)


def _label_text() -> Style:
    """The text on buttons, unless styled."""
    return Style(font_size=14, font_weight=FontWeight.MEDIUM)


def _text_look(style: _ResolvedStyle, alignment: Align) -> _ResolvedStyle:
    """Only the text parts of `style`, placed by `alignment`: the text drawn
    on a widget, which leaves the widget's fill, stroke and shadow to the
    shape beneath it."""
    var look = _ResolvedStyle()
    look.text_color = style.text_color
    look.font = style.font
    look.font_size = style.font_size
    look.font_weight = style.font_weight
    look.font_italic = style.font_italic
    look.tint = style.tint
    look.opacity = style.opacity
    look.blend_mode = style.blend_mode
    look.text_alignment = alignment
    return look^


def _fills(style: _ResolvedStyle) -> Bool:
    """Whether `style` paints a fill that shows: switched on, and either a
    gradient or a colour that isn't transparent."""
    return style.fill_enabled and (
        Bool(style.fill_gradient) or style.fill_color.a > 0
    )


def _variant_look(variant: ButtonVariant, colors: ColorScheme) -> Style:
    """How a button of `variant` looks in `colors`, before its own style:
    the fill behind it, its outline and its text's colour. Each carries the
    outline's colour, so a style that gives only a thickness gets it."""
    if variant == ButtonVariant.TONAL:
        return Style(
            fill=colors.secondary_container,
            stroke=colors.outline,
            stroke_enabled=False,
            text_color=colors.on_secondary_container,
        )
    if variant == ButtonVariant.OUTLINED:
        return Style(
            fill_enabled=False,
            stroke=colors.outline,
            stroke_thickness=1,
            text_color=colors.primary,
        )
    if variant == ButtonVariant.TEXT:
        return Style(
            fill_enabled=False,
            stroke=colors.outline,
            stroke_enabled=False,
            text_color=colors.primary,
        )
    return Style(
        fill=colors.primary,
        stroke=colors.outline,
        stroke_enabled=False,
        text_color=colors.on_primary,
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


def _faded(color: Color, opacity: Float64) -> Color:
    """`color` at `opacity` of its own alpha."""
    return color.with_alpha(UInt8(Float64(color.a) * opacity + 0.5))


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
