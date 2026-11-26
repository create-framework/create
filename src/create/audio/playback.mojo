"""`Playback`: one playback of a `Sound`."""


struct Playback(Copyable, Equatable, ImplicitlyCopyable, Movable):
    """One playback of a `Sound`, as `audio.play` and `audio.loop` return it:
    the handle `stop`, `pause`, `resume`, `volume`, `speed`, `is_playing`
    and `is_paused` take.

    A `Sound` can have several playbacks at once. One that has ended or
    been stopped is stale: every call on it does nothing, even after its slot
    plays another sound. `Playback.NONE` is no playback, for a field before
    anything plays. A handle, like `Sound`, so not printable.
    """

    var _id: Int
    """The slot index and its generation, as `Audio._encode` packs them."""

    comptime NONE = Playback(_id=0)

    def __init__(out self, *, _id: Int):
        self._id = _id

    def __eq__(self, other: Playback) -> Bool:
        return self._id == other._id

    def __ne__(self, other: Playback) -> Bool:
        return self._id != other._id
