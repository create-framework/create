"""`Widget`, `Hoverable` and `Clickable`: what a widget is, and what can be
asked of one after its `update`."""

from create.core import Context
from create.render import Canvas, Drawable


trait Widget(Drawable):
    """A value that reacts to input and draws itself: a `Button`, say.

    Each frame, call `update` and then draw it with `canvas.draw`, in that
    order and in the same transform. `update` reads what the input did to
    it, through `canvas.to_local`, so a widget under a camera or inside a
    `canvas.transform` block is hit where it is drawn. It then keeps what
    happened, for the queries and for drawing, so a widget shows the state
    it is in from the frame it gets there.

    ```mojo
    # In `update`, with a `play: Button` field:
    self.play.update(context, canvas)
    canvas.draw(self.play)
    if self.play.released():
        self.start()
    ```
    """

    def update(mut self, mut context: Context, canvas: Canvas) raises:
        """Read what the input did to it this frame, and keep it."""
        ...


trait Hoverable:
    """A widget the pointer can be over."""

    def hovered(self) -> Bool:
        """Whether the pointer is over it, as of its last `update`."""
        ...


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
