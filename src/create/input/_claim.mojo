"""Internal: a device's claim, for sharing one device between several
readers that would otherwise all act on it."""


@fieldwise_init
struct _Claim(Copyable, ImplicitlyCopyable, Movable):
    """Who has claimed a device: an opaque number, 0 for no one, and the
    frame the claim was last made or renewed in. The device doesn't know
    what the number stands for (a `UI`, for instance).

    A claim lasts while its claimant renews it every frame: one not renewed
    for a frame lapses, so a claimant that stops reading the device, or is
    gone, can't hold it for good."""

    var claimant: Int
    var frame: Int

    def __init__(out self):
        self.claimant = 0
        self.frame = 0

    def claim(mut self, claimant: Int, frame: Int):
        """Claim the device for `claimant`, or renew its claim."""
        self.claimant = claimant
        self.frame = frame

    def release(mut self, claimant: Int):
        """Let go, if `claimant` is the one holding it."""
        if self.claimant == claimant:
            self.claimant = 0

    def held_by_other(self, claimant: Int, frame: Int) -> Bool:
        """Whether someone other than `claimant` holds the device in
        `frame`: claimed, and renewed this frame or the one before."""
        return (
            self.claimant != 0
            and self.claimant != claimant
            and self.frame >= frame - 1
        )
