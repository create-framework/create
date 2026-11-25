"""Internal: `_Pointer`, what the mouse did to a widget, kept between its
`update`s."""

from create.input import Mouse


@fieldwise_init
struct _Pointer(Copyable, ImplicitlyCopyable, Movable):
    """A widget's interaction state: whether the pointer is over it, whether
    it is held, and this frame's edges."""

    var hovered: Bool
    var held: Bool
    """Pressed on it, and the button not let go since."""
    var pressed: Bool
    """The button went down over it this frame."""
    var released: Bool
    """The button came up over it this frame, after being pressed on it:
    a click."""

    def __init__(out self):
        self.hovered = False
        self.held = False
        self.pressed = False
        self.released = False

    def update(
        mut self, mouse: Mouse, inside: Bool, *, free: Bool, enabled: Bool
    ):
        """Work out this frame's state from `mouse`, given whether the
        pointer is `inside` the widget. `free` is false when another widget
        is over it at the pointer, which keeps it from being hovered; a held
        widget stays held until the button comes up. A disabled widget lets
        go and reacts to nothing."""
        self.pressed = False
        self.released = False
        if not enabled:
            self.hovered = False
            self.held = False
            return
        self.hovered = inside and free
        if self.hovered and mouse.pressed():
            self.pressed = True
            self.held = True
        if self.held and mouse.released():
            self.released = self.hovered
            self.held = False
        elif self.held and not mouse.down():
            self.held = False  # let go where its release wasn't seen

    def looks_pressed(self) -> Bool:
        """Whether it is drawn pressed in: held with the pointer still over
        it."""
        return self.held and self.hovered
