"""`StateLayers`: how strongly a widget shows its state."""


@fieldwise_init
struct StateLayers(Copyable, ImplicitlyCopyable, Movable, Writable):
    """How strongly a widget shows its state.

    A hovered, pressed or dragged widget moves its OKLCH lightness
    by that step towards its text colour: 0.09 is a clear but quiet change,
    and the same step looks like the same change on any colour. A disabled
    widget instead fades, its content to `disabled_content` of its opacity
    and its fill to `disabled_container`. Focus has no step: it shows as
    the `FocusRing`.
    """

    var hovered: Float64
    var pressed: Float64
    var dragged: Float64
    var disabled_content: Float64
    var disabled_container: Float64

    def __init__(out self):
        self.hovered = 0.09
        self.pressed = 0.16
        self.dragged = 0.16
        self.disabled_content = 0.38
        self.disabled_container = 0.12
