"""`FocusRing`: the ring drawn around a focused widget."""

from create.color import Color


@fieldwise_init
struct FocusRing(Copyable, ImplicitlyCopyable, Movable, Writable):
    """The ring drawn around a widget focused from the keyboard, a gamepad
    or `ui.focus`: its `thickness`, the `gap` between it and the widget,
    and its `color`, the scheme's `primary` unless given. It follows the
    widget's shape, its corners rounded by the widget's own radius grown by
    the gap."""

    var thickness: Float64
    var gap: Float64
    var color: Optional[Color]

    def __init__(out self):
        self.thickness = 2
        self.gap = 2
        self.color = None
