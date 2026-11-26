"""`Widget`: what a widget is."""

from create.app import Context
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

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        """Read what the input did to it this frame, and keep it."""
        ...
