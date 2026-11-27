"""`ScrollArea`: a window onto a column taller than the room it has, in a
`UI`."""

from create.app import Context
from create.geometry import Line, Rectangle
from create.math import OptionalNumber, Point, clamp
from create.render import Canvas, Style
from ._layout import _UNSIZED
from ._pointer import _Pointer
from ._theme import _ScrollAreaLook, _Theme


struct ScrollArea(Copyable, Movable):
    """A window onto a column of widgets, showing the part of it that fits.

    Add one column inside it. The column is as tall as its widgets, and
    the window shows the part of it `offset` down from its top; what falls
    outside the window is neither drawn nor clicked. While the column is
    taller than the window, a scroll bar runs down the window's right edge:
    the mouse wheel over the window scrolls it, and so does dragging the
    bar's thumb.

    ```mojo
    # In `create`: a list of levels, never taller than 240.
    var window = ui.add(ScrollArea(max_height=240), column)
    var levels = ui.add(Column(), window)
    for name in ["Forest", "Caves", "Castle", "Sky", "Moon"]:
        _ = ui.add(Button(name), levels)

    # In `update`: back to the top.
    self.ui[self.window].offset = 0
    ```

    It leaves room round its column for a focused widget's ring, so the
    ring isn't cut at its edges. With no `rect` of its own it is as wide as
    its column, and as tall as it too, that room included, up to
    `max_height`. In a column or row it can `grow` to fill
    the room left over, like any other widget.

    The bar has two parts, each a line drawn in a style of its own:
    `track`, the length the thumb runs along, and `thumb`, whose length
    shows how much of the column the window shows. The stroke of each is
    its colour and thickness.
    """

    var rect: Rectangle
    """Where the window is: given, or set by what it is in."""
    var offset: Float64
    """How far down its column the window shows, from 0 at the top. Each
    layout keeps it between 0 and as far as the column goes."""
    var max_height: Optional[Float64]
    """The tallest it grows to fit its column, with no `rect` of its own:
    as tall as the column when `None`."""
    var track: Style
    """The line the thumb runs along: its stroke is its colour and
    thickness."""
    var thumb: Style
    """The line whose length shows how much of the column the window
    shows: its stroke is its colour and thickness."""
    var _pointer: _Pointer
    """What the mouse did to the thumb."""
    var _grab: Float64
    """How far above the thumb's middle it was pressed, so a drag keeps it
    under the pointer where it was taken."""
    var _content: Float64
    """The height of the column it shows, as last placed."""
    var _bar: Float64
    """The width of its scroll bar as last placed: 0 while the column fits."""
    var _scrolled: Bool
    """Whether its last update moved `offset`, by the wheel or the thumb."""
    var _look: _ScrollAreaLook

    def __init__(
        out self,
        rect: Rectangle = _UNSIZED,
        *,
        max_height: OptionalNumber = None,
        track: Style = Style(),
        thumb: Style = Style(),
    ):
        self.rect = rect
        self.offset = 0
        self.max_height = max_height._value
        self.track = track
        self.thumb = thumb
        self._pointer = _Pointer()
        self._grab = 0
        self._content = 0
        self._bar = 0
        self._scrolled = False
        self._look = _Theme.default().scroll_area(
            track, thumb, hovered=False, dragging=False, disabled=False
        )

    def _place(mut self, rect: Rectangle, content: Float64, bar: Float64):
        """Place the window at `rect`, onto a column `content` tall, with a
        scroll bar `bar` wide while the column is taller, and keep `offset`
        within the column."""
        self.rect = rect
        self._content = content
        self._bar = bar if self._overflows() else 0.0
        self.offset = min(max(self.offset, 0.0), self._room())

    def _update(
        mut self,
        mut context: Context,
        mut canvas: Canvas,
        theme: _Theme,
        *,
        free: Bool,
        wheel: Bool,
        disabled: Bool,
    ) raises:
        """Read the mouse and work out its look, in `theme`, as a `UI`
        updates it: `free` when it is the topmost under the pointer, so the
        thumb can be hovered and taken, and `wheel` when the wheel is its
        to scroll by."""
        var enabled = not disabled
        var before = self.offset
        var pointer = canvas.to_local(context.mouse.position)
        var ends = self._thumb_ends()
        var over = self._bar > 0 and self._thumb_area(ends).contains(pointer)
        self._pointer.update(context.mouse, over, free=free, enabled=enabled)
        if self._pointer.pressed:
            self._grab = pointer.y - (ends[0] + ends[1]) / 2
        if self._pointer.dragged and self._room() > 0:
            # the thumb's middle follows the pointer, as far as the track
            var track = self._track_ends()
            var length = ends[0] - ends[1]
            var travel = (track[0] - track[1]) - length
            # A window so short that the thumb fills its track leaves the
            # thumb nowhere to go: dragging it moves nothing, rather than
            # jumping to an end, and the wheel still scrolls.
            if travel > 0:
                var top = pointer.y - self._grab + length / 2
                var t = clamp((track[0] - top) / travel, 0.0, 1.0)
                self.offset = t * self._room()
        if enabled and wheel and self._room() > 0:
            # a turn away from you scrolls up, by a control a notch
            var by = context.mouse.wheel.y * theme.control_height
            self.offset = min(max(self.offset - by, 0.0), self._room())
        self._scrolled = self.offset != before
        self._look = theme.scroll_area(
            self.track,
            self.thumb,
            hovered=self._pointer.hovered,
            dragging=self._pointer.dragged,
            disabled=disabled,
        )

    def _overflows(self) -> Bool:
        """Whether its column is taller than its window."""
        return self._content > self.rect.height

    def _room(self) -> Float64:
        """How far it can scroll: the column's height less the window's."""
        return max(self._content - self.rect.height, 0.0)

    def _track_ends(self) -> Tuple[Float64, Float64]:
        """The heights the bar's track runs from and to, top first: inset
        by half the bar's width, so its round ends stay in the window."""
        var inset = self._bar / 2
        return (self.rect.top() - inset, self.rect.bottom() + inset)

    def _thumb_ends(self) -> Tuple[Float64, Float64]:
        """The heights the thumb runs from and to, top first. Its length is
        the track's in proportion to how much of the column shows, and it
        is as far down the track as the window is down the column."""
        var track = self._track_ends()
        var span = track[0] - track[1]
        var length = span
        if self._content > 0:
            length = clamp(
                span * self.rect.height / self._content, self._bar, span
            )
        var t = 0.0
        if self._room() > 0:
            t = self.offset / self._room()
        var top = track[0] - t * (span - length)
        return (top, top - length)

    def _thumb_area(self, ends: Tuple[Float64, Float64]) -> Rectangle:
        """Where a press takes the thumb: the thumb, round ends included."""
        return Rectangle(
            Point(self.rect.right() - self._bar / 2, (ends[0] + ends[1]) / 2),
            self._bar,
            ends[0] - ends[1] + self._bar,
        )

    def _draw_bar(self, mut canvas: Canvas):
        """Draw its scroll bar, while its column is taller than it."""
        if self._bar == 0:
            return
        var x = self.rect.right() - self._bar / 2
        var track = self._track_ends()
        with canvas._with_style(self._look.track):
            canvas.draw(Line(Point(x, track[0]), Point(x, track[1])))
        var ends = self._thumb_ends()
        with canvas._with_style(self._look.thumb):
            canvas.draw(Line(Point(x, ends[0]), Point(x, ends[1])))
