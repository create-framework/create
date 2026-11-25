"""The widget tree: widgets kept together, updated and drawn in one call
each, in a shared look, with only the topmost under the pointer reacting
to it.

During the move from the immediate-mode `UI`, the tree is `_Tree`; it
takes the name `UI` once that is gone. Its handles are `WidgetHandle`s.
"""

from std.utils import Variant

from create.color import Color
from create.core import Context
from create.geometry import Rectangle
from create.math import Point
from create.render import Canvas, Drawable, Picture, Style
from .button import Button
from .checkbox import Checkbox
from .colors import ColorScheme, FocusRing, StateLayers
from .label import Label
from .panel import Panel
from .slider import Slider
from .text_field import TextField
from ._theme import (
    _CONTROL_HEIGHT,
    _CORNER_RADIUS,
    _SPACING,
    _Styles,
    _Theme,
)


comptime _Widget = Variant[
    Button, Checkbox, Label, Panel, Slider, TextField, Picture
]
"""The kinds of widget a tree holds. Storage only: what each does is its
own, reached through `_dispatch` and `_dispatch_mut`."""


@fieldwise_init
struct WidgetHandle[W: Copyable](
    Copyable, Equatable, ImplicitlyCopyable, Movable
):
    """Where a widget of type `W` is in a `UI`: what `ui.add` returns, and
    how the program reaches the widget again, as `ui[handle]`."""

    var _index: Int

    def __eq__(self, other: Self) -> Bool:
        return self._index == other._index


@fieldwise_init
struct _Node(Copyable, Movable):
    var widget: _Widget
    var parent: Optional[Int]
    var children: List[Int]


comptime _DRAW = 0
comptime _HIT = 1


struct _Tree(Drawable, Movable):
    """Widgets kept together: added once, then updated and drawn each frame
    in one call each.

    ```mojo
    # In `create`, building the `ui` field and keeping a handle:
    var ui = _Tree()
    var card = ui.add(Panel(Rectangle((0, 0), 320, 200)))
    var play = ui.add(Button("Play", Rectangle((0, -40), 160, 48)), card)

    # In `update`:
    self.ui.update(context, canvas)
    with canvas.overlay():  # on the screen; leave it out to draw in the world
        canvas.draw(self.ui)
    if self.ui[self.play].released():
        self.start()
    ```

    A widget added inside another is drawn after it, so on top of it, and
    takes the look of what it sits on: text on a panel takes the panel's
    content colour. Where widgets overlap, only the topmost under the
    pointer reacts to it, and a `Panel` covers what is beneath it.

    `update` hit-tests through `canvas.to_local`, so call it in the same
    transform and camera the tree is drawn in.
    """

    var _nodes: List[_Node]
    var _roots: List[Int]
    var _colors: ColorScheme
    var _styles: _Styles
    var _corner_radius: Float64
    var _spacing: Float64
    var _control_height: Float64
    var _state_layers: StateLayers
    var _focus_ring: FocusRing

    def __init__(out self):
        self._nodes = []
        self._roots = []
        self._colors = ColorScheme.light()
        self._styles = _Styles()
        self._corner_radius = _CORNER_RADIUS
        self._spacing = _SPACING
        self._control_height = _CONTROL_HEIGHT
        self._state_layers = StateLayers()
        self._focus_ring = FocusRing()

    # ----------------------------------------------------------- building

    def add[W: Copyable](mut self, var widget: W) -> WidgetHandle[W]:
        """Add `widget` at the top level, drawn above everything added
        before it."""
        self._nodes.append(_Node(_Widget(widget^), None, []))
        var index = len(self._nodes) - 1
        self._roots.append(index)
        return WidgetHandle[W](index)

    def add[
        W: Copyable, P: Copyable
    ](mut self, var widget: W, parent: WidgetHandle[P]) -> WidgetHandle[W]:
        """Add `widget` inside `parent`: drawn after it and after what was
        added inside it before, and in the look of what it sits on."""
        self._nodes.append(_Node(_Widget(widget^), parent._index, []))
        var index = len(self._nodes) - 1
        self._nodes[parent._index].children.append(index)
        return WidgetHandle[W](index)

    def __getitem__[
        W: Copyable
    ](ref self, handle: WidgetHandle[W]) -> ref[
        self._nodes[handle._index].widget[W]
    ] W:
        """The widget `handle` names, to read or change."""
        return self._nodes[handle._index].widget[W]

    # ----------------------------------------------------------- the look

    def colors(self) -> ColorScheme:
        """The colours its widgets are drawn in: the light ones unless
        set."""
        return self._colors

    def colors(mut self, colors: ColorScheme):
        self._colors = colors

    def corner_radius(self) -> Float64:
        """How round its widgets are: at the default, 16, a button is a
        pill."""
        return self._corner_radius

    def corner_radius(mut self, radius: Float64):
        self._corner_radius = radius

    def state_layers(self) -> StateLayers:
        """How far a hovered, pressed or dragged widget's colour steps."""
        return self._state_layers

    def state_layers(mut self, layers: StateLayers):
        self._state_layers = layers

    def style(
        mut self,
        *,
        button: Style = Style(),
        label: Style = Style(),
        panel: Style = Style(),
        slider_track: Style = Style(),
        slider_active_track: Style = Style(),
        slider_handle: Style = Style(),
        slider_handle_outline: Style = Style(),
        checkbox_box: Style = Style(),
        checkbox_checked_box: Style = Style(),
        checkbox_tick: Style = Style(),
        checkbox_text_style: Style = Style(),
        text_field_container: Style = Style(),
        text_field_focused_container: Style = Style(),
        text_field_text_style: Style = Style(),
        text_field_placeholder_style: Style = Style(),
        text_field_caret: Style = Style(),
        text_field_selection: Style = Style(),
    ):
        """Style every widget of a kind in it: each widget's own style sits
        over these, and these over the widget's defaults, field by field.
        Replaces what an earlier call set."""
        self._styles = _Styles(
            button,
            label,
            panel,
            slider_track,
            slider_active_track,
            slider_handle,
            slider_handle_outline,
            checkbox_box,
            checkbox_checked_box,
            checkbox_tick,
            checkbox_text_style,
            text_field_container,
            text_field_focused_container,
            text_field_text_style,
            text_field_placeholder_style,
            text_field_caret,
            text_field_selection,
        )

    def _theme(self) -> _Theme:
        """The look at the top level, outside any panel."""
        return _Theme(
            colors=self._colors,
            styles=self._styles,
            corner_radius=self._corner_radius,
            spacing=self._spacing,
            control_height=self._control_height,
            state_layers=self._state_layers,
            focus_ring=self._focus_ring,
            surface=self._colors.surface,
            content=self._colors.on_surface,
        )

    # ------------------------------------------------------ every frame

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        """Update every widget, a parent before what is inside it, in the
        shared look: only the topmost widget under the pointer reacts to it.
        Call it before drawing the tree, in the same transform."""
        var topmost = self._topmost(
            canvas.to_local(context.mouse.position), canvas
        )
        var theme = self._theme()
        for root in self._roots.copy():
            self._update_from(root, context, canvas, theme, topmost)

    def _update_from(
        mut self,
        index: Int,
        mut context: Context,
        mut canvas: Canvas,
        theme: _Theme,
        topmost: Optional[Int],
    ) raises:
        """Update the widget at `index` in `theme`, then what is inside it,
        in the look of what it sits on."""
        var free = Bool(topmost) and topmost.value() == index
        var inside = self._dispatch_mut(index, context, canvas, theme, free)
        for child in self._nodes[index].children.copy():
            self._update_from(child, context, canvas, inside, topmost)

    def _topmost(self, pointer: Point, mut canvas: Canvas) -> Optional[Int]:
        """The widget drawn last of those the pointer is over, of the ones
        that take the pointer: the one that reacts to it. `canvas` is only
        passed through `_dispatch`, which draws nothing to find a hit
        area."""
        var order = self._drawing_order()
        var i = len(order) - 1
        while i >= 0:
            var area = self._dispatch(order[i], _HIT, canvas)
            if area and area.value().contains(pointer):
                return order[i]
            i -= 1
        return None

    def _drawing_order(self) -> List[Int]:
        """Every widget, a parent before what is inside it: the order they
        are drawn in."""
        var order = List[Int](capacity=len(self._nodes))
        var pending = List[Int]()
        var r = len(self._roots) - 1
        while r >= 0:
            pending.append(self._roots[r])
            r -= 1
        while pending:
            var index = pending.pop()
            order.append(index)
            ref children = self._nodes[index].children
            var c = len(children) - 1
            while c >= 0:
                pending.append(children[c])
                c -= 1
        return order^

    def draw_to(self, mut canvas: Canvas):
        for index in self._drawing_order():
            _ = self._dispatch(index, _DRAW, canvas)

    # ------------------------------------------------------------ dispatch
    #
    # The only two places that know which kinds of widget a tree holds.
    # Each matches the node's kind and hands it to that widget's own
    # methods, so a new kind needs a branch here and nothing else.

    def _dispatch(
        self, index: Int, action: Int, mut canvas: Canvas
    ) -> Optional[Rectangle]:
        """Read the widget at `index`: draw it (`_DRAW`), or give the area
        where it takes the pointer (`_HIT`), `None` where the pointer passes
        through it."""
        ref widget = self._nodes[index].widget
        if widget.isa[Button]():
            ref button = widget[Button]
            if action == _DRAW:
                canvas.draw(button)
            return button.rect
        if widget.isa[Checkbox]():
            ref checkbox = widget[Checkbox]
            if action == _DRAW:
                canvas.draw(checkbox)
            return checkbox.rect
        if widget.isa[Slider]():
            ref slider = widget[Slider]
            if action == _DRAW:
                canvas.draw(slider)
            return slider.rect
        if widget.isa[TextField]():
            ref field = widget[TextField]
            if action == _DRAW:
                canvas.draw(field)
            return field.rect
        if widget.isa[Panel]():
            ref panel = widget[Panel]
            if action == _DRAW:
                canvas.draw(panel)
            return panel.rect  # covers what is beneath it
        if widget.isa[Label]():
            if action == _DRAW:
                canvas.draw(widget[Label])
            return None  # the pointer passes through text
        if action == _DRAW:
            canvas.draw(widget[Picture])
        return None

    def _dispatch_mut(
        mut self,
        index: Int,
        mut context: Context,
        mut canvas: Canvas,
        theme: _Theme,
        free: Bool,
    ) raises -> _Theme:
        """Update the widget at `index` in `theme`, `free` when it is the
        topmost under the pointer; the look of what sits on it."""
        ref widget = self._nodes[index].widget
        if widget.isa[Button]():
            widget[Button]._update(context, canvas, theme, free=free)
        elif widget.isa[Checkbox]():
            widget[Checkbox]._update(context, canvas, theme, free=free)
        elif widget.isa[Slider]():
            widget[Slider]._update(context, canvas, theme, free=free)
        elif widget.isa[TextField]():
            widget[TextField]._update(context, canvas, theme, free=free)
        elif widget.isa[Label]():
            widget[Label]._update(context, canvas, theme, disabled=False)
        elif widget.isa[Panel]():
            ref panel = widget[Panel]
            panel._update(context, canvas, theme)
            var on_panel = theme.copy()
            on_panel.surface = panel.surface_color()
            on_panel.content = panel.content_color()
            return on_panel^
        return theme.copy()
