<p align="center">
    <img src="assets/logo/png/logo-trim.png" width="150" alt="Create Logo">
</p>

<h1 align="center">Create</h1>

> Note: APIs are experimental and subject to change.

---

**Create** is a creative coding library for [Mojo](https://mojolang.org/), inspired by
[Processing](https://processing.org/). It combines the simplicity and immediacy of creative coding
with a structured, modular API, so it works not only for quick sketches but also for small- to
medium-sized projects such as 2D games, simulations and visualisations.

With **Create**, you can draw shapes, text and images and style them with fills, strokes, gradients
and shadows. You can animate objects, play sounds, load CSV and JSON data, and read input from
keyboards, mice and gamepads. **Create** also provides mathematical helpers for working with
geometry as well as scalars, vectors and matrices. It renders on the CPU by default but can also use
the GPU through [OpenGL](https://www.opengl.org/).

## Example programs

The GIF below shows an example program running. First, it generates a [Sierpiński
triangle](https://en.wikipedia.org/wiki/Sierpi%C5%84ski_triangle) using the random midpoint method
(also known as the [chaos game](https://en.wikipedia.org/wiki/Chaos_game)). Then coloured triangles
grow into place on top of it, forming the **Create** logo.

<p align="center">
    <img src="assets/gifs/logo-animation.gif" alt="The Create logo assembling: a Sierpiński triangle drawn in points, then the logo's triangles growing in over it">
    <br>
    <sub>The logo drawn, animated and recorded to a GIF using the <b>Create</b> library itself. See <a href="examples/logo/main.mojo">examples/logo</a> for the source code.</sub>
</p>

You can run the program yourself from the root of this repo using `pixi run example logo` (`logo`
being the name of this specific example). The other programs under [examples/](examples/) can be run
the same way. Run `pixi run example` with no name to list them.

## How a program works

Below is a small "Hello, world!" program, which can be run from the repo root using `pixi run
example hello`:

```mojo
from create import *

@fieldwise_init
struct MyApp(Program):
    var greeting: String
    var position: Point

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> MyApp:
        return MyApp("Hello, world!", (0, 0))

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        canvas.font_size(48)
        canvas.text(self.greeting, self.position)

def main() raises:
    run[MyApp]("Hello")
```

A **Create** program is a struct implementing the `Program` trait, passed to `run` in `main`, which
starts the run loop. `create` is called once when the run starts, to set the initial state and draw
the first frame; `update` is called for every frame after that, to handle input, change the state
and draw. For more details, read [programs.md](docs/guide/basics/programs.md) in the user guide.

## Installation and setup

If you don't already have it, install [pixi](https://pixi.sh):

```sh
curl -fsSL https://pixi.sh/install.sh | sh
```

Now, install the [create-cli](https://github.com/create-framework/create-cli):

```sh
pixi global install create-cli --channel https://prefix.dev/create-framework/create
```

Create and run your first project:

```sh
create new my-project
cd my-project
create run            
```

You are now ready to write your first **Create** program!

For more installation options, see [setup.md](docs/guide/basics/setup.md) in the user guide.

## Documentation

The [user guide](https://create-framework.org/latest/guide/) explains how to use **Create**, topic
by topic, while the [API reference](https://create-framework.org/latest/reference/) lists every type
and function, package by package. They are published together at
[create-framework.org](https://create-framework.org/) for the latest release as well as for the head
of `main`.

Both can also be found in Markdown format here in the repository together with the documentation for
contributors:

- [User guide](docs/guide/README.md): how to use **Create**, topic by topic.
- [API reference](docs/reference/README.md): every public type and function, package by package,
  generated from the docstrings.
- [Contributing](CONTRIBUTING.md): how to work on **Create** itself: its design ethos, building and
  testing, and how changes land.
- [Architecture](ARCHITECTURE.md): how the source is organised, and which package may import which.

## Supported platforms

| Platform | Status |
|----------|--------|
| Linux (x86-64) | Supported, used day to day |
| Windows through WSL2 | Supported, used day to day |
| macOS on Apple silicon | Built and tested by a CI workflow on demand, not on every change; little use on a real desktop yet |

Intel Macs and native Windows are not supported: Mojo doesn't run on either. Every dependency, Mojo
included, comes from [pixi](https://pixi.sh), so `pixi run` is all a supported machine needs. A
program built with `mojo build` finds the libraries it needs, regardless of which directory it is
run from, as long as the pixi environment it was built in stays where it is.
