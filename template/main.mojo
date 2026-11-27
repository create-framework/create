# See https://create-framework.org/guide/ to get started.

from create import *


@fieldwise_init
struct MyApp(Program):
    var logo: Image

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> MyApp:
        return MyApp(Image.load("assets/logo.png"))

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        canvas.image(self.logo, (0, 50))
        canvas.font_size(48)
        canvas.text("Create", (0, -100))


def main() raises:
    run[MyApp]("{{name}}")
