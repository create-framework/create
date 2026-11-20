# SliderStyle

```mojo
struct SliderStyle
```

How one slider looks, where it differs from the theme. Every field left unset is worked out from the theme when the slider is drawn.

Implements `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `Writable`.

## Fields

- `active_track_color: Optional[Color]`: The track between its start and the handle: `primary`.
- `inactive_track_color: Optional[Color]`: The rest of the track: `secondary_container`.
- `handle_color: Optional[Color]`: The handle: `primary`. It is tinted black or white, whichever shows on it, while hovered or dragged.
- `handle_outline_color: Optional[Color]`: A thin border around the handle, none unless given: it keeps a light handle visible on a light surface.
- `handle_shadow: Bool`: Whether the handle casts a soft shadow, lifting it off the track: off unless set.
- `track_thickness: Optional[Float64]`: 4 unless given.
- `handle_radius: Optional[Float64]`: 10 unless given.

## Constructors

```mojo
@staticmethod
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
)
```
