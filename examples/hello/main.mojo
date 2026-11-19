"""The example code used in README."""

from create import *


@fieldwise_init
struct MyApp(Program):
    var greeting: String
    var position: Point2D

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> MyApp:
        return MyApp("Hello, world!", (0, 0))

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        canvas.font_size(48)
        canvas.text(self.greeting, self.position)


def main() raises:
    run[MyApp]("Hello")
