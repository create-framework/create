<p align="center">
    <img src="assets/logo/png/logo-trim.png" width="150" alt="Create Logo">
</p>

<h1 align="center">Create</h1>

> Note: APIs are experimental and subject to change.

---

**Create** is a creative coding library for rapid prototyping and interactive graphics, inspired by Processing but built to scale —
from sketch to game, prototype to full application. It provides a clean, modular API while taking full advantage of Mojo's performance and language features.

## Example Programs

The GIF below shows an example program running. First it generates a [Sierpiński triangle](https://en.wikipedia.org/wiki/Sierpi%C5%84ski_triangle) using the random midpoint method (also known as the [chaos game](https://en.wikipedia.org/wiki/Chaos_game)). 
Then coloured triangles grow into place on top of it, forming the **Create** logo.

<p align="center">
    <img src="assets/gifs/logo-animation.gif" alt="The Create logo assembling: a Sierpiński triangle drawn in points, then the logo's triangles growing in over it">
    <br>
    <sub>The logo drawn, animated and recorded to a GIF using the <b>Create</b> library itself. See <a href="examples/logo/main.mojo">examples/logo</a> for the source code.</sub>
</p>

You can run the program yourself from the root of this repo using `pixi run example logo` (`logo` being the name of this specific example). The other programs under [examples/](examples/) can be run the same way. Run `pixi run example` with no name to list them all.

## How a Program Works

Below is a small "Hello, world!" program, which can be run from the repo root using `pixi run example hello`:

```mojo
from create import *


@fieldwise_init
struct MyApp(Program):
    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> MyApp:
        # Called once: set initial application state and draw the first frame
        return MyApp()

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        # Called once per frame: handle input, modify state, and draw to the screen
        canvas.font_size(48)
        canvas.text("Hello, world!", (0, 0))


def main() raises:
    run[MyApp]("Hello")
```

When writing a **Create** program, you write a struct implementing the `Program` trait, then pass it to `run` in `main`, which starts the run loop. The `Program` trait requires you to implement two methods:

- `create`: a static factory, which is called only once when the run loop starts. This is where initial state is set and the first frame is drawn.
- `update`: an instance method, which is called once per frame after the first. This is where you handle input, modify state, and draw frames 2..N.

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

A CLI tool to streamline this setup is coming soon, along with an API reference, tutorials and more.

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
