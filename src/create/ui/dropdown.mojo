"""`Dropdown`: a field showing the chosen option, which opens a list of
the options over everything else."""

from create.app import Context
from create.geometry import Line, Rectangle
from create.input import Key
from create.math import Point, Vector, clamp
from create.render import Canvas, Style, Text
from ._pointer import _Pointer
from create.color.color_scheme import ColorScheme
from ._theme import _DropdownLook, _Theme
from ._layout import _UNSIZED
from .slider import _CONTROL_WIDTH
from .text_field import _measure
from ._navigation import _Focus
from .clickable import Clickable
from .widget import Widget


comptime _TEXT_INSET = 12.0
"""The gap between the field's or an item's left edge and its text."""

comptime _CHEVRON_ROOM = 36.0
"""The room at the field's right end for the chevron."""

comptime _LIST_GAP = 4.0
"""The gap between the field and its open list, and round the items
inside the list."""


struct Dropdown(Clickable, Copyable, Movable, Widget):
    """A field showing the chosen one of its options, which opens a list of
    them all when clicked, drawn over everything else. Use it to choose one
    of many options, such as a screen resolution, where a `ChoiceGroup`
    would take too much room.

    ```mojo
    # In `create`, building the `resolution` field:
    var resolution = Dropdown(
        ["1280 × 720", "1920 × 1080", "2560 × 1440"],
        Rectangle((0, 0), 220, 40),
    )

    # In `update`: drawn last, so its list is drawn over the rest.
    self.resolution.update(context, canvas)
    canvas.draw(self.resolution)
    if self.resolution.changed():
        self.apply(self.resolution.selected)
    ```

    A click on the field opens the list; a click on an item chooses it and
    closes the list, and a click anywhere else closes it without choosing.
    The list opens below the field, or above it where that leaves more
    room, and shows at most `max_items` at once: the mouse wheel scrolls
    the rest into view.

    In a `UI`, it works without a mouse too. While it has focus, Enter,
    Space or a gamepad's south button opens its list; then the up and down
    arrows or the gamepad's push move the mark, Enter, Space or the south
    button choose the marked item, and Escape or the east button close the
    list without choosing, keeping focus on it. Tab closes it and moves
    on.

    In a `UI`, its list is drawn after every other widget and outside any
    scroll area's window, and while it is open, a click anywhere reaches
    only the dropdown. On its own, draw it after everything else, and keep
    a click that closes it from reaching what is beneath.

    Each part is a shape drawn in a style of its own: `field` is the
    field, a rectangle with the chosen option's text; `list` is the open
    list, a rectangle; and `item` is each item's text, the chosen one in
    the accent colour.
    """

    var options: List[String]
    """The options' text, in the order they are listed."""
    var rect: Rectangle
    """Where its field is."""
    var selected: Int
    """Which option is chosen, counted from 0. Set it to choose one from
    the program; outside the options, the field is empty."""
    var max_items: Int
    """The most items the open list shows at once."""
    var field: Style
    """The field, a rectangle with the chosen option's text."""
    var list: Style
    """The open list, a rectangle."""
    var item: Style
    """Each item's text, the chosen one in the accent colour."""
    var enabled: Bool
    """Whether it reacts to the mouse. A disabled dropdown is faded and
    closed."""
    var _pointer: _Pointer
    """What the mouse did to the field and, while open, its list."""
    var _open: Bool
    var _pressed_item: Int
    var _hovered_item: Int
    var _highlight: Int
    """The item the open list marks: the one under the pointer, or the one
    the arrows or a gamepad moved to; Enter, Space and the south button
    choose it."""
    var _scroll: Float64
    """How far down the items the open list shows."""
    var _list_rect: Rectangle
    """Where the open list is, as last worked out."""
    var _activated: Bool
    """Whether Enter, Space or the south button pressed it this frame."""
    var _changed: Bool
    var _look: _DropdownLook

    def __init__(
        out self,
        var options: List[String],
        rect: Rectangle = _UNSIZED,
        *,
        selected: Int = 0,
        max_items: Int = 6,
        field: Style = Style(),
        list: Style = Style(),
        item: Style = Style(),
        enabled: Bool = True,
    ):
        self.options = options^
        self.rect = rect
        self.selected = selected
        self.max_items = max(max_items, 1)
        self.field = field
        self.list = list
        self.item = item
        self.enabled = enabled
        self._pointer = _Pointer()
        self._open = False
        self._pressed_item = -1
        self._hovered_item = -1
        self._highlight = -1
        self._scroll = 0
        self._list_rect = _UNSIZED
        self._activated = False
        self._changed = False
        self._look = _Theme.default().dropdown(
            field,
            list,
            item,
            hovered=False,
            pressed=False,
            disabled=not enabled,
        )

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        """Read what the mouse did to it this frame, opening, choosing and
        closing, and work out its look: call it before drawing it.

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
        var before = self.selected
        self._activated = focus.activated and enabled
        ref mouse = context.mouse
        var pointer = canvas.to_local(mouse.position)
        if not enabled:
            self._open = False
        if self._open:
            self._list_rect = self._place_list(canvas, theme)
        var in_field = self.rect.contains(pointer)
        var in_list = self._open and self._list_rect.contains(pointer)
        self._pointer.update(
            mouse, in_field or in_list, free=free, enabled=enabled
        )
        var was_hovered = self._hovered_item
        self._hovered_item = -1
        if in_list and self._pointer.hovered:
            self._hovered_item = self._item_at(pointer)
        if self._hovered_item >= 0 and self._hovered_item != was_hovered:
            self._highlight = self._hovered_item  # the mouse marks it
        # in a tree, focus moving away, such as by Tab, closes it
        if self._open and focus.in_tree and not focus.focused:
            self._open = False
        if enabled and self._open:
            if mouse.pressed():
                self._pressed_item = self._hovered_item
            if self._pointer.released:
                if in_list and self._hovered_item == self._pressed_item:
                    if self._hovered_item >= 0:
                        self.selected = self._hovered_item
                        self._open = False
                elif in_field:
                    self._open = False  # a click on the field closes it
            elif mouse.pressed() and not in_field and not in_list:
                self._open = False  # a click anywhere else closes it
            if self._open and in_list and mouse.wheel.y != 0:
                self._scroll_by(-mouse.wheel.y * self._item_height())
            if self._open:
                self._keys_while_open(context, focus)
        elif enabled and (
            (self._pointer.released and in_field) or focus.activated
        ):
            self._open_list(canvas, theme)
        self._changed = self.selected != before
        self._look = theme.dropdown(
            self.field,
            self.list,
            self.item,
            hovered=self._pointer.hovered and in_field,
            pressed=self._pointer.looks_pressed() and in_field,
            disabled=not enabled,
        )

    def _keys_while_open(mut self, context: Context, focus: _Focus):
        """Move the mark with the arrows or a gamepad's push, choose the
        marked item with Enter, Space or the south button, and close the
        list without choosing on Escape or the east button."""
        if focus.back:
            self._open = False
            return
        if focus.activated:
            if self._highlight >= 0 and self._highlight < len(self.options):
                self.selected = self._highlight
            self._open = False
            return
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
        if by != 0 and self.options:
            var last = len(self.options) - 1
            if self._highlight < 0:
                self._highlight = 0 if by > 0 else last
            else:
                self._highlight = min(max(self._highlight + by, 0), last)
            self._show_item(self._highlight)

    def _open_list(mut self, mut canvas: Canvas, theme: _Theme):
        """Open the list, scrolled to show the chosen item, which it marks."""
        self._open = True
        self._highlight = self.selected
        self._pressed_item = -1
        self._list_rect = self._place_list(canvas, theme)
        self._scroll = 0
        if self.selected >= 0 and self.selected < len(self.options):
            self._show_item(self.selected)

    def _item_height(self) -> Float64:
        """How tall each item in the list is: as tall as the field."""
        return self.rect.height

    def _shown_items(self) -> Int:
        """How many items the open list shows at once."""
        return min(len(self.options), self.max_items)

    def _room(self) -> Float64:
        """How far the open list can scroll."""
        return max(
            Float64(len(self.options) - self._shown_items())
            * self._item_height(),
            0.0,
        )

    def _scroll_by(mut self, amount: Float64):
        self._scroll = clamp(self._scroll + amount, 0.0, self._room())

    def _show_item(mut self, item: Int):
        """Scroll the open list by the least that shows `item`."""
        var height = self._item_height()
        var top = Float64(item) * height
        var shown = Float64(self._shown_items()) * height
        if top < self._scroll:
            self._scroll = top
        elif top + height > self._scroll + shown:
            self._scroll = top + height - shown
        self._scroll = clamp(self._scroll, 0.0, self._room())

    def _place_list(self, mut canvas: Canvas, theme: _Theme) -> Rectangle:
        """Where the open list goes: below the field, or above it when the
        canvas leaves more room there, as wide as the field."""
        var height = (
            Float64(self._shown_items()) * self._item_height() + 2 * _LIST_GAP
        )
        var foot = canvas.to_local(Point(0, canvas.bottom())).y
        var head = canvas.to_local(Point(0, canvas.top())).y
        var below = self.rect.bottom() - _LIST_GAP - foot
        var above = head - (self.rect.top() + _LIST_GAP)
        var centre_y = self.rect.bottom() - _LIST_GAP - height / 2
        if below < height and above > below:
            centre_y = self.rect.top() + _LIST_GAP + height / 2
        return Rectangle(
            Point(self.rect.position.x, centre_y),
            self.rect.width,
            height,
            corner_radius=self._look.list.corner_radius,
        )

    def _items_area(self) -> Rectangle:
        """The part of the open list its items are drawn in."""
        return self._list_rect.inset(_LIST_GAP)

    def _item_at(self, point: Point) -> Int:
        """The item `point` is on in the open list, or -1."""
        var area = self._items_area()
        if not area.contains(point):
            return -1
        var i = Int((area.top() - point.y + self._scroll) / self._item_height())
        if i < 0 or i >= len(self.options):
            return -1
        return i

    def _measure(
        self, mut canvas: Canvas, theme: _Theme
    ) raises -> Tuple[Float64, Float64]:
        """The size it prefers in `theme`: as wide as its widest option with
        room for the chevron, at least `_CONTROL_WIDTH`, and
        `control_height` tall."""
        var look = theme.dropdown(
            self.field,
            self.list,
            self.item,
            hovered=False,
            pressed=False,
            disabled=False,
        )
        var widest = 0.0
        for option in self.options:
            widest = max(widest, _measure(canvas, option, look.field_text))
        return (
            max(widest + _TEXT_INSET + _CHEVRON_ROOM, _CONTROL_WIDTH),
            theme.control_height,
        )

    def _ring(self) -> Rectangle:
        """The shape its focus ring goes round: its field."""
        var field = self.rect.copy()
        field.corner_radius = self._look.field.corner_radius
        return field

    def _popup(self) -> Optional[Rectangle]:
        """Where its open list is, or `None` while it is closed."""
        if self._open:
            return self._list_rect
        return None

    def is_open(self) -> Bool:
        """Whether its list is open."""
        return self._open

    def selected_text(self) -> String:
        """The chosen option's text, or an empty string when none is."""
        if self.selected >= 0 and self.selected < len(self.options):
            return self.options[self.selected]
        return ""

    def changed(self) -> Bool:
        """Whether its last `update` chose another option."""
        return self._changed

    def hovered(self) -> Bool:
        """Whether the pointer is over its field, or its list while open,
        as of its last `update`."""
        return self._pointer.hovered

    def pressed(self) -> Bool:
        """Whether the left button went down over its field, or its list
        while open, this frame."""
        return self._pointer.pressed

    def down(self) -> Bool:
        """Whether it is held: pressed on it, and the button not let go
        since, wherever the pointer has moved."""
        return self._pointer.held

    def released(self) -> Bool:
        """Whether it was clicked this frame: let go over its field or its
        open list after being pressed on it, or, in a `UI`, pressed with
        Enter, Space or a gamepad's south button while it has focus."""
        return self._pointer.released or self._activated

    def draw_to(self, mut canvas: Canvas):
        self._draw_field(canvas)
        self._draw_list(canvas)

    def _draw_field(self, mut canvas: Canvas):
        """Draw the field: its box, the chosen option and the chevron."""
        with canvas._with_style(self._look.field):
            canvas.draw(self._ring())
        with canvas._with_style(self._look.field_text):
            canvas.draw(
                Text(
                    self.selected_text(),
                    Point(self.rect.left() + _TEXT_INSET, self.rect.position.y),
                )
            )
        # a chevron pointing down while closed, up while open
        var tip = Point(
            self.rect.right() - _CHEVRON_ROOM / 2, self.rect.position.y
        )
        var lean = 3.0 if self._open else -3.0
        with canvas._with_style(self._look.chevron):
            canvas.draw(Line(tip + Vector(-5, -lean), tip + Vector(0, lean)))
            canvas.draw(Line(tip + Vector(0, lean), tip + Vector(5, -lean)))

    def _draw_list(self, mut canvas: Canvas):
        """Draw the open list, if it is open: its box, its items and, when
        there are more than fit, a thumb showing where it is scrolled to."""
        if not self._open:
            return
        with canvas._with_style(self._look.list):
            canvas.draw(self._list_rect)
        var area = self._items_area()
        var height = self._item_height()
        with canvas.clip(area):
            for i in range(len(self.options)):
                var middle = (
                    area.top() - self._scroll - (Float64(i) + 0.5) * height
                )
                if middle + height / 2 < area.bottom():
                    break
                if middle - height / 2 > area.top():
                    continue
                var row = Rectangle(
                    Point(area.position.x, middle),
                    area.width,
                    height,
                    corner_radius=self._look.list.corner_radius / 2,
                )
                if i == self._highlight:
                    with canvas._with_style(self._look.layer):
                        canvas.draw(row)
                with canvas._with_style(
                    self._look.selected_text if i
                    == self.selected else self._look.item_text
                ):
                    canvas.draw(
                        Text(
                            self.options[i],
                            Point(area.left() + _TEXT_INSET, middle),
                        )
                    )
        var room = self._room()
        if room > 0:
            # a thumb as long as the share of the items shown, where the
            # list is scrolled to
            var span = area.height
            var length = span * (span / (span + room))
            var top = area.top() - (self._scroll / room) * (span - length)
            var x = area.right() - 3
            with canvas._with_style(self._look.thumb):
                canvas.draw(Line(Point(x, top), Point(x, top - length)))
