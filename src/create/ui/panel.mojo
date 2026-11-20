"""`PanelStyle`: how a panel looks."""

from create.color import Color
from create.math._optional_float64 import _OptionalFloat64


struct PanelStyle(Copyable, ImplicitlyCopyable, Movable, Writable):
    """How one panel looks, where it differs from the theme. Every field left
    unset is worked out from the theme when the panel is drawn."""

    var color: Optional[Color]
    """The panel's surface: `surface_container`."""
    var content_color: Optional[Color]
    """The colour of text on it: the `on_` partner of `color` when it is one
    of the scheme's roles, otherwise black or white, whichever reads
    better."""
    var outline_color: Optional[Color]
    """A border, none unless given."""
    var outline_thickness: Optional[Float64]
    """1 unless given, when there is a border."""
    var corner_radius: Optional[Float64]
    """The theme's large corner radius unless given."""
    var shadow: Bool
    """Whether it casts a soft shadow, lifting it off what is beneath."""

    def __init__(
        out self,
        *,
        color: Optional[Color] = None,
        content_color: Optional[Color] = None,
        outline_color: Optional[Color] = None,
        outline_thickness: _OptionalFloat64 = None,
        corner_radius: _OptionalFloat64 = None,
        shadow: Bool = False,
    ):
        self.color = color
        self.content_color = content_color
        self.outline_color = outline_color
        self.outline_thickness = outline_thickness._value
        self.corner_radius = corner_radius._value
        self.shadow = shadow
