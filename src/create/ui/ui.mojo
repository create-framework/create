"""`UI`, the widget tree: widgets kept together, updated and drawn in one
call each, in a shared look, with only the topmost under the pointer
reacting to it.
"""

from std.memory import ArcPointer
from std.os import abort
from std.utils import Variant

from create.color import Color
from create.app import Context
from create.geometry import Circle, Rectangle
from create.input import GamepadButton, Key
from create.math import OptionalNumber, Point, Vector, clamp
from create.render import Align, Canvas, Drawable, Picture, Style, Text
from .button import Button
from .widget_handle import WidgetHandle
from .checkbox import Checkbox
from .color_scheme import ColorScheme
from .focus_ring import FocusRing
from .state_layers import StateLayers
from .label import Label
from ._navigation import (
    _Focus,
    _PadRepeat,
    _arrow_push,
    _nearest,
    _pad_pressed,
    _pad_push,
)
from ._layout import _Placement, _across, _overlap, _shares, _sized
from .column import Column
from .row import Row
from .space import Space
from .scroll_area import ScrollArea
from .panel import Panel
from .progress_bar import ProgressBar
from .slider import Slider
from .switch import Switch
from .choice_group import ChoiceGroup
from .tabs import Tabs
from .number_field import NumberField
from .dropdown import Dropdown
from .text_field import TextField, _measure
from ._theme import (
    _CONTROL_HEIGHT,
    _CORNER_RADIUS,
    _SPACING,
    _Styles,
    _Theme,
    _TooltipLook,
)


comptime _TOOLTIP_DELAY = 0.5
"""How long, in seconds, the pointer rests on a widget before its tooltip
shows."""

comptime _TOOLTIP_PADDING = 8.0
"""The room round a tooltip's text, inside its box."""

comptime _TOOLTIP_GAP = 6.0
"""The gap between a widget and its tooltip."""


comptime _Widget = Variant[
    Button,
    Checkbox,
    Switch,
    ChoiceGroup,
    Tabs,
    Label,
    Panel,
    Slider,
    TextField,
    NumberField,
    Dropdown,
    Picture,
    ProgressBar,
    Column,
    Row,
    Space,
    ScrollArea,
]
"""The kinds of node a tree holds. Storage only: what each does is its own,
reached through `_describe`, `_draw` and `_dispatch_mut`."""


comptime _Container = Variant[Panel, Column, Row, ScrollArea]
"""The kinds of node another can be added inside."""

comptime _NOT_A_NODE = (
    "ui.add takes a Button, Checkbox, Switch, ChoiceGroup, Tabs, Label,"
    " Panel, Slider, TextField, NumberField, Dropdown, Picture, ProgressBar,"
    " Column, Row, Space or ScrollArea"
)
comptime _NOT_A_CONTAINER = (
    "ui.add adds a widget inside a Panel, Column, Row or ScrollArea only"
)


@fieldwise_init
struct _Node(Copyable, Movable):
    var widget: _Widget
    var parent: Optional[Int]
    var children: List[Int]
    var sized_by_ui: Bool
    """Added with no size of its own: the tree gives it the size it prefers
    every frame, unless what it is in places it."""
    var enabled: Bool
    """Whether the tree lets it and what is inside it react: `ui.enabled`
    sets it, apart from each widget's own `enabled`."""
    var visible: Bool
    """Whether it and what is inside it are shown: `ui.visible` sets it."""
    var generation: Int
    """How many nodes had been at its place in the list before it."""
    var removed: Bool
    """Whether `ui.remove` has removed it, leaving its place free for the
    next node added."""
    var placement: _Placement
    """How it fits in the column or row it is in: what `ui.add` was told."""
    var clip: Optional[Rectangle]
    """What of it can be seen and clicked: the windows of the `ScrollArea`s it
    is in, overlapped, as the last layout left them. All of it when
    `None`."""
    var tooltip: Optional[String]
    """The text shown near it while the pointer rests on it, or while it
    has focus from the keyboard or a gamepad: `ui.tooltip` sets it."""


comptime _UPDATE = 0
comptime _MEASURE = 1
comptime _PLACE = 2
comptime _SCROLL_TO = 3

comptime _WIDGET = 0
comptime _PANEL = 1
comptime _COLUMN = 2
comptime _ROW = 3
comptime _SPACE = 4
comptime _SCROLL_AREA = 5


@fieldwise_init
struct _Description(Copyable, Movable):
    """What layout and hit-testing need to know about a node."""

    var kind: Int
    var rect: Rectangle
    """Where it is now; a `Space` has none, and no size."""
    var takes_pointer: Bool
    """Whether it is hit where it is, rather than letting the pointer
    through."""
    var gap: Optional[Float64]
    var align: Optional[Align]
    """Where a column or row sets its children across it: stretched when
    `None`."""
    var amount: Optional[Float64]
    """A space's size, when set."""
    var padding: Optional[Float64]
    """A panel's padding, when set."""
    var offset: Float64
    """How far down its column a scroll area shows."""
    var max_height: Optional[Float64]
    """The tallest a scroll area grows, when set."""
    var overflows: Bool
    """Whether a scroll area's column is taller than it, so it scrolls."""
    var room: Float64
    """How far a scroll area can scroll."""
    var focusable: Bool
    """Whether it can take focus: a widget that reacts, while enabled."""
    var takes_typing: Bool
    var adjusts_x: Bool
    """Whether the left and right arrows and a gamepad's push change it, as
    they step a slider, rather than move focus away."""
    var adjusts_y: Bool
    """Whether the up and down arrows and a gamepad's push change it,
    rather than move focus away."""
    var ring: Optional[Rectangle]
    """The shape its focus ring goes round, when it is a rectangle."""
    var ring_circle: Optional[Circle]
    """The shape its focus ring goes round, when it is a circle."""
    var held: Bool
    """Whether the mouse holds it: pressed on it and not let go."""
    var captures_keys: Bool
    """Whether it takes every key and push itself while focused, such as a
    dropdown with its list open: the arrows, Enter, Space, Escape and the
    gamepad's buttons, which then move and clear no focus."""
    var popup: Optional[Rectangle]
    """What it draws over everything else, such as a dropdown's open list,
    while it does."""
    var focus_request: Optional[Bool]
    """Whether the program asked the widget itself for focus (`True`) or
    for it to let go (`False`) since its last update."""

    def __init__(out self, kind: Int, rect: Rectangle, takes_pointer: Bool):
        self.kind = kind
        self.rect = rect
        self.takes_pointer = takes_pointer
        self.gap = None
        self.align = None
        self.amount = None
        self.padding = None
        self.offset = 0
        self.max_height = None
        self.overflows = False
        self.room = 0
        self.focusable = False
        self.takes_typing = False
        self.adjusts_x = False
        self.adjusts_y = False
        self.ring = None
        self.ring_circle = None
        self.held = False
        self.captures_keys = False
        self.popup = None
        self.focus_request = None


@fieldwise_init
struct _Tooltip(Copyable, Movable):
    """A tooltip as this frame shows it: its text, where its box is, and
    the look it is drawn in."""

    var text: String
    var rect: Rectangle
    var look: _TooltipLook


@fieldwise_init
struct _Reply(Copyable, Movable):
    """What `_dispatch_mut` gives back: the look of what sits on the node,
    when measuring, the size it prefers, and, when updating, whether it was
    a scroll area that moved."""

    var theme: _Theme
    var width: Float64
    var height: Float64
    var scrolled: Bool


struct UI(Drawable, Movable):
    """Widgets kept together: added once, then updated and drawn each frame
    in one call each.

    ```mojo
    # In `create`, building the `ui` field and keeping a handle:
    var ui = UI()
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
    `Panel` places a column or row inside it in its inside, and a `ScrollArea`
    shows part of a column taller than itself. A panel with no size fits
    the column or row inside it. Where widgets overlap, only the
    topmost under the pointer reacts to it, and a `Panel` covers what is
    beneath it.

    `ui.visible(handle, False)` hides a widget and everything inside it until
    it is shown again, and `ui.remove(handle)` takes them out of the tree for
    good.

    `update` hit-tests through `canvas.to_local`, so call it in the same
    transform and camera the tree is drawn in.
    """

    var _nodes: List[_Node]
    var _roots: List[Int]
    var _free: List[Int]
    """The places in `_nodes` that removed nodes left, for the next nodes
    added."""
    var _reveal: Optional[Int]
    """A node to scroll into view at the next `update`: one focus moved to
    from the keyboard, a gamepad or code, or one `scroll_to` named."""
    var _identity: ArcPointer[Int]
    """A cell of its own on the heap, whose address tells its handles from
    another `UI`'s: it stays put when the `UI` is moved."""
    var _colors: ColorScheme
    var _styles: ArcPointer[_Styles]
    """What `style` sets, on the heap: seventeen `Style`s inline made a `UI`
    12 KB, and moving one through a pointer, as `run` moves a program,
    took the compiler gigabytes."""
    var _corner_radius: Float64
    var _spacing: Float64
    var _control_height: Float64
    var _state_layers: StateLayers
    var _focus_ring: FocusRing
    var _player: Optional[Int]
    var _focused: Optional[Int]
    """The node with focus."""
    var _focus_visible: Bool
    """Whether focus came from the keyboard, a gamepad or code, so its ring
    shows; a click gives focus without one."""
    var _focus_from_gamepad: Bool
    var _pad_repeat: _PadRepeat
    var _arrow_moved: Bool
    """Whether an arrow key moved focus this frame, so it doesn't also
    step the slider it lands on."""
    var _back: Bool
    """Whether Escape or the east button backed out of the focused widget
    this frame, rather than taking its focus away."""
    var _pad_move: Vector
    """This frame's push on a gamepad, which a focused slider may take."""
    var _typing_was: Bool
    var _claimant: Int
    """Its number for claiming the keyboard and mouse, from
    `Context._new_claimant()`; 0 until its first `update`."""
    var _frame: Int
    """The frame it was last updated in."""
    var _tip_node: Optional[Int]
    """The node the pointer last rested on that has a tooltip."""
    var _tip_since: Float64
    """When the pointer came to rest on it, by the real clock."""
    var _tip_dismissed: Bool
    """Whether a press hid its tooltip until the pointer leaves it."""
    var _tip: Optional[_Tooltip]
    """The tooltip to draw this frame, if any."""
    var _pointed_at: Bool
    """Whether the pointer was over one of its widgets at its last
    `update`."""
    var _key_used: Bool
    """Whether a key acted on it at its last `update`: moved or took away
    focus, or pressed, stepped or typed into the focused widget."""

    def __init__(out self, *, player: Optional[Int] = None):
        """A tree whose focus any gamepad moves, unless `player` names one,
        as each player's menu in a split-screen game would."""
        self._player = player
        self._focused = None
        self._focus_visible = False
        self._focus_from_gamepad = False
        self._pad_repeat = _PadRepeat()
        self._arrow_moved = False
        self._pad_move = Vector.ZERO
        self._back = False
        self._typing_was = False
        self._claimant = 0
        self._frame = -1
        self._pointed_at = False
        self._key_used = False
        self._nodes = []
        self._roots = []
        self._free = []
        self._identity = ArcPointer(0)
        self._tip_node = None
        self._tip_since = 0
        self._tip_dismissed = False
        self._tip = None
        self._reveal = None
        self._colors = ColorScheme.light()
        self._styles = ArcPointer(_Styles())
        self._corner_radius = _CORNER_RADIUS
        self._spacing = _SPACING
        self._control_height = _CONTROL_HEIGHT
        self._state_layers = StateLayers()
        self._focus_ring = FocusRing()

    # ----------------------------------------------------------- building

    def add[W: Copyable](mut self, var widget: W) -> WidgetHandle[W]:
        """Add `widget` at the top level, drawn above everything added
        before it. It is a `Button`, `Checkbox`, `Switch`, `ChoiceGroup`,
        `Tabs`, `Label`, `Panel`, `Slider`, `NumberField`, `Dropdown`,
        `TextField`, `Picture`, `ProgressBar`, `Column`, `Row`, `Space` or
        `ScrollArea`;
        anything else doesn't compile."""
        comptime assert _Widget.is_type_supported[W](), _NOT_A_NODE
        var handle = self._new_node[W](_Widget(widget^), None, _Placement())
        self._roots.append(handle._index)
        return handle

    def add[
        W: Copyable, P: Copyable
    ](
        mut self,
        var widget: W,
        parent: WidgetHandle[P],
        *,
        grow: OptionalNumber = None,
        width: OptionalNumber = None,
        height: OptionalNumber = None,
        align: Optional[Align] = None,
    ) -> WidgetHandle[W]:
        """Add `widget` inside `parent`: drawn after it and after what was
        added inside it before, and in the look of what it sits on. Only a
        `Panel`, `Column`, `Row` or `ScrollArea` can be a parent; anything else
        doesn't compile.

        In a column or row, `width` and `height` set the size it starts
        from, in place of the one it prefers, so two buttons given the same
        `width` are as wide as each other:

        ```mojo
        # In `create`: two buttons of one width, side by side.
        var buttons = ui.add(Row(), column)
        var ok = ui.add(Button("OK"), buttons, width=120)
        var cancel = ui.add(Button("Cancel"), buttons, width=120)
        ```

        The room a column or row has left over, once each widget has the
        size it starts from, goes to the widgets added with a `grow`, in
        proportion to it. A `width` of 0 with a `grow` gives exact shares:
        `grow=1` and `grow=3` take a quarter and three quarters. `align`
        sets where it sits across the column or row, in place of the
        column's or row's own `align`, and a widget given a `width` in a
        column, or a `height` in a row, is centred across it unless aligned.
        A negative `grow`, `width` or
        `height` stops the program.
        """
        comptime assert _Widget.is_type_supported[W](), _NOT_A_NODE
        comptime assert _Container.is_type_supported[P](), _NOT_A_CONTAINER
        if grow.or_else(0) < 0 or width.or_else(0) < 0 or height.or_else(0) < 0:
            abort("create: ui.add given a negative grow, width or height")
        var inside = self._index_of(parent)
        var placement = _Placement(
            grow.or_else(0), width._value, height._value, align
        )
        var handle = self._new_node[W](_Widget(widget^), inside, placement^)
        self._nodes[inside].children.append(handle._index)
        return handle

    def _new_node[
        W: Copyable
    ](
        mut self,
        var widget: _Widget,
        parent: Optional[Int],
        var placement: _Placement,
    ) -> WidgetHandle[W]:
        """Keep `widget` in a node of its own, in a place a removed node
        left when there is one, and hand back its handle."""
        var index: Int
        var generation = 0
        if self._free:
            index = self._free.pop()
            generation = self._nodes[index].generation + 1
            self._nodes[index] = _Node(
                widget^,
                parent,
                [],
                False,
                True,
                True,
                generation,
                False,
                placement^,
                None,
                None,
            )
        else:
            index = len(self._nodes)
            self._nodes.append(
                _Node(
                    widget^,
                    parent,
                    [],
                    False,
                    True,
                    True,
                    0,
                    False,
                    placement^,
                    None,
                    None,
                )
            )
        self._nodes[index].sized_by_ui = not _sized(self._describe(index).rect)
        return WidgetHandle[W](index, generation, self._id())

    def _id(self) -> Int:
        """Its identity: the address of its `_identity` cell."""
        return Int(Pointer(to=self._identity[]))

    def _index_of[W: Copyable](self, handle: WidgetHandle[W]) -> Int:
        """Where the node `handle` names is, stopping the program when the
        handle is another `UI`'s or its widget has been removed."""
        if handle._tree != self._id():
            abort("create: a WidgetHandle used on a UI it doesn't belong to")
        ref node = self._nodes[handle._index]
        if node.removed or node.generation != handle._generation:
            abort(
                "create: a WidgetHandle used after its widget was removed"
                " from the UI"
            )
        return handle._index

    def __getitem__[
        W: Copyable
    ](ref self, handle: WidgetHandle[W]) -> ref[
        self._nodes[handle._index].widget[W]
    ] W:
        """The widget `handle` names, to read or change:
        `ui[play].text = "Go"`, or `if ui[play].released():`.

        It is the widget itself, inside the `UI`, so while one is in use no
        other can be: `Vector(ui[x].value, ui[y].value)` doesn't compile in a
        method that changes the `UI`. Read each into a variable first, or
        read with `get`, which hands back a copy."""
        return self._nodes[self._index_of(handle)].widget[W]

    def get[W: Copyable](self, handle: WidgetHandle[W]) -> W:
        """A copy of the widget `handle` names, to read: as many can be read
        in one expression as you like, as in
        `Vector(ui.get(x).value, ui.get(y).value)`. Changing the copy
        changes nothing in the `UI`; change a widget through `ui[handle]`.
        """
        return self._nodes[self._index_of(handle)].widget[W].copy()

    def remove[W: Copyable](mut self, handle: WidgetHandle[W]):
        """Take the widget `handle` names out of the tree, and everything
        inside it, for good: they are no longer laid out, updated or drawn,
        and the focus leaves them. Their handles name nothing afterwards, so
        drop them; to take a widget away for a while, hide it with
        `visible` instead.

        ```mojo
        # In `update`, with `ui: UI` and `items: List[WidgetHandle[Button]]`
        # fields: the item clicked is used up.
        for i in range(len(self.items)):
            if self.ui[self.items[i]].released():
                self.ui.remove(self.items.pop(i))
                break
        ```
        """
        var index = self._index_of(handle)
        var parent = self._nodes[index].parent
        if parent:
            _drop(self._nodes[parent.value()].children, index)
        else:
            _drop(self._roots, index)
        var pending: List[Int] = [index]
        while pending:
            var at = pending.pop()
            if self._focused and self._focused.value() == at:
                self.clear_focus()
            ref node = self._nodes[at]
            pending.extend(node.children.copy())
            node.children = []
            node.widget = _Widget(Space())  # lets go of what it held
            node.parent = None
            node.removed = True
            self._free.append(at)

    def visible[W: Copyable](self, handle: WidgetHandle[W]) -> Bool:
        """Whether the tree shows the widget `handle` names, apart from what
        it is inside: `True` unless set."""
        return self._nodes[self._index_of(handle)].visible

    def visible[W: Copyable](mut self, handle: WidgetHandle[W], visible: Bool):
        """Show the widget `handle` names, and everything inside it, or hide
        them: a hidden part of the tree isn't drawn, takes no room in a
        column or row, reacts to nothing, takes no focus and lets go of
        focus it has. Its widgets keep their fields, so showing it again
        brings it back as it was.

        ```mojo
        # In `update`: the advanced settings show while their box is ticked.
        var ticked = self.ui[self.advanced].checked
        self.ui.visible(self.advanced_settings, ticked)
        ```
        """
        self._nodes[self._index_of(handle)].visible = visible

    def _hidden(self, index: Int) -> Bool:
        """Whether the node at `index` is in a part of the tree that is
        hidden: it, or something it is inside."""
        var at = Optional[Int](index)
        while at:
            ref node = self._nodes[at.value()]
            if not node.visible:
                return True
            at = node.parent
        return False

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

    def spacing(self) -> Float64:
        """The gap a `Column` or `Row` leaves between its widgets unless
        given one, and half the inset of a panel's inside: 8 unless set."""
        return self._spacing

    def spacing(mut self, spacing: Float64):
        self._spacing = spacing

    def control_height(self) -> Float64:
        """How tall a button, checkbox, slider or text field is when the
        `UI` sizes it: 40 unless set."""
        return self._control_height

    def control_height(mut self, height: Float64):
        self._control_height = height

    def focus_ring(self) -> FocusRing:
        """How the ring round a widget focused from the keyboard, a gamepad
        or code is drawn."""
        return self._focus_ring

    def focus_ring(mut self, ring: FocusRing):
        self._focus_ring = ring

    def state_layers(self) -> StateLayers:
        """How far a hovered, pressed or dragged widget's colour steps."""
        return self._state_layers

    def state_layers(mut self, layers: StateLayers):
        self._state_layers = layers

    def style(
        mut self,
        *,
        button: Optional[Style] = None,
        label: Optional[Style] = None,
        panel: Optional[Style] = None,
        slider_track: Optional[Style] = None,
        slider_active_track: Optional[Style] = None,
        slider_handle: Optional[Style] = None,
        slider_handle_outline: Optional[Style] = None,
        checkbox_box: Optional[Style] = None,
        checkbox_checked_box: Optional[Style] = None,
        checkbox_tick: Optional[Style] = None,
        checkbox_text_style: Optional[Style] = None,
        text_field_container: Optional[Style] = None,
        text_field_focused_container: Optional[Style] = None,
        text_field_text_style: Optional[Style] = None,
        text_field_placeholder_style: Optional[Style] = None,
        text_field_caret: Optional[Style] = None,
        text_field_selection: Optional[Style] = None,
        scroll_area_track: Optional[Style] = None,
        scroll_area_thumb: Optional[Style] = None,
        progress_bar_track: Optional[Style] = None,
        progress_bar_indicator: Optional[Style] = None,
        switch_track: Optional[Style] = None,
        switch_on_track: Optional[Style] = None,
        switch_handle: Optional[Style] = None,
        switch_text_style: Optional[Style] = None,
        choice_group_circle: Optional[Style] = None,
        choice_group_selected_circle: Optional[Style] = None,
        choice_group_dot: Optional[Style] = None,
        choice_group_text_style: Optional[Style] = None,
        tabs_tab: Optional[Style] = None,
        tabs_selected_tab: Optional[Style] = None,
        tabs_indicator: Optional[Style] = None,
        number_field_container: Optional[Style] = None,
        number_field_text_style: Optional[Style] = None,
        number_field_buttons: Optional[Style] = None,
        dropdown_field: Optional[Style] = None,
        dropdown_list: Optional[Style] = None,
        dropdown_item: Optional[Style] = None,
        tooltip: Optional[Style] = None,
    ):
        """Style every widget of a kind in it: each widget's own style sits
        over these, and these over the widget's defaults, field by field.

        Each keyword given replaces what an earlier call set for that kind,
        and a kind left out keeps it, so the styles can be set a few at a
        time. `Style()` clears a kind's style:

        ```mojo
        # In `create`, building the `ui` field:
        ui.style(button=Style(corner_radius=4))
        ui.style(slider_handle=Style(stroke=Color.ORANGE))  # buttons kept
        ui.style(button=Style())  # the buttons' defaults again
        ```
        """
        var styles = self._styles[]
        if button:
            styles.button = button.value()
        if label:
            styles.label = label.value()
        if panel:
            styles.panel = panel.value()
        if slider_track:
            styles.slider_track = slider_track.value()
        if slider_active_track:
            styles.slider_active_track = slider_active_track.value()
        if slider_handle:
            styles.slider_handle = slider_handle.value()
        if slider_handle_outline:
            styles.slider_handle_outline = slider_handle_outline.value()
        if checkbox_box:
            styles.checkbox_box = checkbox_box.value()
        if checkbox_checked_box:
            styles.checkbox_checked_box = checkbox_checked_box.value()
        if checkbox_tick:
            styles.checkbox_tick = checkbox_tick.value()
        if checkbox_text_style:
            styles.checkbox_label_style = checkbox_text_style.value()
        if text_field_container:
            styles.text_field_container = text_field_container.value()
        if text_field_focused_container:
            styles.text_field_focused = text_field_focused_container.value()
        if text_field_text_style:
            styles.text_field_text_style = text_field_text_style.value()
        if text_field_placeholder_style:
            styles.text_field_placeholder_style = (
                text_field_placeholder_style.value()
            )
        if text_field_caret:
            styles.text_field_caret = text_field_caret.value()
        if text_field_selection:
            styles.text_field_selection = text_field_selection.value()
        if scroll_area_track:
            styles.scroll_area_track = scroll_area_track.value()
        if scroll_area_thumb:
            styles.scroll_area_thumb = scroll_area_thumb.value()
        if progress_bar_track:
            styles.progress_bar_track = progress_bar_track.value()
        if progress_bar_indicator:
            styles.progress_bar_indicator = progress_bar_indicator.value()
        if switch_track:
            styles.switch_track = switch_track.value()
        if switch_on_track:
            styles.switch_on_track = switch_on_track.value()
        if switch_handle:
            styles.switch_handle = switch_handle.value()
        if switch_text_style:
            styles.switch_text_style = switch_text_style.value()
        if choice_group_circle:
            styles.choice_group_circle = choice_group_circle.value()
        if choice_group_selected_circle:
            styles.choice_group_selected_circle = (
                choice_group_selected_circle.value()
            )
        if choice_group_dot:
            styles.choice_group_dot = choice_group_dot.value()
        if choice_group_text_style:
            styles.choice_group_text_style = choice_group_text_style.value()
        if tabs_tab:
            styles.tabs_tab = tabs_tab.value()
        if tabs_selected_tab:
            styles.tabs_selected_tab = tabs_selected_tab.value()
        if tabs_indicator:
            styles.tabs_indicator = tabs_indicator.value()
        if number_field_container:
            styles.number_field_container = number_field_container.value()
        if number_field_text_style:
            styles.number_field_text_style = number_field_text_style.value()
        if number_field_buttons:
            styles.number_field_buttons = number_field_buttons.value()
        if dropdown_field:
            styles.dropdown_field = dropdown_field.value()
        if dropdown_list:
            styles.dropdown_list = dropdown_list.value()
        if dropdown_item:
            styles.dropdown_item = dropdown_item.value()
        if tooltip:
            styles.tooltip = tooltip.value()
        self._styles = ArcPointer(styles^)

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
        if self._claimant == 0:
            self._claimant = context._new_claimant()
        var frame = context.frame_count()
        self._frame = frame
        self._lay_out(context, canvas)
        # another tree holding the mouse: this one leaves it alone
        var topmost = Optional[Int](None)
        if not context.mouse._claim.held_by_other(self._claimant, frame):
            topmost = self._topmost(canvas.to_local(context.mouse.position))
        self._pointed_at = Bool(topmost)
        self._navigate(context, topmost)
        # what focus moved onto, or `scroll_to` named, brought into view
        # before any widget acts on where it is
        if self._reveal:
            var reveal = self._reveal.value()
            self._reveal = None
            if not self._nodes[reveal].removed and not self._hidden(reveal):
                if self._scroll_into_view(reveal, context, canvas):
                    self._lay_out(context, canvas)
        var wheel = Optional[Int](None)
        if context.mouse.wheel.y != 0:
            wheel = self._wheel_target(topmost)
        var theme = self._theme()
        var scrolled = False
        for root in self._roots.copy():
            if self._update_from(root, context, canvas, theme, topmost, wheel):
                scrolled = True
        # a scroll area the wheel or its thumb moved: its column goes where
        # it is drawn this frame
        if scrolled:
            self._lay_out(context, canvas)
        self._place_tooltip(context, canvas, topmost)
        self._claim(context)

    def wants_mouse(self, context: Context) -> Bool:
        """Whether the mouse is the tree's this frame: the pointer is over
        one of its widgets, or one is held. A game checks it before using
        the mouse itself, so a click on a button doesn't also fire a weapon.
        It reads the tree's last `update`, and a tree not updated this frame
        or last, such as a menu that has closed, never wants it.

        ```mojo
        # In `update`, after the tree's `update`:
        if context.mouse.pressed() and not self.ui.wants_mouse(context):
            self.fire()
        ```
        """
        if not self._updated_lately(context):
            return False
        return self._pointed_at or self._holds_mouse()

    def wants_keyboard(self, context: Context) -> Bool:
        """Whether the keyboard is the tree's this frame: a text field has
        focus, or a widget has focus from the keyboard or code, so keys act
        on it; and in the frame a key moved or took away focus, such as
        Escape leaving a text field. A game checks it before reading keys
        itself, so typing a name with W in it doesn't move the player. A
        tree not updated this frame or last never wants it.

        ```mojo
        # In `update`, after the tree's `update`:
        if (
            context.keyboard.pressed(Key.ESCAPE)
            and not self.ui.wants_keyboard(context)
        ):
            context.quit()
        ```
        """
        if not self._updated_lately(context):
            return False
        return self._holds_keys() or self._key_used

    def _updated_lately(self, context: Context) -> Bool:
        return self._frame >= context.frame_count() - 1

    def _holds_keys(self) -> Bool:
        """Whether its focus takes keys: from the keyboard or code, or on a
        text field. Focus from a click on a button or from a gamepad
        doesn't."""
        if not self._focused:
            return False
        if self._focus_visible and not self._focus_from_gamepad:
            return True
        var node = self._describe(self._focused.value())
        return node.takes_typing or node.captures_keys

    def _captures(self) -> Bool:
        """Whether the focused widget takes every key and push itself, as an
        open dropdown does."""
        return (
            Bool(self._focused)
            and self._describe(self._focused.value()).captures_keys
        )

    def _holds_mouse(self) -> Bool:
        """Whether one of its widgets is held."""
        for index in self._drawing_order():
            if self._describe(index).held:
                return True
        return False

    def _claim(self, mut context: Context):
        """Claim the keyboard while its focus takes keys, and the mouse while
        one of its widgets is held, renewing the claims every frame, so
        another tree leaves them alone; let go of them otherwise."""
        var frame = context.frame_count()
        if self._holds_keys():
            context.keyboard._claim.claim(self._claimant, frame)
        else:
            context.keyboard._claim.release(self._claimant)
        if self._holds_mouse():
            context.mouse._claim.claim(self._claimant, frame)
        else:
            context.mouse._claim.release(self._claimant)

    # ------------------------------------------------------------ enabled

    def enabled[W: Copyable](self, handle: WidgetHandle[W]) -> Bool:
        """Whether the tree lets the widget `handle` names react, apart from
        its own `enabled`: `True` unless set."""
        return self._nodes[self._index_of(handle)].enabled

    def enabled[W: Copyable](mut self, handle: WidgetHandle[W], enabled: Bool):
        """Let the widget `handle` names, and everything inside it, react,
        or not: the widgets, labels and pictures in a disabled part of the
        tree are drawn faded, take no focus, and let go of focus they have;
        a panel keeps its colour. Each widget's own `enabled` is kept,
        so enabling the part again restores it."""
        self._nodes[self._index_of(handle)].enabled = enabled

    def _disabled(self, index: Int) -> Bool:
        """Whether the node at `index` is in a part of the tree that is
        disabled: it, or something it is inside."""
        var at = Optional[Int](index)
        while at:
            ref node = self._nodes[at.value()]
            if not node.enabled:
                return True
            at = node.parent
        return False

    def _can_focus(self, index: Int) -> Bool:
        return (
            self._describe(index).focusable
            and not self._disabled(index)
            and not self._hidden(index)
        )

    def _update_from(
        mut self,
        index: Int,
        mut context: Context,
        mut canvas: Canvas,
        theme: _Theme,
        topmost: Optional[Int],
        wheel: Optional[Int],
    ) raises -> Bool:
        """Update the widget at `index` in `theme`, then what is inside it,
        in the look of what it sits on; `wheel` is the scroll area the
        mouse wheel scrolls, if any. Gives back whether a scroll area among
        them moved. A hidden widget is updated as a
        disabled one, so it lets go and keeps no click or change from before
        it was hidden to report while it is."""
        var free = Bool(topmost) and topmost.value() == index
        var hidden = self._hidden(index)
        var focus = _Focus(
            in_tree=True,
            focused=False,
            keys=False,
            activated=False,
            push=Vector.ZERO,
            back=False,
        )
        if not hidden:
            focus = self._focus_for(index, context)
        var reply = self._dispatch_mut(
            index,
            _UPDATE,
            context,
            canvas,
            theme,
            free=free and not hidden,
            focus=focus,
            disabled=hidden or self._disabled(index),
            wheel=Bool(wheel) and wheel.value() == index,
        )
        var scrolled = reply.scrolled
        for child in self._nodes[index].children.copy():
            if self._update_from(
                child, context, canvas, reply.theme, topmost, wheel
            ):
                scrolled = True
        return scrolled

    def _scroll_into_view(
        mut self, index: Int, mut context: Context, mut canvas: Canvas
    ) raises -> Bool:
        """Scroll each scroll area the node at `index` is in, innermost
        first, by the least that brings it, as last placed, and the focus
        ring round it, inside the area's window. Gives back whether any
        moved."""
        var theme = self._theme()
        var shown = self._describe(index).rect.inset(-theme.ring_reach())
        var moved = False
        var at = self._nodes[index].parent
        while at:
            var area = at.value()
            var node = self._describe(area)
            if node.kind == _SCROLL_AREA:
                ref window = node.rect
                var offset = node.offset
                if shown.top() > window.top():
                    offset -= shown.top() - window.top()
                elif shown.bottom() < window.bottom():
                    offset += window.bottom() - shown.bottom()
                offset = min(max(offset, 0.0), node.room)
                if offset != node.offset:
                    _ = self._dispatch_mut(
                        area,
                        _SCROLL_TO,
                        context,
                        canvas,
                        theme,
                        free=False,
                        content=offset,
                    )
                    # the node moves up as far as the column does
                    shown = shown.translate(Vector(0, offset - node.offset))
                    moved = True
            at = self._nodes[area].parent
        return moved

    def _tooltip_of(self, index: Optional[Int]) -> Optional[Int]:
        """The node whose tooltip shows for `index`: it, or the nearest node
        it is inside that has one."""
        var at = index
        while at:
            if self._nodes[at.value()].tooltip:
                return at
            at = self._nodes[at.value()].parent
        return None

    def _place_tooltip(
        mut self,
        mut context: Context,
        mut canvas: Canvas,
        topmost: Optional[Int],
    ) raises:
        """Work out this frame's tooltip: the one the pointer has rested on
        for `_TOOLTIP_DELAY`, unless a press hid it, or else the focused
        widget's while its focus shows from the keyboard or a gamepad."""
        self._tip = None
        var now = context.time.real_elapsed
        var pointed = self._tooltip_of(topmost)
        var same = Bool(pointed) == Bool(self._tip_node) and (
            not pointed or pointed.value() == self._tip_node.value()
        )
        if not same:
            self._tip_node = pointed
            self._tip_since = now
            self._tip_dismissed = False
        if context.mouse.pressed():
            self._tip_dismissed = True
        var shown = Optional[Int](None)
        if (
            pointed
            and not self._tip_dismissed
            and now - self._tip_since >= _TOOLTIP_DELAY
        ):
            shown = pointed
        elif self._focused and self._focus_visible:
            shown = self._tooltip_of(self._focused)
        if not shown or self._hidden(shown.value()):
            return
        var index = shown.value()
        var text = self._nodes[index].tooltip.value()
        var look = self._theme().tooltip()
        var width = _measure(canvas, text, look.text) + 2 * _TOOLTIP_PADDING
        var height = look.text.font_size * 1.5 + _TOOLTIP_PADDING
        var widget = self._describe(index).rect
        # below the widget, or above it where that leaves more room
        var foot = canvas.to_local(Point(0, canvas.bottom())).y
        var head = canvas.to_local(Point(0, canvas.top())).y
        var below = widget.bottom() - _TOOLTIP_GAP - foot
        var above = head - widget.top() - _TOOLTIP_GAP
        var y = widget.bottom() - _TOOLTIP_GAP - height / 2
        if below < height and above > below:
            y = widget.top() + _TOOLTIP_GAP + height / 2
        # kept inside the canvas from side to side
        var left = canvas.to_local(Point(canvas.left(), 0)).x
        var right = canvas.to_local(Point(canvas.right(), 0)).x
        var x = clamp(
            widget.position.x,
            left + width / 2,
            max(right - width / 2, left + width / 2),
        )
        self._tip = _Tooltip(
            text,
            Rectangle(
                Point(x, y), width, height, corner_radius=look.box.corner_radius
            ),
            look^,
        )

    def _wheel_target(self, topmost: Optional[Int]) -> Optional[Int]:
        """The scroll area the mouse wheel scrolls: the innermost of those
        under the pointer whose column is taller than it, if any."""
        var at = topmost
        while at:
            var node = self._describe(at.value())
            if node.kind == _SCROLL_AREA and node.overflows:
                return at
            at = self._nodes[at.value()].parent
        return None

    def _topmost(self, pointer: Point) -> Optional[Int]:
        """The widget drawn last of those the pointer is over, of the ones
        that take the pointer: the one that reacts to it."""
        var order = self._drawing_order()
        # an open popup takes every pointer, so a click anywhere else only
        # closes it
        var p = len(order) - 1
        while p >= 0:
            if self._describe(order[p]).popup:
                return order[p]
            p -= 1
        var i = len(order) - 1
        while i >= 0:
            var node = self._describe(order[i])
            ref clip = self._nodes[order[i]].clip
            if (
                node.takes_pointer
                and node.rect.contains(pointer)
                and (not clip or clip.value().contains(pointer))
            ):
                return order[i]
            i -= 1
        return None

    def _drawing_order(self) -> List[Int]:
        """Every widget shown, a parent before what is inside it: the order
        they are drawn in. A hidden part of the tree is left out."""
        var order = List[Int](capacity=len(self._nodes))
        var pending = List[Int]()
        var r = len(self._roots) - 1
        while r >= 0:
            pending.append(self._roots[r])
            r -= 1
        while pending:
            var index = pending.pop()
            if not self._nodes[index].visible:
                continue  # hidden, with everything inside it
            order.append(index)
            ref children = self._nodes[index].children
            var c = len(children) - 1
            while c >= 0:
                pending.append(children[c])
                c -= 1
        return order^

    def draw_to(self, mut canvas: Canvas):
        for root in self._roots:
            self._draw_from(root, canvas)
        # what widgets draw over everything, such as an open dropdown's
        # list, outside any scroll area's window
        for index in self._drawing_order():
            if self._describe(index).popup:
                self._draw_popup(index, canvas)
        # the focus ring last, so nothing covers it, and no further than
        # the scroll areas it is in show
        if (
            self._focused
            and self._focus_visible
            and not self._hidden(self._focused.value())
        ):
            ref clip = self._nodes[self._focused.value()].clip
            if clip:
                with canvas.clip(clip.value()):
                    self._draw_ring(canvas)
            else:
                self._draw_ring(canvas)
        # the tooltip over everything, the ring included
        if self._tip:
            ref tip = self._tip.value()
            with canvas._with_style(tip.look.box):
                canvas.draw(tip.rect)
            with canvas._with_style(tip.look.text):
                canvas.draw(Text(tip.text, tip.rect.position))

    def _draw_from(self, index: Int, mut canvas: Canvas):
        """Draw the node at `index`, then what is inside it, in drawing
        order; what is inside a scroll area only in its window. A hidden node is
        left out, with what is inside it."""
        if not self._nodes[index].visible:
            return
        self._draw(index, canvas)
        var node = self._describe(index)
        if node.kind == _SCROLL_AREA:
            with canvas.clip(node.rect):
                for child in self._nodes[index].children:
                    self._draw_from(child, canvas)
        else:
            for child in self._nodes[index].children:
                self._draw_from(child, canvas)

    def _draw_ring(self, mut canvas: Canvas):
        """Draw the ring round the focused widget."""
        var node = self._describe(self._focused.value())
        var gap = self._focus_ring.gap
        with canvas._with_style(self._theme().ring()):
            if node.ring:
                ref shape = node.ring.value()
                var ring = shape.copy()
                ring.width += 2 * gap
                ring.height += 2 * gap
                ring.corner_radius = shape.corner_radius + gap
                canvas.draw(ring)
            elif node.ring_circle:
                ref circle = node.ring_circle.value()
                canvas.draw(Circle(circle.position, circle.radius + gap))

    # --------------------------------------------------------------- focus

    def tooltip[
        W: Copyable
    ](mut self, handle: WidgetHandle[W], text: Optional[String]):
        """Show `text` near the widget `handle` names while the pointer
        rests on it for half a second, or at once while it has focus from
        the keyboard or a gamepad; `None` takes its tooltip away.

        ```mojo
        # In `create`, after adding the `difficulty` choice group:
        ui.tooltip(difficulty, "How hard the enemies hit")
        ```

        A tooltip is drawn over everything, below the widget or above it
        where that leaves more room, and a press of the mouse hides it
        until the pointer leaves the widget. It never takes the pointer.
        """
        self._nodes[self._index_of(handle)].tooltip = text

    def tooltip[W: Copyable](self, handle: WidgetHandle[W]) -> Optional[String]:
        """The text of the widget's tooltip, if it has one."""
        return self._nodes[self._index_of(handle)].tooltip

    def scroll_to[W: Copyable](mut self, handle: WidgetHandle[W]):
        """Scroll each scroll area the widget `handle` names is in by the
        least that shows all of it, as moving focus onto it with Tab would.
        It takes effect at the tree's next `update`.

        ```mojo
        # In `update`: show the level just unlocked.
        if self.unlocked:
            self.ui.scroll_to(self.levels[self.next_level])
        ```
        """
        self._reveal = self._index_of(handle)

    def focus[W: Copyable](mut self, handle: WidgetHandle[W]):
        """Give the widget `handle` names focus, with its ring showing, as
        Tab would: a dialog gives its first field focus as it opens. A
        widget that can't take focus, such as a label, takes nothing."""
        var index = self._index_of(handle)
        if self._can_focus(index):
            self._focus_on(index, visible=True, from_gamepad=False)

    def clear_focus(mut self):
        """Take focus away from whatever has it, as Escape does."""
        self._focused = None
        self._focus_visible = False
        self._focus_from_gamepad = False

    def has_focus[W: Copyable](self, handle: WidgetHandle[W]) -> Bool:
        """Whether the widget `handle` names has focus."""
        var index = self._index_of(handle)
        return Bool(self._focused) and self._focused.value() == index

    def _focus_on(mut self, index: Int, *, visible: Bool, from_gamepad: Bool):
        self._focused = index
        self._focus_visible = visible
        self._focus_from_gamepad = from_gamepad
        # focus that shows is brought into view; a click's is in view already
        if visible:
            self._reveal = index

    def _navigate(mut self, mut context: Context, topmost: Optional[Int]):
        """Move focus for this frame's input, before any widget acts: away
        for Escape, a gamepad's east button or a click on nothing focusable;
        onto a clicked widget; along for Tab; and towards an arrow, while
        keys act on the focus, or a gamepad's push. First, though, do what
        a widget was asked for itself, such as `ui[field].focus()`, as
        `ui.focus` would. Then switch typing on while a text field has
        focus."""
        self._take_focus_requests()
        ref keyboard = context.keyboard
        var frame = context.frame_count()
        var keyboard_taken = keyboard._claim.held_by_other(
            self._claimant, frame
        )
        var mouse_taken = context.mouse._claim.held_by_other(
            self._claimant, frame
        )
        self._key_used = False
        if keyboard_taken and self._holds_keys():
            self.clear_focus()  # another tree has taken the keyboard
        if self._focused and not self._can_focus(self._focused.value()):
            self.clear_focus()  # disabled, or no longer a widget that can
        self._back = False
        if (
            self._focused
            and keyboard.pressed(Key.ESCAPE)
            and not keyboard_taken
        ):
            if self._captures():
                self._back = True  # for the widget to back out of
            else:
                self.clear_focus()
            self._key_used = True
        if context.mouse.pressed() and not mouse_taken:
            if topmost and self._can_focus(topmost.value()):
                self._focus_on(
                    topmost.value(), visible=False, from_gamepad=False
                )
            else:
                self.clear_focus()  # a click on nothing, or on a panel
        if keyboard.typed(Key.TAB) and not keyboard_taken:
            self._key_used = True
            self._tab(
                backwards=keyboard.down(Key.LEFT_SHIFT)
                or keyboard.down(Key.RIGHT_SHIFT)
            )
        self._arrow_moved = False
        if not keyboard_taken and self._holds_keys():
            var arrow = _arrow_push(keyboard)
            if arrow != Vector.ZERO and not self._takes_arrow(arrow):
                self._move_focus(arrow, from_gamepad=False)
                self._key_used = True
                self._arrow_moved = True
        var push = _pad_push(context, self._player, self._pad_repeat)
        self._pad_move = push
        if _pad_pressed(context, self._player, GamepadButton.EAST):
            if self._captures():
                self._back = True
            else:
                self.clear_focus()  # back out, as Escape does
        elif push != Vector.ZERO:
            if not self._focused or not self._adjusts(
                self._focused.value(), push
            ):
                self._move_focus(push, from_gamepad=True)
                # what focus lands on doesn't also take the push
                self._pad_move = Vector.ZERO
        var typing = (
            Bool(self._focused)
            and self._describe(self._focused.value()).takes_typing
        )
        if typing != self._typing_was:
            context.text_input(typing)
            self._typing_was = typing

    def _take_focus_requests(mut self):
        """Give focus to a widget the program asked for it, as `ui.focus`
        does, and take it from one asked to let go."""
        for index in self._drawing_order():
            var request = self._describe(index).focus_request
            if not request:
                continue
            if request.value():
                if self._can_focus(index):
                    self._focus_on(index, visible=True, from_gamepad=False)
            elif self._focused and self._focused.value() == index:
                self.clear_focus()

    def _focusable(self) -> List[Int]:
        """The widgets that can take focus, in the order they are drawn:
        the order Tab goes through them."""
        var focusable = List[Int]()
        for index in self._drawing_order():
            if self._can_focus(index):
                focusable.append(index)
        return focusable^

    def _tab(mut self, backwards: Bool):
        """Move focus to the next widget that can take it, or the previous
        one `backwards`; from no focus, to the first or the last. The order
        wraps round."""
        var order = self._focusable()
        if not order:
            return
        var at = -1
        if self._focused:
            for i in range(len(order)):
                if order[i] == self._focused.value():
                    at = i
                    break
        var next: Int
        if at == -1:
            next = len(order) - 1 if backwards else 0
        elif backwards:
            next = (at - 1 + len(order)) % len(order)
        else:
            next = (at + 1) % len(order)
        self._focus_on(order[next], visible=True, from_gamepad=False)

    def _takes_arrow(self, arrow: Vector) -> Bool:
        """Whether the focused widget takes `arrow` itself rather than
        letting it move focus: a text field takes every arrow, for its
        caret, and a widget the arrows along an axis it adjusts, as a
        slider takes left and right to step it."""
        var focused = self._focused.value()
        var node = self._describe(focused)
        return (
            node.takes_typing
            or node.captures_keys
            or self._adjusts(focused, arrow)
        )

    def _adjusts(self, index: Int, direction: Vector) -> Bool:
        """Whether the node at `index` takes a push or an arrow in
        `direction` itself, along an axis it adjusts, rather than letting
        it move focus."""
        var node = self._describe(index)
        if node.captures_keys:
            return True
        if direction.y == 0:
            return node.adjusts_x
        return direction.x == 0 and node.adjusts_y

    def _move_focus(mut self, direction: Vector, *, from_gamepad: Bool):
        """Move focus to the nearest widget in `direction`, judged from where
        the widgets are; from no focus, to the first."""
        var order = self._focusable()
        var centres = List[Point]()
        for index in order:
            centres.append(self._describe(index).rect.position)
        var at = Optional[Point](None)
        if self._focused:
            at = self._describe(self._focused.value()).rect.position
        var best = _nearest(at, direction, centres)
        if best:
            self._focus_on(
                order[best.value()], visible=True, from_gamepad=from_gamepad
            )

    def _focus_for(mut self, index: Int, context: Context) -> _Focus:
        """What the tree's focus means for the node at `index` this
        frame."""
        var focused = Bool(self._focused) and self._focused.value() == index
        var shown = focused and self._focus_visible
        # a widget that captures the keys has them however it got focus,
        # such as a dropdown opened by a click
        var captures = focused and self._describe(index).captures_keys
        ref keyboard = context.keyboard
        var keyboard_free = not keyboard._claim.held_by_other(
            self._claimant, context.frame_count()
        )
        var keys = (
            (shown and not self._focus_from_gamepad or captures)
            and keyboard_free
            and not self._arrow_moved
        )
        if keys and (
            keyboard.pressed(Key.ENTER)
            or keyboard.pressed(Key.SPACE)
            or keyboard.typed(Key.LEFT)
            or keyboard.typed(Key.RIGHT)
            or keyboard.typed(Key.UP)
            or keyboard.typed(Key.DOWN)
            or keyboard.pressed(Key.HOME)
            or keyboard.pressed(Key.END)
        ):
            self._key_used = True
        var activated = (
            keys
            and (keyboard.pressed(Key.ENTER) or keyboard.pressed(Key.SPACE))
        ) or (
            (shown or captures)
            and _pad_pressed(context, self._player, GamepadButton.SOUTH)
        )
        return _Focus(
            in_tree=True,
            focused=focused,
            keys=keys,
            activated=activated,
            push=self._pad_move if shown or captures else Vector.ZERO,
            back=focused and self._back,
        )

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
            self._place_from(root, None, None, context, canvas, theme, sizes)

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
        if node.kind == _COLUMN or node.kind == _ROW:
            # a widget with a size of its own keeps its place, and takes no
            # room in the column or row
            var placed = self._placed_children(index)
            var gap = node.gap.or_else(theme.spacing)
            for i in range(len(placed)):
                ref size = sizes[placed[i]]
                var between = gap if i > 0 else 0.0
                if node.kind == _COLUMN:
                    width = max(width, size[0])
                    height += size[1] + between
                else:
                    width += size[0] + between
                    height = max(height, size[1])
        elif node.kind == _SPACE:
            width = node.amount.or_else(2 * theme.spacing)
            height = width
        elif node.kind == _SCROLL_AREA:
            if _sized(node.rect):
                width = node.rect.width
                height = node.rect.height
            else:
                # as big as the column it shows, with room round it for a
                # focus ring, up to its `max_height`
                var margin = 2 * theme.ring_reach()
                for child in children:
                    if self._fills(child, index):
                        width = sizes[child][0] + margin
                        height = sizes[child][1] + margin
                if node.max_height:
                    height = min(height, node.max_height.value())
        elif node.kind == _PANEL:
            if _sized(node.rect):
                width = node.rect.width
                height = node.rect.height
            else:
                # fitted round the column or row it places
                for child in children:
                    if self._fills(child, index):
                        width = max(width, sizes[child][0])
                        height = max(height, sizes[child][1])
                var padding = node.padding.or_else(2 * theme.spacing)
                width += 2 * padding
                height += 2 * padding
        else:
            var reply = self._dispatch_mut(
                index, _MEASURE, context, canvas, theme, free=False
            )
            width = reply.width
            height = reply.height
        # the size `ui.add` was given wins over the one it prefers
        ref placement = self._nodes[index].placement
        sizes[index] = (
            placement.width.or_else(width),
            placement.height.or_else(height),
        )

    def _place_from(
        mut self,
        index: Int,
        slot: Optional[Rectangle],
        clip: Optional[Rectangle],
        mut context: Context,
        mut canvas: Canvas,
        theme: _Theme,
        sizes: List[Tuple[Float64, Float64]],
    ) raises:
        """Place the node at `index`: in `slot` when what it is in gives it
        one, at the size it prefers when it was added with none, and where
        it is otherwise; then what is inside it. `clip` is what of it can be
        seen, from the scroll areas it is in. A hidden node is left where it
        is."""
        if not self._nodes[index].visible:
            return
        self._nodes[index].clip = clip
        var node = self._describe(index)
        var rect = node.rect
        if slot:
            rect = slot.value()
        elif self._nodes[index].sized_by_ui:
            rect = Rectangle(
                node.rect.position, sizes[index][0], sizes[index][1]
            )
        var children = self._nodes[index].children.copy()
        # how far a scroll area's column runs, the room for a focus ring
        # above and below it included, to keep its offset within
        var content = 0.0
        for child in children:
            if node.kind == _SCROLL_AREA and self._fills(child, index):
                content = sizes[child][1] + 2 * theme.ring_reach()
        if slot or self._nodes[index].sized_by_ui or node.kind == _SCROLL_AREA:
            _ = self._dispatch_mut(
                index,
                _PLACE,
                context,
                canvas,
                theme,
                free=False,
                rect=rect,
                content=content,
            )
        if node.kind == _COLUMN or node.kind == _ROW:
            var placed = self._placed_children(index)
            var slots = List[Rectangle]()
            var gap = node.gap.or_else(theme.spacing)
            var column = node.kind == _COLUMN
            # along the column or row: what each starts from, and its grow
            var bases = List[Float64]()
            var grows = List[Float64]()
            for child in placed:
                bases.append(sizes[child][1] if column else sizes[child][0])
                grows.append(self._nodes[child].placement.grow)
            var lengths = _shares(
                bases, grows, rect.height if column else rect.width, gap
            )
            # from the top of a column, or the left of a row
            var at = rect.top() if column else rect.left()
            for length in lengths:
                if column:
                    slots.append(
                        Rectangle(
                            Point(rect.position.x, at - length / 2),
                            rect.width,
                            length,
                        )
                    )
                    at -= length + gap
                else:
                    slots.append(
                        Rectangle(
                            Point(at + length / 2, rect.position.y),
                            length,
                            rect.height,
                        )
                    )
                    at += length + gap
            var next = 0
            for child in children:
                var given: Optional[Rectangle] = None
                ref child_node = self._nodes[child]
                if child_node.sized_by_ui and child_node.visible:
                    # across: stretched, or set by its own or the
                    # column's or row's `align`
                    ref placement = child_node.placement
                    given = _across(
                        slots[next],
                        sizes[child][0] if column else sizes[child][1],
                        placement.align if placement.align else node.align,
                        Bool(placement.width) if column else Bool(
                            placement.height
                        ),
                        column,
                    )
                    next += 1
                self._place_from(
                    child, given, clip, context, canvas, theme, sizes
                )
        elif node.kind == _PANEL:
            var inside = rect.inset(node.padding.or_else(2 * theme.spacing))
            for child in children:
                var given: Optional[Rectangle] = None
                if self._fills(child, index):
                    given = inside
                self._place_from(
                    child, given, clip, context, canvas, theme, sizes
                )
        elif node.kind == _SCROLL_AREA:
            # the column, as tall as its widgets, moved up by the offset;
            # what is inside sees no more than the window
            var described = self._describe(index)
            var offset = described.offset
            # the column leaves room for the bar while it is taller, and for
            # a focus ring all round
            var bar = theme.scroll_bar_width() if described.overflows else 0.0
            var reach = theme.ring_reach()
            var window = _overlap(clip.value(), rect) if clip else rect
            for child in children:
                var given: Optional[Rectangle] = None
                if self._fills(child, index):
                    given = Rectangle(
                        Point(
                            rect.position.x - bar / 2,
                            rect.top() + offset - content / 2,
                        ),
                        rect.width - bar - 2 * reach,
                        content - 2 * reach,
                    )
                self._place_from(
                    child, given, window, context, canvas, theme, sizes
                )
        else:
            for child in children:
                self._place_from(
                    child, None, clip, context, canvas, theme, sizes
                )

    def _placed_children(self, index: Int) -> List[Int]:
        """The children a column or row at `index` places: those shown and
        added with no size of their own. The rest keep their place."""
        var placed = List[Int]()
        for child in self._nodes[index].children:
            ref node = self._nodes[child]
            if node.sized_by_ui and node.visible:
                placed.append(child)
        return placed^

    def _fills(self, index: Int, parent: Int) -> Bool:
        """Whether the node at `index` is the one its `parent` places: a
        column or row added with no size of its own inside a panel, or such
        a column inside a scroll area."""
        var kind = self._describe(index).kind
        ref node = self._nodes[index]
        if not node.sized_by_ui or not node.visible:
            return False
        if self._describe(parent).kind == _SCROLL_AREA:
            return kind == _COLUMN
        return kind == _COLUMN or kind == _ROW

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
            ref button = widget[Button]
            var described = _Description(_WIDGET, button.rect, True)
            described.focusable = button.enabled
            described.ring = button._ring()
            described.held = button.down()
            return described^
        if widget.isa[Checkbox]():
            ref checkbox = widget[Checkbox]
            var described = _Description(_WIDGET, checkbox.rect, True)
            described.focusable = checkbox.enabled
            described.ring = checkbox._ring()
            described.held = checkbox.down()
            return described^
        if widget.isa[Switch]():
            ref switch = widget[Switch]
            var described = _Description(_WIDGET, switch.rect, True)
            described.focusable = switch.enabled
            described.ring = switch._ring()
            described.held = switch.down()
            return described^
        if widget.isa[ChoiceGroup]():
            ref group = widget[ChoiceGroup]
            var described = _Description(_WIDGET, group.rect, True)
            described.focusable = group.enabled
            described.adjusts_y = True
            described.ring_circle = group._ring()
            described.held = group.down()
            return described^
        if widget.isa[Tabs]():
            ref tabs = widget[Tabs]
            var described = _Description(_WIDGET, tabs.rect, True)
            described.focusable = tabs.enabled
            described.adjusts_x = True
            described.ring = tabs._ring()
            described.held = tabs.down()
            return described^
        if widget.isa[Slider]():
            ref slider = widget[Slider]
            var described = _Description(_WIDGET, slider.rect, True)
            described.focusable = slider.enabled
            described.adjusts_x = True
            described.ring_circle = slider._ring()
            described.held = slider.down()
            return described^
        if widget.isa[TextField]():
            ref field = widget[TextField]
            var described = _Description(_WIDGET, field.rect, True)
            described.focusable = field.enabled
            described.takes_typing = True
            described.held = field.down()
            described.focus_request = field._focus_request
            return described^
        if widget.isa[NumberField]():
            ref number = widget[NumberField]
            var described = _Description(_WIDGET, number.rect, True)
            described.focusable = number.enabled
            described.takes_typing = True
            described.adjusts_y = True
            described.held = number.down()
            return described^
        if widget.isa[Dropdown]():
            ref dropdown = widget[Dropdown]
            var described = _Description(_WIDGET, dropdown.rect, True)
            described.focusable = dropdown.enabled
            described.ring = dropdown._ring()
            # an open list holds the mouse, so another tree leaves it alone
            described.held = dropdown.down() or dropdown.is_open()
            described.popup = dropdown._popup()
            described.captures_keys = dropdown.is_open()
            return described^
        if widget.isa[Panel]():
            # covers what is beneath it
            ref panel = widget[Panel]
            var described = _Description(_PANEL, panel.rect, True)
            described.padding = panel.padding
            return described^
        if widget.isa[ProgressBar]():
            # the pointer passes through it, as through text
            return _Description(_WIDGET, widget[ProgressBar].rect, False)
        if widget.isa[Label]():
            # the pointer passes through text
            return _Description(_WIDGET, widget[Label].rect, False)
        if widget.isa[Picture]():
            return _Description(_WIDGET, widget[Picture].bounds(), False)
        if widget.isa[Column]():
            ref column = widget[Column]
            var described = _Description(_COLUMN, column.rect, False)
            described.gap = column.gap
            described.align = column.align
            return described^
        if widget.isa[Row]():
            ref row = widget[Row]
            var described = _Description(_ROW, row.rect, False)
            described.gap = row.gap
            described.align = row.align
            return described^
        if widget.isa[ScrollArea]():
            ref area = widget[ScrollArea]
            # covers what is beneath it, so the wheel scrolls it anywhere
            var described = _Description(_SCROLL_AREA, area.rect, True)
            described.offset = area.offset
            described.max_height = area.max_height
            described.overflows = area._overflows()
            described.room = area._room()
            described.held = area._pointer.held
            return described^
        # no size of its own: the column or row it is in sizes it
        var described = _Description(
            _SPACE, Rectangle(Point(0.0, 0.0), 0.0, 0.0), False
        )
        described.amount = widget[Space].amount
        return described^

    def _draw_popup(self, index: Int, mut canvas: Canvas):
        """Draw what the node at `index` draws over everything else."""
        ref widget = self._nodes[index].widget
        if widget.isa[Dropdown]():
            widget[Dropdown]._draw_list(canvas)

    def _draw(self, index: Int, mut canvas: Canvas):
        """Draw the node at `index`: a scroll area its bar; a column, row or
        space nothing."""
        ref widget = self._nodes[index].widget
        if widget.isa[Button]():
            canvas.draw(widget[Button])
        elif widget.isa[Checkbox]():
            canvas.draw(widget[Checkbox])
        elif widget.isa[Switch]():
            canvas.draw(widget[Switch])
        elif widget.isa[ChoiceGroup]():
            canvas.draw(widget[ChoiceGroup])
        elif widget.isa[Tabs]():
            canvas.draw(widget[Tabs])
        elif widget.isa[Slider]():
            canvas.draw(widget[Slider])
        elif widget.isa[TextField]():
            canvas.draw(widget[TextField])
        elif widget.isa[NumberField]():
            canvas.draw(widget[NumberField])
        elif widget.isa[Dropdown]():
            widget[Dropdown]._draw_field(canvas)  # its list comes later
        elif widget.isa[Panel]():
            canvas.draw(widget[Panel])
        elif widget.isa[Label]():
            canvas.draw(widget[Label])
        elif widget.isa[ProgressBar]():
            canvas.draw(widget[ProgressBar])
        elif widget.isa[ScrollArea]():
            widget[ScrollArea]._draw_bar(canvas)
        elif widget.isa[Picture]():
            if self._disabled(index):
                canvas.draw(
                    widget[Picture],
                    Style(opacity=self._state_layers.disabled_content),
                )
            else:
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
        focus: _Focus = _Focus.standalone(),
        disabled: Bool = False,
        rect: Rectangle = Rectangle(Point(0.0, 0.0), 0.0, 0.0),
        content: Float64 = 0,
        wheel: Bool = False,
    ) raises -> _Reply:
        """Update (`_UPDATE`), measure (`_MEASURE`) or place in `rect`
        (`_PLACE`, onto a column `content` tall for a scroll area) the node
        at `index`, or scroll it to `content` (`_SCROLL_TO`, a scroll area),
        in `theme`; `free` when it is the topmost under the pointer, and
        `wheel` when it is the scroll area the wheel scrolls. Gives back the
        look of what sits on it and, when measuring, the size it prefers."""
        var reply = _Reply(theme.copy(), 0.0, 0.0, False)
        ref widget = self._nodes[index].widget
        if widget.isa[Button]():
            ref button = widget[Button]
            if action == _UPDATE:
                button._update(
                    context,
                    canvas,
                    theme,
                    free=free,
                    focus=focus,
                    disabled=disabled,
                )
            elif action == _MEASURE:
                reply.width, reply.height = button._measure(canvas, theme)
            else:
                button.rect = rect
        elif widget.isa[Checkbox]():
            ref checkbox = widget[Checkbox]
            if action == _UPDATE:
                checkbox._update(
                    context,
                    canvas,
                    theme,
                    free=free,
                    focus=focus,
                    disabled=disabled,
                )
            elif action == _MEASURE:
                reply.width, reply.height = checkbox._measure(canvas, theme)
            else:
                checkbox.rect = rect
        elif widget.isa[Switch]():
            ref switch = widget[Switch]
            if action == _UPDATE:
                switch._update(
                    context,
                    canvas,
                    theme,
                    free=free,
                    focus=focus,
                    disabled=disabled,
                )
            elif action == _MEASURE:
                reply.width, reply.height = switch._measure(canvas, theme)
            else:
                switch.rect = rect
        elif widget.isa[ChoiceGroup]():
            ref group = widget[ChoiceGroup]
            if action == _UPDATE:
                group._update(
                    context,
                    canvas,
                    theme,
                    free=free,
                    focus=focus,
                    disabled=disabled,
                )
            elif action == _MEASURE:
                reply.width, reply.height = group._measure(canvas, theme)
            else:
                group.rect = rect
        elif widget.isa[Tabs]():
            ref tabs = widget[Tabs]
            if action == _UPDATE:
                tabs._update(
                    context,
                    canvas,
                    theme,
                    free=free,
                    focus=focus,
                    disabled=disabled,
                )
            elif action == _MEASURE:
                reply.width, reply.height = tabs._measure(canvas, theme)
            else:
                tabs.rect = rect
        elif widget.isa[NumberField]():
            ref number = widget[NumberField]
            if action == _UPDATE:
                number._update(
                    context,
                    canvas,
                    theme,
                    free=free,
                    focus=focus,
                    disabled=disabled,
                )
            elif action == _MEASURE:
                reply.width, reply.height = number._measure(canvas, theme)
            else:
                number.rect = rect
        elif widget.isa[Dropdown]():
            ref dropdown = widget[Dropdown]
            if action == _UPDATE:
                dropdown._update(
                    context,
                    canvas,
                    theme,
                    free=free,
                    focus=focus,
                    disabled=disabled,
                )
            elif action == _MEASURE:
                reply.width, reply.height = dropdown._measure(canvas, theme)
            else:
                dropdown.rect = rect
        elif widget.isa[Slider]():
            ref slider = widget[Slider]
            if action == _UPDATE:
                slider._update(
                    context,
                    canvas,
                    theme,
                    free=free,
                    focus=focus,
                    disabled=disabled,
                )
            elif action == _MEASURE:
                reply.width, reply.height = slider._measure(canvas, theme)
            else:
                slider.rect = rect
        elif widget.isa[TextField]():
            ref field = widget[TextField]
            if action == _UPDATE:
                field._update(
                    context,
                    canvas,
                    theme,
                    free=free,
                    focus=focus,
                    disabled=disabled,
                )
            elif action == _MEASURE:
                reply.width, reply.height = field._measure(canvas, theme)
            else:
                field.rect = rect
        elif widget.isa[Label]():
            ref label = widget[Label]
            if action == _UPDATE:
                label._update(context, canvas, theme, disabled=disabled)
            elif action == _MEASURE:
                reply.width, reply.height = label._measure(canvas, theme)
            else:
                label.rect = rect
        elif widget.isa[ProgressBar]():
            ref bar = widget[ProgressBar]
            if action == _UPDATE:
                bar._update(context, canvas, theme, disabled=disabled)
            elif action == _MEASURE:
                reply.width, reply.height = bar._measure(canvas, theme)
            else:
                bar.rect = rect
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
        elif widget.isa[ScrollArea]():
            ref area = widget[ScrollArea]
            if action == _UPDATE:
                area._update(
                    context,
                    canvas,
                    theme,
                    free=free,
                    wheel=wheel,
                    disabled=disabled,
                )
                reply.scrolled = area._scrolled
            elif action == _PLACE:
                area._place(rect, content, theme.scroll_bar_width())
            elif action == _SCROLL_TO:
                area.offset = content
        return reply^


def _drop(mut indices: List[Int], index: Int):
    """Take `index` out of `indices`, where it is once."""
    for i in range(len(indices)):
        if indices[i] == index:
            _ = indices.pop(i)
            return
