"""`CheckboxStyle`: how a checkbox looks."""

from create.color import Color
from .theme import FocusRing, TypeStyle


struct CheckboxStyle(Copyable, ImplicitlyCopyable, Movable, Writable):
    """How one checkbox looks, where it differs from the theme. Every field
    left unset is worked out from the theme when the checkbox is drawn."""

    var box_color: Optional[Color]
    """The fill of a ticked box: `primary`."""
    var check_color: Optional[Color]
    """The tick: `on_primary`."""
    var outline_color: Optional[Color]
    """The border of an empty box: `on_surface_variant`."""
    var label_color: Optional[Color]
    """The label's text: `on_surface`."""
    var text_style: Optional[TypeStyle]
    """The theme's `body` text unless given."""

    var focus_ring: Optional[FocusRing]
    """The ring shown while it has focus from the keyboard: the theme's
    unless given."""

    def __init__(
        out self,
        *,
        box_color: Optional[Color] = None,
        check_color: Optional[Color] = None,
        outline_color: Optional[Color] = None,
        label_color: Optional[Color] = None,
        text_style: Optional[TypeStyle] = None,
        focus_ring: Optional[FocusRing] = None,
    ):
        self.box_color = box_color
        self.check_color = check_color
        self.outline_color = outline_color
        self.label_color = label_color
        self.text_style = text_style
        self.focus_ring = focus_ring

    def _over(self, under: Self) -> Self:
        """This style, with every field it leaves unset taken from `under`:
        how a call's style sits over a `ui.style` block's, and an inner block
        over an outer one."""
        var merged = self.copy()
        if not merged.box_color:
            merged.box_color = under.box_color
        if not merged.check_color:
            merged.check_color = under.check_color
        if not merged.outline_color:
            merged.outline_color = under.outline_color
        if not merged.label_color:
            merged.label_color = under.label_color
        if not merged.text_style:
            merged.text_style = under.text_style
        if not merged.focus_ring:
            merged.focus_ring = under.focus_ring
        return merged^
