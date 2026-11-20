"""`SliderStyle`: how a slider looks."""

from create.color import Color
from create.math._optional_float64 import _OptionalFloat64
from .theme import FocusRing


struct SliderStyle(Copyable, ImplicitlyCopyable, Movable, Writable):
    """How one slider looks, where it differs from the theme. Every field
    left unset is worked out from the theme when the slider is drawn."""

    var active_track_color: Optional[Color]
    """The track between its start and the handle: `primary`."""
    var inactive_track_color: Optional[Color]
    """The rest of the track: `secondary_container`."""
    var handle_color: Optional[Color]
    """The handle: `primary`. It is tinted black or white, whichever shows
    on it, while hovered or dragged."""
    var handle_outline_color: Optional[Color]
    """A thin border around the handle, none unless given: it keeps a light
    handle visible on a light surface."""
    var handle_shadow: Bool
    """Whether the handle casts a soft shadow, lifting it off the track:
    off unless set."""
    var track_thickness: Optional[Float64]
    """4 unless given."""
    var handle_radius: Optional[Float64]
    """10 unless given."""

    var focus_ring: Optional[FocusRing]
    """The ring shown while it has focus from the keyboard: the theme's
    unless given."""

    def __init__(
        out self,
        *,
        active_track_color: Optional[Color] = None,
        inactive_track_color: Optional[Color] = None,
        handle_color: Optional[Color] = None,
        handle_outline_color: Optional[Color] = None,
        handle_shadow: Bool = False,
        track_thickness: _OptionalFloat64 = None,
        handle_radius: _OptionalFloat64 = None,
        focus_ring: Optional[FocusRing] = None,
    ):
        self.active_track_color = active_track_color
        self.inactive_track_color = inactive_track_color
        self.handle_color = handle_color
        self.handle_outline_color = handle_outline_color
        self.handle_shadow = handle_shadow
        self.track_thickness = track_thickness._value
        self.handle_radius = handle_radius._value
        self.focus_ring = focus_ring

    def _over(self, under: Self) -> Self:
        """This style, with every field it leaves unset taken from `under`:
        how a call's style sits over a `ui.style` block's, and an inner block
        over an outer one."""
        var merged = self.copy()
        if not merged.active_track_color:
            merged.active_track_color = under.active_track_color
        if not merged.inactive_track_color:
            merged.inactive_track_color = under.inactive_track_color
        if not merged.handle_color:
            merged.handle_color = under.handle_color
        if not merged.handle_outline_color:
            merged.handle_outline_color = under.handle_outline_color
        if not merged.track_thickness:
            merged.track_thickness = under.track_thickness
        if not merged.handle_radius:
            merged.handle_radius = under.handle_radius
        if not merged.focus_ring:
            merged.focus_ring = under.focus_ring
        merged.handle_shadow = self.handle_shadow or under.handle_shadow
        return merged^
