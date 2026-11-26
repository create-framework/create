"""`Tabs`: a row of tabs, one selected, for switching between pages."""

from create.app import Context
from create.geometry import Line, Rectangle
from create.input import Key
from create.math import Point
from create.render import Canvas, Style, Text
from ._pointer import _Pointer
from .color_scheme import ColorScheme
from ._theme import _TabsLook, _Theme
from ._layout import _UNSIZED
from .text_field import _measure
from ._navigation import _Focus
from .clickable import Clickable
from .widget import Widget


comptime _TAB_PADDING = 24.0
"""The room a tab leaves either side of its text."""


struct Tabs(Clickable, Copyable, Movable, Widget):
    """A row of tabs, one of them selected, for switching between pages of
    a menu: the selected one's text in the accent colour, with a line
    beneath it.

    ```mojo
    # In `create`, building the `ui` field: a page for each tab.
    var tabs = ui.add(Tabs(["General", "Audio"]), column)
    var general = ui.add(Column(), column)
    var audio = ui.add(Column(), column)
    ui.visible(audio, False)

    # In `update`: show the selected tab's page.
    if self.ui[self.tabs].changed():
        var selected = self.ui[self.tabs].selected
        self.ui.visible(self.general, selected == 0)
        self.ui.visible(self.audio, selected == 1)
    ```

    A click on a tab selects it. In a `UI`, the left and right arrows and
    a gamepad's push move the selection while it has focus. The tabs share
    its width equally, the first at the left.

    Each part is a shape drawn in a style of its own: `tab` is each tab, a
    rectangle with its text, with no fill or outline unless its style
    gives one; `selected_tab` is the selected one, taking what it leaves
    unset from `tab`; and `indicator` is the line beneath the selected tab,
    so its stroke is its colour and thickness.
    """

    var options: List[String]
    """The tabs' text, the first at the left."""
    var rect: Rectangle
    """Where it is: the tabs share its width."""
    var selected: Int
    """Which tab is selected, counted from 0 at the left. Set it to select
    one from the program; outside the tabs, none is."""
    var tab: Style
    var selected_tab: Style
    var indicator: Style
    var enabled: Bool
    """Whether it reacts to the mouse. Disabled tabs are faded."""
    var _pointer: _Pointer
    var _pressed_tab: Int
    """The tab the mouse was pressed on, so a click selects only where it
    was both pressed and let go."""
    var _hovered_tab: Int
    """The tab under the pointer, or -1."""
    var _changed: Bool
    var _look: _TabsLook

    def __init__(
        out self,
        var options: List[String],
        rect: Rectangle = _UNSIZED,
        *,
        selected: Int = 0,
        tab: Style = Style(),
        selected_tab: Style = Style(),
        indicator: Style = Style(),
        enabled: Bool = True,
    ):
        self.options = options^
        self.rect = rect
        self.selected = selected
        self.tab = tab
        self.selected_tab = selected_tab
        self.indicator = indicator
        self.enabled = enabled
        self._pointer = _Pointer()
        self._pressed_tab = -1
        self._hovered_tab = -1
        self._changed = False
        self._look = _Theme.default().tabs(
            tab,
            selected_tab,
            indicator,
            hovered=False,
            pressed=False,
            disabled=not enabled,
        )

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        """Read what the mouse did to it this frame, selecting the tab
        clicked, and work out its look: call it before drawing it.

        It is drawn in the light colours; give it others with `colors`."""
        self._update(context, canvas, _Theme.default(), free=True)

    def update(
        mut self,
        mut context: Context,
        mut canvas: Canvas,
        *,
        colors: ColorScheme,
    ) raises:
        """`update`, drawn in `colors`, such as `ColorScheme.dark()` on a
        dark screen."""
        self._update(context, canvas, _Theme.default(colors), free=True)

    def _update(
        mut self,
        mut context: Context,
        mut canvas: Canvas,
        theme: _Theme,
        *,
        free: Bool,
        focus: _Focus = _Focus.standalone(),
        disabled: Bool = False,
    ) raises:
        """`update` in `theme`, as a `UI` updates it; `free` is false when
        another widget is over it at the pointer, and `focus` is what the
        `UI`'s focus means for it, and `disabled` disables it as part of a
        disabled part of the `UI`, whatever its own `enabled`."""
        var enabled = self.enabled and not disabled
        var pointer = canvas.to_local(context.mouse.position)
        self._pointer.update(
            context.mouse,
            self.rect.contains(pointer),
            free=free,
            enabled=enabled,
        )
        var under = self._tab_at(pointer) if self._pointer.hovered else -1
        self._hovered_tab = under
        if self._pointer.pressed:
            self._pressed_tab = under
        var before = self.selected
        if self._pointer.released and under == self._pressed_tab:
            self.selected = under
        if enabled and self.options:
            # left selects the tab before, right the one after
            var by = 0
            if focus.keys:
                if context.keyboard.typed(Key.LEFT):
                    by = -1
                elif context.keyboard.typed(Key.RIGHT):
                    by = 1
            if focus.push.x < 0:
                by = -1
            elif focus.push.x > 0:
                by = 1
            if by != 0:
                var last = len(self.options) - 1
                if self.selected < 0 or self.selected > last:
                    self.selected = 0 if by > 0 else last
                else:
                    self.selected = min(max(self.selected + by, 0), last)
        self._changed = self.selected != before
        self._look = theme.tabs(
            self.tab,
            self.selected_tab,
            self.indicator,
            hovered=self._pointer.hovered,
            pressed=self._pointer.looks_pressed(),
            disabled=not enabled,
        )

    def _measure(
        self, mut canvas: Canvas, theme: _Theme
    ) raises -> Tuple[Float64, Float64]:
        """The size it prefers in `theme`: as many tabs as it has, each as
        wide as the widest tab's text with room either side, and
        `control_height` tall."""
        var look = theme.tabs(
            self.tab,
            self.selected_tab,
            self.indicator,
            hovered=False,
            pressed=False,
            disabled=False,
        )
        var widest = 0.0
        for option in self.options:
            widest = max(widest, _measure(canvas, option, look.selected_text))
        return (
            (widest + 2 * _TAB_PADDING) * Float64(len(self.options)),
            theme.control_height,
        )

    def _tab_width(self) -> Float64:
        """How wide each tab is: an equal share of its width."""
        if not self.options:
            return 0.0
        return self.rect.width / Float64(len(self.options))

    def _tab_at(self, point: Point) -> Int:
        """The tab `point` is on, by width, or -1 off them all."""
        var width = self._tab_width()
        if width <= 0:
            return -1
        var i = Int((point.x - self.rect.left()) / width)
        if i < 0 or i >= len(self.options):
            return -1
        return i

    def _tab_rect(self, tab: Int) -> Rectangle:
        """The rectangle of the tab counted `tab` from the left."""
        var width = self._tab_width()
        return Rectangle(
            Point(
                self.rect.left() + (Float64(tab) + 0.5) * width,
                self.rect.position.y,
            ),
            width,
            self.rect.height,
            corner_radius=self._look.tab.corner_radius,
        )

    def _ring(self) -> Rectangle:
        """The shape its focus ring goes round: the selected tab, or the
        first when none is selected."""
        if self.selected >= 0 and self.selected < len(self.options):
            return self._tab_rect(self.selected)
        return self._tab_rect(0)

    def selected_text(self) -> String:
        """The selected tab's text, or an empty string when none is."""
        if self.selected >= 0 and self.selected < len(self.options):
            return self.options[self.selected]
        return ""

    def changed(self) -> Bool:
        """Whether its last `update` selected another tab."""
        return self._changed

    def hovered(self) -> Bool:
        return self._pointer.hovered

    def pressed(self) -> Bool:
        return self._pointer.pressed

    def down(self) -> Bool:
        return self._pointer.held

    def released(self) -> Bool:
        return self._pointer.released

    def draw_to(self, mut canvas: Canvas):
        for i in range(len(self.options)):
            var area = self._tab_rect(i)
            var selected = i == self.selected
            with canvas._with_style(
                self._look.selected_tab if selected else self._look.tab
            ):
                canvas.draw(area)
            if i == self._hovered_tab:
                # a layer over the tab under the pointer
                with canvas._with_style(self._look.layer):
                    canvas.draw(area)
            with canvas._with_style(
                self._look.selected_text if selected else self._look.text
            ):
                canvas.draw(Text(self.options[i], area.position))
            if selected:
                # the indicator along the tab's foot, inside it
                var inset = self._look.indicator.stroke_thickness / 2
                var y = area.bottom() + inset
                with canvas._with_style(self._look.indicator):
                    canvas.draw(
                        Line(
                            Point(area.left(), y),
                            Point(area.right(), y),
                        )
                    )
