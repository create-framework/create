<p align="center">
    <img src="assets/logo/png/logo-trim.png" width="150" alt="Create Logo">
</p>

<h1 align="center">Create</h1>

> Note: APIs are experimental and subject to change.

---

**Create** is a creative coding library for [Mojo](https://mojolang.org/), inspired by [Processing](https://processing.org/). It combines the simplicity and immediacy of creative coding with a structured, modular API, so it works not only for quick sketches but also for small- to medium-sized projects such as 2D games, simulations and visualisations.

## Example Programs

The GIF below shows an example program running. First it generates a [Sierpiński triangle](https://en.wikipedia.org/wiki/Sierpi%C5%84ski_triangle) using the random midpoint method (also known as the [chaos game](https://en.wikipedia.org/wiki/Chaos_game)). 
Then coloured triangles grow into place on top of it, forming the **Create** logo.

<p align="center">
    <img src="assets/gifs/logo-animation.gif" alt="The Create logo assembling: a Sierpiński triangle drawn in points, then the logo's triangles growing in over it">
    <br>
    <sub>The logo drawn, animated and recorded to a GIF using the <b>Create</b> library itself. See <a href="examples/logo/main.mojo">examples/logo</a> for the source code.</sub>
</p>

You can run the program yourself from the root of this repo using `pixi run example logo` (`logo` being the name of this specific example). The other programs under [examples/](examples/) can be run the same way. Run `pixi run example` with no name to list them all.

## Features

- **Shapes and curves**: rectangles, circles, ellipses, capsules, triangles, sectors and polygons (rounded corners optional), plus lines, arcs, Béziers and splines ([polygons](examples/polygons/main.mojo), [spline](examples/spline/main.mojo))
- **Styling**: fills, strokes, gradients, drop and inset shadows, tint, opacity and blend modes ([gradients](examples/gradients/main.mojo), [shadows](examples/shadows/main.mojo), [blending](examples/blending/main.mojo))
- **Text**: any font, with weights and italics; Noto Sans built in ([poster](examples/poster/main.mojo))
- **Images and animation**: PNG, JPEG and BMP images, sprite animation, tweens and easing curves ([image](examples/image/main.mojo), [animation](examples/animation/main.mojo), [tween](examples/tween/main.mojo))
- **Input**: keyboard, mouse and gamepads, plus text entry ([gamepad](examples/gamepad/main.mojo), [typing](examples/typing/main.mojo))
- **Collisions**: overlap, containment and intersection tests between every shape ([collisions](examples/collisions/main.mojo))
- **Camera and transforms**: a world camera, a fixed overlay for the HUD, and clipping ([camera](examples/camera/main.mojo), [transforms](examples/transforms/main.mojo), [clipping](examples/clipping/main.mojo))
- **Audio**: WAV, OGG, FLAC and MP3 playback ([audio](examples/audio/main.mojo))
- **Pixels and capture**: read back what has been drawn, draw offscreen and record GIFs ([pixels](examples/pixels/main.mojo), [offscreen](examples/offscreen/main.mojo), [capture](examples/capture/main.mojo))
- **Data**: CSV/TSV tables and JSON ([data](examples/data/main.mojo))
- **Randomness and noise**: seeded random numbers and smooth noise ([noise](examples/noise/main.mojo))

## How a Program Works

Below is a small "Hello, world!" program, which can be run from the repo root using `pixi run example hello`:

```mojo
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
        # Called once per frame: handle input, modify state and draw to the screen
        canvas.font_size(48)
        canvas.text(self.greeting, self.position)


def main() raises:
    run[MyApp]("Hello")
```

When writing a **Create** program, you write a struct implementing the `Program` trait, then pass it to `run` in `main`, which starts the run loop. The `Program` trait requires you to implement two methods:

- `create`: a static factory, which is called only once when the run loop starts. This is where initial state is set and the first frame is drawn.
- `update`: an instance method, which is called once for each following frame. This is where you handle input, modify state and draw to the screen.

`@fieldwise_init` saves boilerplate by generating the struct's constructor from its fields.

Rendering runs on the CPU by default. `backend=RenderBackend.GPU` runs the same program through an OpenGL 3.3 backend instead:

```mojo
run[MyApp]("Hello", backend=RenderBackend.GPU)
```

`RenderBackend.from_arguments()` lets the command line choose: the GPU when the program is run with a `gpu` argument, the CPU otherwise.

```mojo
run[MyApp]("Hello", backend=RenderBackend.from_arguments())
```

## Installation and Setup

If you don't already have it, install [pixi](https://pixi.sh):

```sh
curl -fsSL https://pixi.sh/install.sh | sh
```

Create a project with the MAX and Modular community conda channels enabled:

```sh
pixi init my-project \
  -c https://conda.modular.com/max \
  -c https://repo.prefix.dev/modular-community \
  -c conda-forge
```

Then `cd` into the project and add the `mojo` and `create` packages:

```sh
cd my-project
pixi add mojo create
```

You are now ready to add a `main.mojo` file and write your first **Create** program. To get started, you can copy the structure of the "Hello, world!" program from [How a Program Works](#how-a-program-works) or any of the other programs in [examples/](examples/).

Run your project with:

```sh
pixi run mojo run main.mojo
```

The [user guide](docs/README.md) covers the library topic by topic. A CLI tool to streamline this setup is coming soon, along with an API reference and tutorials.

## Documentation

- [User guide](docs/README.md): how to use **Create**, topic by topic.
- [Contributing](CONTRIBUTING.md): how to work on **Create** itself: its design ethos, building and testing, and how changes land.
- [Architecture](ARCHITECTURE.md): how the source is organised, and which package may import which.

## Supported Platforms

| Platform | Status |
|----------|--------|
| Linux (x86-64) | Supported, used day to day |
| Windows through WSL2 | Supported, used day to day |
| macOS on Apple silicon | Built and tested by a CI workflow run on demand, not on every change; little use on a real desktop yet |

Intel Macs and native Windows are not supported: Mojo doesn't run on either. Every dependency, Mojo included,
comes from [pixi](https://pixi.sh), so `pixi run` is all a supported machine needs. A program built with
`mojo build` finds those libraries itself, from any directory, while the pixi environment it was built in
stays where it is.
