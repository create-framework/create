# See https://create-framework.org/guide/ to get started

from create import *


@fieldwise_init
struct MyApp(Program):
    var logo: Image

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> MyApp:
        # Called once: set initial application state and draw the first frame
        return MyApp(Image.load("assets/logo.png"))

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        # Called once per frame: handle input, modify state and draw to the screen
        canvas.image(self.logo, (0, 40))
        canvas.font_size(48)
        canvas.text("Create", (0, -110))


def main() raises:
    run[MyApp]("{{name}}")
