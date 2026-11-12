"""The example code used in README."""

from create import *


@fieldwise_init
struct MyApp(Program):
    var greeting: String
    var position: Point2D

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> MyApp:
        # Called once: set initial application state and draw the first frame
        return MyApp("Hello, world!", (0, 0))

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        # Called once per frame: handle input, modify state, and draw to the screen
        self.position = context.mouse.position
        canvas.font_size(48)
        canvas.text(self.greeting, self.position)


def main() raises:
    run[MyApp]("Hello")
