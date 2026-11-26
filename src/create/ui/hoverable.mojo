"""`Hoverable`: a widget the pointer can be over."""


trait Hoverable:
    """A widget the pointer can be over."""

    def hovered(self) -> Bool:
        """Whether the pointer is over it, as of its last `update`."""
        ...
