# Programs

A Create program is a struct that implements the `Program` trait, handed to `run`. The
[README](../README.md#how-a-program-works)'s "Hello, world!" shows the smallest one; this page
explains how a program runs, where its state lives, and the few things each frame needs.

## `create` and `update`

`Program` asks for two methods:

- `create(mut context, mut canvas)`, a static method called once when the run starts. It returns
  the program's initial state, and draws the first frame.
- `update(mut self, mut context, mut canvas)`, called once for every frame after that. It reads
  input, changes the program's state and draws the frame.

If you know Processing, `create` is `setup` and `update` is `draw`. A program that moves a ball
and turns it around with the space bar:

```mojo
from create import *


@fieldwise_init
struct Ball(Program):
    var position: Point2D
    var velocity: Vector2D

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> Ball:
        return Ball((0, 0), Vector2D(120, 80))

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        canvas.background(Color.WHITE)
        if context.keyboard.pressed(Key.SPACE):
            self.velocity = -self.velocity
        self.position = self.position + self.velocity * context.time.delta
        canvas.fill(Color.ORANGE)
        canvas.circle(self.position, 20)


def main() raises:
    run[Ball]("Ball")
```

`@fieldwise_init` writes the struct's constructor from its fields, so use it on program structs.
Make `canvas.background(...)` the first render call in `update`; with the autoclear off (see
[Drawing](drawing.md#the-background)), call `canvas.autoclear(False)` and `canvas.background(...)`
once, in `create`, instead. A complete, bigger program is
[examples/sidescroller](../examples/sidescroller/main.mojo); the smallest that builds is
[tests/core/test_smoke.mojo](../tests/core/test_smoke.mojo).

## Running a program

`run[P](title)` opens a window and runs `P` in it until it quits. Its other arguments are
keywords with defaults:

| Argument | Default | What it sets |
|---|---|---|
| `mode` | `WindowMode.WINDOWED` | `WINDOWED`, `MAXIMIZED`, `FULLSCREEN` or `BORDERLESS` |
| `width`, `height` | `1280`, `720` | The design size, see [Coordinates](coordinates.md#design-size-and-autoscale) |
| `backend` | `RenderBackend.CPU` | Which renderer draws the frames, below |
| `resizable` | `True` | Whether the user can resize the window |
| `antialiasing` | `Antialiasing.MEDIUM` | See [Drawing](drawing.md#antialiasing) |
| `autoscale` | `Autoscale.FIT` | How the design size maps onto the window |

Every argument but `backend` is only a starting value, changed later through a setter (see
[The run's settings](coordinates.md#the-runs-settings)).

**The backend** is fixed for the run. Rendering runs on the CPU by default;
`RenderBackend.GPU` runs the same program through an OpenGL 3.3 backend instead. The two draw
the same frame, apart from the GPU's multisampled edges:

```mojo
# A fragment, inside `main`.
run[Ball]("Ball", backend=RenderBackend.GPU)
```

`RenderBackend.from_arguments()` lets the command line choose: the GPU when the program is run
with a `gpu` argument (`./ball gpu`), the CPU otherwise. Other arguments are left for the
program. [examples/backends](../examples/backends/main.mojo) reads it this way, so
`pixi run example backends` and `pixi run example backends gpu` compare the two.

```mojo
# A fragment, inside `main`.
run[Ball]("Ball", backend=RenderBackend.from_arguments())
```

## The first frame

**`create` draws frame 1**, like Processing's `setup`: its `canvas` is a real frame, presented like
every later one, so what you draw there shows, and the canvas's geometry is as valid as on any
first frame (but see [gotcha 1](#critical-gotchas)). In `create`, `context.frame_count()` is 1 (it
is 2 in the first `update`), `context.time` is zero and no key or button is down.

`create` has no `self` yet, so drawing that needs the program's fields builds `Self` into a local
first:

```mojo
# A fragment: the program has a `draw(mut self, mut canvas: Canvas)` method of its own.
@staticmethod
def create(mut context: Context, mut canvas: Canvas) raises -> Self:
    var program = Self(...)
    program.draw(canvas)
    return program^
```

`run_headless(frames=N)` runs `create`'s frame and then N `update`s, so `frames=0` returns
`create`'s frame alone.

## Parameters and fields

What the loop hands `create` and every `update` is a parameter:

- **`Context`** is the run's state and outlives the frame. Its readings are filled in by the loop
  before each `update`: it ticks `context.time` and folds events into `context.keyboard`,
  `context.mouse` and the gamepads (`context.gamepad(player)`). Read them, don't write them: the
  loop carries them into the next frame. Input only arrives this way; there are no event
  callbacks. See [Input](input.md).
- **`Canvas`** is where this frame is drawn. The loop builds it fresh each frame, so nothing may
  hold on to it across frames.

Everything the program drives on its own schedule is a field it constructs in `create`: an
`Image`, `Font`, `Sound`, `Audio`, `Animator`, `Camera`, `Tween`, `Noise`, a `Table` or `JSON`,
or an offscreen `Canvas(w, h)` (see [Drawing into an image](pixels.md#drawing-into-an-image)), which is the
program's own. So adding one touches neither `Program` nor the run loop.

## Assets and playheads

An `Image`, `Font`, `Animation` or `Sound` is a shared, immutable **asset**. It shares its data
itself, so a plain field or a copy is cheap and nothing needs wrapping in an `ArcPointer`.

An `Animator`, or a `Voice` (what `audio.play` and `audio.loop` return), is a **playhead**: one
entity's position in an asset. Two enemies sharing one walk `Animation` each have their own
`Animator`. The frame rate, `fps`, belongs to the asset. An animator, like a `Tween`, keeps time
on its own: it reads its position off the run's clock, so nothing ticks it.

An animator's `use(anim)` is the per-frame selector: call it every frame with the animation the
entity should show, and the animation already held is left as it is, paused or finished included.
`play` and `loop`, with or without an animation, are commands and always start from frame 0. Read
[`Animator`](../src/create/image/animator.mojo) before driving one.

## File paths

A relative path given to Create is relative to **the source file that makes the call**, not the
working directory. So an asset beside the program is named as it sits on disk, and is found
wherever the program is run from:

```mojo
# A fragment, inside `create`, in game/main.mojo: opens game/assets/player.png.
var player = Image.load("assets/player.png")
```

- **Every loader and saver works this way:** `Image.load`, `Animation.from_folder`, `Font.load`
  (both paths), `Sound.load`, `Table.load` and `save`, `JSON.load` and `save`, and the canvas's
  `save_image`, `save_screenshot` and `start_recording`. An absolute path is used as it is.
- **A call in another file** resolves against that file, as Python's `__file__` does: a helper in
  `game/enemies/spawn.mojo` loading `"sprites/bat.png"` opens `game/enemies/sprites/bat.png`.
- **Built programs:** the caller's path is baked in at compile time, so a `mojo build` binary finds
  its files from any directory, as long as they stay where they were at build time.
- **Anything else that takes a path**, such as the standard library's `open()`, `listdir` or
  `makedirs`, resolves against the working directory. Give it `source_path("...")` to get the same
  answer Create's loaders do.
- **A path that arrives while the program runs**, such as a command-line argument or typed text,
  means the working directory to whoever gave it. Make it absolute first with
  `String(cwd() / path)`, using `cwd` from `std.pathlib`.

## Multiple screens

A program with a menu, a game and a pause screen keeps each screen as a plain field of the root
`Program` (not a `Program` itself) and switches between them with an int field and `if`/`elif`:

```mojo
# A fragment of examples/scenes: `Menu` and `Paint` are plain structs.
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
```

A screen's `update` takes only what it uses (`context` to read input or time, `canvas` to draw),
and a one-shot reset is a plain `enter(...)` method the parent calls before switching, taking
whatever that transition carries. There is no scene trait on purpose: it would force one
`update`/`enter` signature on every screen, and those must vary. Mojo 1.2 has no dynamic trait
dispatch either; to store different types side by side, use `Variant` from `std.utils` and
dispatch with `isa[T]()`. See [examples/scenes](../examples/scenes/main.mojo).

## Critical gotchas

1. **Don't cache pixel dimensions from `create` or the first frame.** A window's first reported
   size can be wrong (fullscreen, Wayland); the loop corrects it from the next frame on. Read
   `canvas.width()`, `canvas.right()` and the like each frame instead.
