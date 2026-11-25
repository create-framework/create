"""`Drawable`: a program's own type that draws itself onto a canvas."""

from .canvas import Canvas


trait Drawable:
    """Something drawn onto a canvas through `canvas.draw`: a program's own
    type, made of the shapes and curves it draws.

    A shape or a curve needs no `Drawable`: `canvas.draw` draws any of them
    itself. A type of your own is `Drawable` when its `draw_to` draws its
    parts:

    ```mojo
    @fieldwise_init
    struct Badge(Drawable):
        var plate: Rectangle
        var disc: Circle

        def draw_to(self, mut canvas: Canvas):
            canvas.draw(self.plate)
            canvas.draw(self.disc)
    ```

    Each part is drawn in whatever style and transform the canvas has when
    `canvas.draw(badge)` is called, as a single shape would be.
    """

    def draw_to(self, mut canvas: Canvas):
        """Draw this onto `canvas`."""
        ...
