"""`LabelStyle`: how a label's text looks."""

from create.color import Color
from .theme import TypeStyle


struct LabelStyle(Copyable, ImplicitlyCopyable, Movable, Writable):
    """How a label's text looks, where it differs from the theme: the
    theme's `on_surface` colour and `body` text unless given."""

    var color: Optional[Color]
    var text_style: Optional[TypeStyle]

    def __init__(
        out self,
        *,
        color: Optional[Color] = None,
        text_style: Optional[TypeStyle] = None,
    ):
        self.color = color
        self.text_style = text_style
