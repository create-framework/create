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
- **CPU or GPU rendering**: every program runs on a CPU rasteriser or through OpenGL 3.3, chosen at startup

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

A **Create** program is a struct implementing the `Program` trait, passed to `run` in `main`, which starts the run loop. `create` is called once when the run starts, to set the initial state and draw the first frame; `update` is called for every frame after that, to handle input, change the state and draw. [Programs](docs/programs.md) in the user guide explains the rest.

## Installation and Setup

If you don't already have it, install [pixi](https://pixi.sh):

```sh
curl -fsSL https://pixi.sh/install.sh | sh
```

### Option 1: create-cli

The [create-cli](https://github.com/create-framework/create-cli) makes creating and running projects very easy. Running this command installs it to `~/.pixi/bin`:

```sh
pixi global install create-cli --channel https://prefix.dev/create-framework/create
```

Make a project and run it:

```sh
create new my-project
cd my-project
create run
```

`create new` makes a pixi project with the `mojo` and `create` packages and a `main.mojo` to start from, and `create run` runs it from anywhere inside the project.

### Option 2: pixi

If you don't want to use the create-cli, you can set up the pixi project by hand. Create it with the MAX and Modular community conda channels enabled:

```sh
pixi init my-project \
  -c https://conda.modular.com/max \
  -c https://repo.prefix.dev/modular-community \
  -c conda-forge
```

Then `cd` into the project, add the `mojo` and `create` packages:

```sh
cd my-project
pixi add mojo create
```

Now, you can write your `main.mojo`, and use the following command to run it:

```sh
pixi run mojo run main.mojo
```

## Documentation

- [User guide](docs/README.md): how to use **Create**, topic by topic.
- [Contributing](CONTRIBUTING.md): how to work on **Create** itself: its design ethos, building and testing, and how changes land.
- [Architecture](ARCHITECTURE.md): how the source is organised, and which package may import which.

API reference and tutorials are coming soon.

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
