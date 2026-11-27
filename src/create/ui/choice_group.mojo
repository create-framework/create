"""`ChoiceGroup`: one of a few options, all shown, each a circle with its
text."""

from create.app import Context
from create.geometry import Circle, Line, Rectangle
from create.input import Key
from create.math import Point
from create.render import Canvas, Style, Text
from ._pointer import _Pointer
from .checkbox import _TEXT_GAP
from create.color.color_scheme import ColorScheme
from ._theme import _ChoiceGroupLook, _Theme
from ._layout import _UNSIZED
from .text_field import _measure
from ._navigation import _Focus
from .clickable import Clickable
from .widget import Widget


comptime _CIRCLE_RADIUS = 10.0
"""How big an option's circle is."""


struct ChoiceGroup(Clickable, Copyable, Movable, Widget):
    """A few options, one under the other, of which one is chosen: each a
    circle with its text, the chosen one's circle with a dot in it. Other
    toolkits call these radio buttons.

    ```mojo
    # In `create`, building the `difficulty` field:
    var difficulty = ChoiceGroup(
        ["Easy", "Normal", "Hard"], Rectangle((0, 0), 200, 120), selected=1
    )

    # In `update`:
    self.difficulty.update(context, canvas)
    canvas.draw(self.difficulty)
    if self.difficulty.changed():
        self.start_level(self.difficulty.selected)
    ```

    A click on an option chooses it. In a `UI`, the up and down arrows and
    a gamepad's push move the choice while it has focus. Each option takes
    an equal share of its rectangle's height, the first at the top. A
    `Dropdown` suits a longer list, and a column of `Checkbox`es suits
    choosing several.

    Each part is a shape drawn in a style of its own: `circle` is each
    option's circle, an outline unless its style fills it;
    `selected_circle` is the chosen option's, taking what it leaves unset
    from `circle`; `dot` is a point in the chosen circle, so its stroke is
    its colour and its `stroke_thickness` its diameter; and `text_style` is
    the options' text.
    """

    var options: List[String]
    """The options' text, the first at the top."""
    var rect: Rectangle
    """Where it is: the options share its height, their circles against
    its left edge."""
    var selected: Int
    """Which option is chosen, counted from 0 at the top. Set it to choose
    one from the program; outside the options, none is."""
    var circle: Style
    """Each option's circle: an outline unless its style fills it."""
    var selected_circle: Style
    """The chosen option's circle, taking what it leaves unset from
    `circle`."""
    var dot: Style
    """The dot in the chosen circle, a point: its stroke is its colour,
    and its `stroke_thickness` its diameter."""
    var text_style: Style
    """The options' text."""
    var enabled: Bool
    """Whether it reacts to the mouse. A disabled group is faded."""
    var _pointer: _Pointer
    var _pressed_option: Int
    """The option the mouse was pressed on, so a click chooses only where
    it was both pressed and let go."""
    var _hovered_option: Int
    """The option under the pointer, or -1."""
    var _changed: Bool
    var _look: _ChoiceGroupLook

    def __init__(
        out self,
        var options: List[String],
        rect: Rectangle = _UNSIZED,
        *,
        selected: Int = 0,
        circle: Style = Style(),
        selected_circle: Style = Style(),
        dot: Style = Style(),
        text_style: Style = Style(),
        enabled: Bool = True,
    ):
        self.options = options^
        self.rect = rect
        self.selected = selected
        self.circle = circle
        self.selected_circle = selected_circle
        self.dot = dot
        self.text_style = text_style
        self.enabled = enabled
        self._pointer = _Pointer()
        self._pressed_option = -1
        self._hovered_option = -1
        self._changed = False
        self._look = _Theme.default().choice_group(
            circle,
            selected_circle,
            dot,
            text_style,
            hovered=False,
            pressed=False,
            disabled=not enabled,
        )

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        """Read what the mouse did to it this frame, choosing the option
        clicked, and work out its look: call it before drawing it.

        It is drawn in the canvas's colours,
        `canvas.colors()`."""
        self._update(
            context, canvas, _Theme.default(canvas.colors()), free=True
        )

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
        var under = self._option_at(pointer) if self._pointer.hovered else -1
        self._hovered_option = under
        if self._pointer.pressed:
            self._pressed_option = under
        var before = self.selected
        if self._pointer.released and under == self._pressed_option:
            self.selected = under
        if enabled and self.options:
            # up moves the choice to the option above, down to the one below
            var by = 0
            if focus.keys:
                if context.keyboard.typed(Key.UP):
                    by = -1
                elif context.keyboard.typed(Key.DOWN):
                    by = 1
            if focus.push.y > 0:
                by = -1
            elif focus.push.y < 0:
                by = 1
            if by != 0:
                var last = len(self.options) - 1
                if self.selected < 0 or self.selected > last:
                    self.selected = 0 if by > 0 else last
                else:
                    self.selected = min(max(self.selected + by, 0), last)
        self._changed = self.selected != before
        self._look = theme.choice_group(
            self.circle,
            self.selected_circle,
            self.dot,
            self.text_style,
            hovered=self._pointer.hovered,
            pressed=self._pointer.looks_pressed(),
            disabled=not enabled,
        )

    def _measure(
        self, mut canvas: Canvas, theme: _Theme
    ) raises -> Tuple[Float64, Float64]:
        """The size it prefers in `theme`: its circles, the gap and its
        widest option, and `control_height` for each option."""
        var look = theme.choice_group(
            self.circle,
            self.selected_circle,
            self.dot,
            self.text_style,
            hovered=False,
            pressed=False,
            disabled=False,
        )
        var widest = 0.0
        for option in self.options:
            widest = max(widest, _measure(canvas, option, look.text))
        return (
            2 * _CIRCLE_RADIUS + _TEXT_GAP + widest,
            theme.control_height * Float64(len(self.options)),
        )

    def _option_height(self) -> Float64:
        """How tall each option is: an equal share of its height."""
        if not self.options:
            return 0.0
        return self.rect.height / Float64(len(self.options))

    def _option_at(self, point: Point) -> Int:
        """The option `point` is on, by height, or -1 off them all."""
        var height = self._option_height()
        if height <= 0:
            return -1
        var i = Int((self.rect.top() - point.y) / height)
        if i < 0 or i >= len(self.options):
            return -1
        return i

    def _circle_at(self, option: Int) -> Circle:
        """The circle of the option counted `option` from the top."""
        var y = (
            self.rect.top() - (Float64(option) + 0.5) * self._option_height()
        )
        return Circle(
            Point(self.rect.left() + _CIRCLE_RADIUS, y), _CIRCLE_RADIUS
        )

    def _ring(self) -> Circle:
        """The shape its focus ring goes round: the chosen option's circle,
        or the first's when none is chosen."""
        if self.selected >= 0 and self.selected < len(self.options):
            return self._circle_at(self.selected)
        return self._circle_at(0)

    def selected_text(self) -> String:
        """The chosen option's text, or an empty string when none is."""
        if self.selected >= 0 and self.selected < len(self.options):
            return self.options[self.selected]
        return ""

    def changed(self) -> Bool:
        """Whether its last `update` chose another option."""
        return self._changed

    def hovered(self) -> Bool:
        """Whether the pointer is over it, as of its last `update`."""
        return self._pointer.hovered

    def pressed(self) -> Bool:
        """Whether the left button went down over it this frame."""
        return self._pointer.pressed

    def down(self) -> Bool:
        """Whether it is held: pressed on it, and the button not let go
        since, wherever the pointer has moved."""
        return self._pointer.held

    def released(self) -> Bool:
        """Whether it was clicked this frame: let go over it, after being
        pressed on it."""
        return self._pointer.released

    def draw_to(self, mut canvas: Canvas):
        for i in range(len(self.options)):
            var circle = self._circle_at(i)
            if i == self._hovered_option:
                # a halo behind the option under the pointer
                with canvas._with_style(self._look.halo):
                    canvas.draw(Circle(circle.position, 2 * _CIRCLE_RADIUS))
            if i == self.selected:
                with canvas._with_style(self._look.selected_circle):
                    canvas.draw(circle)
                with canvas._with_style(self._look.dot):
                    canvas.draw(Line(circle.position, circle.position))
            else:
                with canvas._with_style(self._look.circle):
                    canvas.draw(circle)
            with canvas._with_style(self._look.text):
                canvas.draw(
                    Text(
                        self.options[i],
                        Point(
                            self.rect.left() + 2 * _CIRCLE_RADIUS + _TEXT_GAP,
                            circle.position.y,
                        ),
                    )
                )
