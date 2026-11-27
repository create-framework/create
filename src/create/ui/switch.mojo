"""`Switch`: a setting turned on or off, drawn as a handle in a track, with
text beside it."""

from create.app import Context
from create.geometry import Line, Rectangle
from create.math import Point
from create.render import Canvas, Style, Text
from ._pointer import _Pointer
from .checkbox import _TEXT_GAP
from create.color.color_scheme import ColorScheme
from ._theme import _SwitchLook, _Theme
from ._layout import _UNSIZED
from .text_field import _measure
from ._navigation import _Focus
from .clickable import Clickable
from .widget import Widget


comptime _TRACK_WIDTH = 44.0
"""How wide a switch's track is."""

comptime _TRACK_HEIGHT = 24.0
"""How tall a switch's track is."""


struct Switch(Clickable, Copyable, Movable, Widget):
    """A setting that is on or off and applies at once, such as music or
    full screen: a track against the left edge of a rectangle, its handle
    at the right end while `on`, with text beside it. A click anywhere in
    the rectangle turns it over.

    ```mojo
    # In `create`, building the `music` field:
    var music = Switch("Music", Rectangle((0, 0), 200, 32), on=True)

    # In `update`:
    self.music.update(context, canvas)
    canvas.draw(self.music)
    if self.music.changed():
        self.audio.volume(1.0 if self.music.on else 0.0)
    ```

    A switch and a checkbox do the same job. A switch reads as a setting
    that takes effect the moment it is turned, and a checkbox as a choice
    made before something else happens, such as a box ticked in a form.

    Each part is a shape drawn in a style of its own: `track` is a rounded
    rectangle, its outline and fill drawn while off; `on_track` is the same
    rectangle while on, taking what it leaves unset from `track`; `handle`
    is a point, so its stroke is its colour and its `stroke_thickness` its
    diameter; and `text_style` is the text's.
    """

    var text: String
    """The text beside the track."""
    var rect: Rectangle
    """Where it is: the track against its left edge, and the area a click
    turns it over in."""
    var on: Bool
    """Whether it is on. Set it to turn it from the program."""
    var track: Style
    var on_track: Style
    var handle: Style
    var text_style: Style
    var enabled: Bool
    """Whether it reacts to the mouse. A disabled switch is faded."""
    var _pointer: _Pointer
    var _changed: Bool
    var _look: _SwitchLook

    def __init__(
        out self,
        text: String,
        rect: Rectangle = _UNSIZED,
        *,
        on: Bool = False,
        track: Style = Style(),
        on_track: Style = Style(),
        handle: Style = Style(),
        text_style: Style = Style(),
        enabled: Bool = True,
    ):
        self.text = text
        self.rect = rect
        self.on = on
        self.track = track
        self.on_track = on_track
        self.handle = handle
        self.text_style = text_style
        self.enabled = enabled
        self._pointer = _Pointer()
        self._changed = False
        self._look = _Theme.default().switch(
            track,
            on_track,
            handle,
            text_style,
            on=on,
            hovered=False,
            pressed=False,
            disabled=not enabled,
        )

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        """Read what the mouse did to it this frame, turning it over on a
        click, and work out its look: call it before drawing it.

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
        self._changed = self._pointer.released or (focus.activated and enabled)
        if self._changed:
            self.on = not self.on
        self._look = theme.switch(
            self.track,
            self.on_track,
            self.handle,
            self.text_style,
            on=self.on,
            hovered=self._pointer.hovered,
            pressed=self._pointer.looks_pressed(),
            disabled=not enabled,
        )

    def _measure(
        self, mut canvas: Canvas, theme: _Theme
    ) raises -> Tuple[Float64, Float64]:
        """The size it prefers in `theme`: its track, the gap and its text,
        `control_height` tall."""
        var look = theme.switch(
            self.track,
            self.on_track,
            self.handle,
            self.text_style,
            on=self.on,
            hovered=False,
            pressed=False,
            disabled=False,
        )
        var width = _measure(canvas, self.text, look.text)
        return (_TRACK_WIDTH + _TEXT_GAP + width, theme.control_height)

    def _ring(self) -> Rectangle:
        """The shape its focus ring goes round: its track."""
        return _switch_track(self.rect)

    def changed(self) -> Bool:
        """Whether its last `update` turned it over."""
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
        var track = _switch_track(self.rect)
        with canvas._with_style(self._look.track):
            canvas.draw(track)
        # the handle sits in the end it is turned to
        var inset = _TRACK_HEIGHT / 2
        var x = track.left() + inset
        if self.on:
            x = track.right() - inset
        var centre = Point(x, track.position.y)
        with canvas._with_style(self._look.handle):
            canvas.draw(Line(centre, centre))
        with canvas._with_style(self._look.text):
            var left = self.rect.left()
            canvas.draw(
                Text(
                    self.text,
                    Point(
                        left + _TRACK_WIDTH + _TEXT_GAP, self.rect.position.y
                    ),
                )
            )


def _switch_track(rect: Rectangle) -> Rectangle:
    """A switch's track: against the left edge of `rect`, centred on it
    from top to bottom, with round ends."""
    return Rectangle(
        Point(rect.left() + _TRACK_WIDTH / 2, rect.position.y),
        _TRACK_WIDTH,
        _TRACK_HEIGHT,
        corner_radius=_TRACK_HEIGHT / 2,
    )
