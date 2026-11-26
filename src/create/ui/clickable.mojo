"""`Clickable`: a widget the mouse presses."""

from .hoverable import Hoverable


trait Clickable(Hoverable):
    """A widget the mouse presses, in the words the input devices use:
    *pressed* and *released* are the edges, true only in the frame they
    happen, and *down* is held. Each is as of its last `update`."""

    def pressed(self) -> Bool:
        """Whether the left button went down over it this frame."""
        ...

    def down(self) -> Bool:
        """Whether it is held: pressed on it, and the button not let go
        since, wherever the pointer has moved."""
        ...

    def released(self) -> Bool:
        """Whether it was clicked this frame: let go over it, after being
        pressed on it. A press that starts elsewhere doesn't count."""
        ...
