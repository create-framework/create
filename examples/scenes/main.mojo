"""Two scenes in one program: a menu, and a canvas to paint on.

Each scene is a plain struct, not a `Program`, kept as a field of the
program. An `Int` field says which scene is showing, and an `if` in `update`
runs it. Each scene's `update` takes only what it uses, and `enter` resets
the painting scene as the program switches to it. "Multiple scenes" in the
user guide's Programs page says why there is no scene trait.

Click to start painting. Drag with the left button to paint, and
right-click to go back to the menu.
"""

from create import *
from menu import Menu
from paint import Paint

comptime _MENU = 0
comptime _DRAWING = 1


@fieldwise_init
struct App(Program):
    var scene: Int
    var menu: Menu
    var paint: Paint

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> App:
        # The painting scene accumulates ink across frames, so the per-frame
        # clear is off for the whole program: `Menu` paints its own background
        # every frame, and `Paint` clears once on entry.
        canvas.autoclear(False)
        return App(_MENU, Menu(False), Paint(False, False))

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        if self.scene == _MENU:
            self.menu.update(context, canvas)
            if self.menu.start_pressed:
                self.paint.enter()
                self.scene = _DRAWING
        else:
            self.paint.update(context, canvas)
            if self.paint.back_pressed:
                self.scene = _MENU


def main() raises:
    run[App]("Scenes", width=800, height=600)
