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
from .layout import Column, Row, Space, _sized
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
    Button,
    Checkbox,
    Label,
    Panel,
    Slider,
    TextField,
    Picture,
    Column,
    Row,
    Space,
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
    var sized_by_ui: Bool
    """Added with no size of its own: the tree gives it the size it prefers
    every frame, unless what it is in places it."""


comptime _UPDATE = 0
comptime _MEASURE = 1
comptime _PLACE = 2

comptime _WIDGET = 0
comptime _PANEL = 1
comptime _COLUMN = 2
comptime _ROW = 3
comptime _SPACE = 4


@fieldwise_init
struct _Description(Copyable, Movable):
    """What layout and hit-testing need to know about a node."""

    var kind: Int
    var rect: Rectangle
    """Where it is now; a `Space` has none."""
    var takes_pointer: Bool
    """Whether it is hit where it is, rather than letting the pointer
    through."""
    var gap: Optional[Float64]
    var weights: List[Float64]
    var height: Optional[Float64]
    """A row's height in a column, when set."""
    var amount: Optional[Float64]
    """A space's size, when set."""

    def __init__(out self, kind: Int, rect: Rectangle, takes_pointer: Bool):
        self.kind = kind
        self.rect = rect
        self.takes_pointer = takes_pointer
        self.gap = None
        self.weights = []
        self.height = None
        self.amount = None


@fieldwise_init
struct _Reply(Copyable, Movable):
    """What `_dispatch_mut` gives back: the look of what sits on the node,
    and, when measuring, the size it prefers."""

    var theme: _Theme
    var width: Float64
    var height: Float64


struct _Tree(Drawable, Movable):
    """Widgets kept together: added once, then updated and drawn each frame
    in one call each.

    ```mojo
    # In `create`, building the `ui` field and keeping a handle:
    var ui = _Tree()
    var card = ui.add(Panel())  # fitted round its column
    var list = ui.add(Column(), card)
    _ = ui.add(Label("Ready?"), list)
    var play = ui.add(Button("Play"), list)

    # In `update`:
    self.ui.update(context, canvas)
    with canvas.overlay():  # on the screen; leave it out to draw in the world
        canvas.draw(self.ui)
    if self.ui[self.play].released():
        self.start()
    ```

    A widget added inside another is drawn after it, so on top of it, and
    takes the look of what it sits on: text on a panel takes the panel's
    content colour.

    A widget added with no `rect` of its own is sized by the tree every
    frame, to the size it prefers, unless what it is in places it: a
    `Column` stacks what is inside it, a `Row` sets it side by side, and a
    `Panel` places a column or row inside it in its inside. A panel with no
    size fits the column or row inside it. Where widgets overlap, only the topmost under the
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
        self._nodes.append(_Node(_Widget(widget^), None, [], False))
        var index = len(self._nodes) - 1
        self._nodes[index].sized_by_ui = not _sized(self._describe(index).rect)
        self._roots.append(index)
        return WidgetHandle[W](index)

    def add[
        W: Copyable, P: Copyable
    ](mut self, var widget: W, parent: WidgetHandle[P]) -> WidgetHandle[W]:
        """Add `widget` inside `parent`: drawn after it and after what was
        added inside it before, and in the look of what it sits on."""
        self._nodes.append(_Node(_Widget(widget^), parent._index, [], False))
        var index = len(self._nodes) - 1
        self._nodes[index].sized_by_ui = not _sized(self._describe(index).rect)
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
        self._lay_out(context, canvas)
        var topmost = self._topmost(canvas.to_local(context.mouse.position))
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
        var reply = self._dispatch_mut(
            index, _UPDATE, context, canvas, theme, free=free
        )
        for child in self._nodes[index].children.copy():
            self._update_from(child, context, canvas, reply.theme, topmost)

    def _topmost(self, pointer: Point) -> Optional[Int]:
        """The widget drawn last of those the pointer is over, of the ones
        that take the pointer: the one that reacts to it."""
        var order = self._drawing_order()
        var i = len(order) - 1
        while i >= 0:
            var node = self._describe(order[i])
            if node.takes_pointer and node.rect.contains(pointer):
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
            self._draw(index, canvas)

    # -------------------------------------------------------------- layout

    def _lay_out(mut self, mut context: Context, mut canvas: Canvas) raises:
        """Size every widget, from what is inside it outwards, then place
        them, from the top level inwards."""
        var theme = self._theme()
        var sizes = List[Tuple[Float64, Float64]](
            length=len(self._nodes), fill=(0.0, 0.0)
        )
        # backwards through the drawing order: every node after what is in it
        var order = self._drawing_order()
        var i = len(order) - 1
        while i >= 0:
            self._measure(order[i], context, canvas, theme, sizes)
            i -= 1
        for root in self._roots.copy():
            self._place_from(root, None, context, canvas, theme, sizes)

    def _measure(
        mut self,
        index: Int,
        mut context: Context,
        mut canvas: Canvas,
        theme: _Theme,
        mut sizes: List[Tuple[Float64, Float64]],
    ) raises:
        """Work out the size the node at `index` prefers, into `sizes`, from
        the sizes of what is in it, already there."""
        var children = self._nodes[index].children.copy()
        var node = self._describe(index)
        var width = 0.0
        var height = 0.0
        if node.kind == _COLUMN:
            var gap = node.gap.or_else(theme.spacing)
            for i in range(len(children)):
                ref size = sizes[children[i]]
                width = max(width, size[0])
                height += size[1] + (gap if i > 0 else 0.0)
        elif node.kind == _ROW:
            var gap = node.gap.or_else(theme.spacing)
            for i in range(len(children)):
                ref size = sizes[children[i]]
                width += size[0] + (gap if i > 0 else 0.0)
                height = max(height, size[1])
            height = node.height.or_else(height)
        elif node.kind == _SPACE:
            width = node.amount.or_else(2 * theme.spacing)
            height = width
        elif node.kind == _PANEL:
            if _sized(node.rect):
                width = node.rect.width
                height = node.rect.height
            else:
                # fitted round the column or row inside it
                for child in children:
                    var inner = self._describe(child).kind
                    if inner == _COLUMN or inner == _ROW:
                        width = max(width, sizes[child][0])
                        height = max(height, sizes[child][1])
                width += 4 * theme.spacing
                height += 4 * theme.spacing
        else:
            var reply = self._dispatch_mut(
                index, _MEASURE, context, canvas, theme, free=False
            )
            width = reply.width
            height = reply.height
        sizes[index] = (width, height)

    def _place_from(
        mut self,
        index: Int,
        slot: Optional[Rectangle],
        mut context: Context,
        mut canvas: Canvas,
        theme: _Theme,
        sizes: List[Tuple[Float64, Float64]],
    ) raises:
        """Place the node at `index`: in `slot` when what it is in gives it
        one, at the size it prefers when it was added with none, and where
        it is otherwise; then what is inside it."""
        var node = self._describe(index)
        var rect = node.rect
        if slot:
            rect = slot.value()
        elif self._nodes[index].sized_by_ui:
            rect = Rectangle(
                node.rect.position, sizes[index][0], sizes[index][1]
            )
        if slot or self._nodes[index].sized_by_ui:
            _ = self._dispatch_mut(
                index, _PLACE, context, canvas, theme, free=False, rect=rect
            )
        var children = self._nodes[index].children.copy()
        if node.kind == _COLUMN:
            var gap = node.gap.or_else(theme.spacing)
            var top = rect.top()
            for i in range(len(children)):
                var child = children[i]
                if i > 0:
                    top -= gap
                var height = sizes[child][1]
                var strip = Rectangle(
                    Point(rect.position.x, top - height / 2),
                    rect.width,
                    height,
                )
                self._place_from(child, strip, context, canvas, theme, sizes)
                top -= height
        elif node.kind == _ROW:
            var gap = node.gap.or_else(theme.spacing)
            var weights = node.weights.copy()
            while len(weights) < len(children):
                weights.append(1.0)
            var slots = rect.columns(weights=weights, gap=gap)
            for i in range(len(children)):
                self._place_from(
                    children[i], slots[i], context, canvas, theme, sizes
                )
        elif node.kind == _PANEL:
            var inside = rect.inset(2 * theme.spacing)
            for child in children:
                var inner = self._describe(child).kind
                var given: Optional[Rectangle] = None
                if inner == _COLUMN or inner == _ROW:
                    given = inside
                self._place_from(child, given, context, canvas, theme, sizes)
        else:
            for child in children:
                self._place_from(child, None, context, canvas, theme, sizes)

    # ------------------------------------------------------------ dispatch
    #
    # The only three methods that know which kinds of node a tree holds:
    # each matches the node's kind and hands it to that kind's own fields
    # and methods, so a new kind needs a branch in each and nothing else.
    # Reading, drawing and changing a node are three because each needs the
    # tree and the canvas differently: `_describe` neither, `_draw` the
    # canvas to draw on, `_dispatch_mut` the tree to change.

    def _describe(self, index: Int) -> _Description:
        """What layout and hit-testing need to know about the node at
        `index`."""
        ref widget = self._nodes[index].widget
        if widget.isa[Button]():
            return _Description(_WIDGET, widget[Button].rect, True)
        if widget.isa[Checkbox]():
            return _Description(_WIDGET, widget[Checkbox].rect, True)
        if widget.isa[Slider]():
            return _Description(_WIDGET, widget[Slider].rect, True)
        if widget.isa[TextField]():
            return _Description(_WIDGET, widget[TextField].rect, True)
        if widget.isa[Panel]():
            # covers what is beneath it
            return _Description(_PANEL, widget[Panel].rect, True)
        if widget.isa[Label]():
            # the pointer passes through text
            return _Description(_WIDGET, widget[Label].rect, False)
        if widget.isa[Picture]():
            return _Description(_WIDGET, widget[Picture].bounds(), False)
        if widget.isa[Column]():
            ref column = widget[Column]
            var described = _Description(_COLUMN, column.rect, False)
            described.gap = column.gap
            return described^
        if widget.isa[Row]():
            ref row = widget[Row]
            var described = _Description(_ROW, row.rect, False)
            described.gap = row.gap
            described.weights = row.weights.copy()
            described.height = row.height
            return described^
        var described = _Description(
            _SPACE, Rectangle(Point(0.0, 0.0), 1.0, 1.0), False
        )
        described.amount = widget[Space].amount
        return described^

    def _draw(self, index: Int, mut canvas: Canvas):
        """Draw the node at `index`; a column, row or space draws
        nothing."""
        ref widget = self._nodes[index].widget
        if widget.isa[Button]():
            canvas.draw(widget[Button])
        elif widget.isa[Checkbox]():
            canvas.draw(widget[Checkbox])
        elif widget.isa[Slider]():
            canvas.draw(widget[Slider])
        elif widget.isa[TextField]():
            canvas.draw(widget[TextField])
        elif widget.isa[Panel]():
            canvas.draw(widget[Panel])
        elif widget.isa[Label]():
            canvas.draw(widget[Label])
        elif widget.isa[Picture]():
            canvas.draw(widget[Picture])

    def _dispatch_mut(
        mut self,
        index: Int,
        action: Int,
        mut context: Context,
        mut canvas: Canvas,
        theme: _Theme,
        *,
        free: Bool,
        rect: Rectangle = Rectangle(Point(0.0, 0.0), 0.0, 0.0),
    ) raises -> _Reply:
        """Update (`_UPDATE`), measure (`_MEASURE`) or place in `rect`
        (`_PLACE`) the node at `index`, in `theme`; `free` when it is the
        topmost under the pointer. Gives back the look of what sits on it
        and, when measuring, the size it prefers."""
        var reply = _Reply(theme.copy(), 0.0, 0.0)
        ref widget = self._nodes[index].widget
        if widget.isa[Button]():
            ref button = widget[Button]
            if action == _UPDATE:
                button._update(context, canvas, theme, free=free)
            elif action == _MEASURE:
                reply.width, reply.height = button._measure(canvas, theme)
            else:
                button.rect = rect
        elif widget.isa[Checkbox]():
            ref checkbox = widget[Checkbox]
            if action == _UPDATE:
                checkbox._update(context, canvas, theme, free=free)
            elif action == _MEASURE:
                reply.width, reply.height = checkbox._measure(canvas, theme)
            else:
                checkbox.rect = rect
        elif widget.isa[Slider]():
            ref slider = widget[Slider]
            if action == _UPDATE:
                slider._update(context, canvas, theme, free=free)
            elif action == _MEASURE:
                reply.width, reply.height = slider._measure(canvas, theme)
            else:
                slider.rect = rect
        elif widget.isa[TextField]():
            ref field = widget[TextField]
            if action == _UPDATE:
                field._update(context, canvas, theme, free=free)
            elif action == _MEASURE:
                reply.width, reply.height = field._measure(canvas, theme)
            else:
                field.rect = rect
        elif widget.isa[Label]():
            ref label = widget[Label]
            if action == _UPDATE:
                label._update(context, canvas, theme, disabled=False)
            elif action == _MEASURE:
                reply.width, reply.height = label._measure(canvas, theme)
            else:
                label.rect = rect
        elif widget.isa[Panel]():
            ref panel = widget[Panel]
            if action == _UPDATE:
                panel._update(context, canvas, theme)
                reply.theme.surface = panel.surface_color()
                reply.theme.content = panel.content_color()
            elif action == _PLACE:
                panel.rect = rect
        elif widget.isa[Picture]():
            ref picture = widget[Picture]
            if action == _MEASURE:
                reply.width = picture.width
                reply.height = picture.height
            elif action == _PLACE:
                picture.position = rect.position
                picture.width = rect.width
                picture.height = rect.height
        elif widget.isa[Column]():
            if action == _PLACE:
                widget[Column].rect = rect
        elif widget.isa[Row]():
            if action == _PLACE:
                widget[Row].rect = rect
        return reply^
