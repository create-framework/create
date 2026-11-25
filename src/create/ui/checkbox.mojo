"""`Checkbox`: a box the mouse ticks and unticks, with text beside it."""

from create.core import Context
from create.geometry import Line, Rectangle
from create.math import Point, Vector
from create.render import Align, Canvas, Style, Text
from ._pointer import _Pointer
from ._theme import _CheckboxLook, _Theme
from .layout import _UNSIZED
from .text_field import _measure
from ._navigation import _Focus
from .widget import Clickable, Widget


comptime _BOX_SIZE = 18.0
"""How wide and tall a checkbox's box is."""

comptime _TEXT_GAP = 12.0
"""The gap between a checkbox's box and its text."""


struct Checkbox(Clickable, Copyable, Movable, Widget):
    """A box against the left edge of a rectangle, ticked while `checked`,
    with text beside it. A click anywhere in the rectangle ticks or unticks
    it.

    ```mojo
    # In `create`, building the `music` field:
    var music = Checkbox("Music", Rectangle((0, 0), 200, 32), checked=True)

    # In `update`:
    self.music.update(context, canvas)
    canvas.draw(self.music)
    if self.music.changed():
        self.audio.volume(1.0 if self.music.checked else 0.0)
    ```

    Each part is a shape drawn in a style of its own: `box` is the empty
    box, an outline unless its style fills it; `checked_box` is the ticked
    box, filled, taking what it leaves unset from `box`; `tick` is the lines
    of the tick, so its stroke is their colour and width; and `text_style`
    is the text's.
    """

    var text: String
    """The text beside the box."""
    var rect: Rectangle
    """Where it is: the box against its left edge, and the area a click
    ticks it in."""
    var checked: Bool
    """Whether it is ticked. Set it to tick it from the program."""
    var box: Style
    var checked_box: Style
    var tick: Style
    var text_style: Style
    var enabled: Bool
    """Whether it reacts to the mouse. A disabled checkbox is faded."""
    var _pointer: _Pointer
    var _changed: Bool
    var _look: _CheckboxLook

    def __init__(
        out self,
        text: String,
        rect: Rectangle = _UNSIZED,
        *,
        checked: Bool = False,
        box: Style = Style(),
        checked_box: Style = Style(),
        tick: Style = Style(),
        text_style: Style = Style(),
        enabled: Bool = True,
    ):
        self.text = text
        self.rect = rect
        self.checked = checked
        self.box = box
        self.checked_box = checked_box
        self.tick = tick
        self.text_style = text_style
        self.enabled = enabled
        self._pointer = _Pointer()
        self._changed = False
        self._look = _Theme.default().checkbox(
            box,
            checked_box,
            tick,
            text_style,
            checked=checked,
            hovered=False,
            pressed=False,
            disabled=not enabled,
        )

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        """Read what the mouse did to it this frame, ticking or unticking it
        on a click, and work out its look: call it before drawing it."""
        self._update(context, canvas, _Theme.default(), free=True)

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
        self._changed = self._pointer.released or (focus.activated and enabled)
        if self._changed:
            self.checked = not self.checked
        self._look = theme.checkbox(
            self.box,
            self.checked_box,
            self.tick,
            self.text_style,
            checked=self.checked,
            hovered=self._pointer.hovered,
            pressed=self._pointer.looks_pressed(),
            disabled=not enabled,
        )

    def _measure(
        self, mut canvas: Canvas, theme: _Theme
    ) raises -> Tuple[Float64, Float64]:
        """The size it prefers in `theme`: its box, the gap and its text,
        `control_height` tall."""
        var look = theme.checkbox(
            self.box,
            self.checked_box,
            self.tick,
            self.text_style,
            checked=self.checked,
            hovered=False,
            pressed=False,
            disabled=False,
        )
        var width = _measure(canvas, self.text, look.text)
        return (_BOX_SIZE + _TEXT_GAP + width, theme.control_height)

    def _ring(self) -> Rectangle:
        """The shape its focus ring goes round: its box."""
        return _checkbox_box(self.rect, self._look.box.corner_radius)

    def changed(self) -> Bool:
        """Whether its last `update` ticked or unticked it."""
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
        var box = _checkbox_box(self.rect, self._look.box.corner_radius)
        with canvas._with_style(self._look.box):
            canvas.draw(box)
        if self.checked:
            var lines = _tick_lines(box.position)
            with canvas._with_style(self._look.tick):
                canvas.draw(lines[0])
                canvas.draw(lines[1])
        with canvas._with_style(self._look.text):
            canvas.draw(Text(self.text, _checkbox_text_at(self.rect)))


def _checkbox_box(rect: Rectangle, corner_radius: Float64) -> Rectangle:
    """A checkbox's box: against the left edge of `rect`, centred on it
    from top to bottom."""
    var left = rect.position.x - rect.width / 2
    return Rectangle(
        Point(left + _BOX_SIZE / 2, rect.position.y),
        _BOX_SIZE,
        _BOX_SIZE,
        corner_radius=corner_radius,
    )


def _tick_lines(centre: Point) -> Tuple[Line, Line]:
    """The two strokes of a tick in a box centred on `centre`."""
    var corner = centre + Vector(-1.5, -4.0)
    return (
        Line(centre + Vector(-5.0, 0.5), corner),
        Line(corner, centre + Vector(5.0, 5.0)),
    )


def _checkbox_text_at(rect: Rectangle) -> Point:
    """Where a checkbox's text starts, aligned left: a gap after its box."""
    var left = rect.position.x - rect.width / 2
    return Point(left + _BOX_SIZE + _TEXT_GAP, rect.position.y)
