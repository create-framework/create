# Programs

A Create program is a struct that implements the `Program` trait, handed to `run`. The
[README](../README.md#how-a-program-works)'s "Hello, world!" shows a simple one; this page
explains how a program runs, where its state lives, which settings belong to the run and how long
each one lasts. Coming from Processing? [Coming from Processing](processing.md) lists what works
differently.

## `create` and `update`

`Program` asks for two methods:

- `create(mut context, mut canvas)`, a static method called once when the run starts. It returns
  the program's initial state, and draws the first frame.
- `update(mut self, mut context, mut canvas)`, called once for every frame after that. It reads
  input, changes the program's state and draws the frame.

## Example program

A program that draws a circle at the mouse, orange while the left mouse button is held and blue
otherwise:

```mojo
from create import *


@fieldwise_init
struct Example(Program):
    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> Example:
        return Example()

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        canvas.background(Color.WHITE)
        if context.mouse.down():  # held this frame; the left button by default
            canvas.fill(Color.ORANGE)
        else:
            canvas.fill(Color.BLUE)
        canvas.circle(context.mouse.position, 40)


def main() raises:
    run[Example]("Example")
```

`@fieldwise_init` writes the struct's constructor from its fields, so use it on program structs.
Every frame starts cleared to light gray, so a program needs no background call to get a clean
frame. `canvas.background(...)` paints the frame another colour, and paints over everything drawn
before it, so call it before anything else you draw (see [Drawing](drawing.md#the-background)).
See [examples/sidescroller](../examples/sidescroller/main.mojo) for a complete bigger program.

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
[The run's settings](#the-runs-settings)).

**The backend** is fixed for the run. Rendering runs on the CPU by default;
`RenderBackend.GPU` runs the same program through an OpenGL 3.3 backend instead. The two draw
the same frame, apart from tiny differences along antialiased edges:

```mojo
# In `main`:
run[Example]("Example", backend=RenderBackend.GPU)
```

`RenderBackend.from_arguments()` lets the command line choose: the GPU when the program is run
with a `gpu` argument (`./example gpu`), the CPU otherwise. Other arguments are left for the
program. [examples/backends](../examples/backends/main.mojo) reads it this way, so
`pixi run example backends` and `pixi run example backends gpu` compare the two.

```mojo
# In `main`:
run[Example]("Example", backend=RenderBackend.from_arguments())
```

## The first frame

**`create` draws frame 1**, like Processing's `setup`: its `canvas` is an ordinary frame, and what
you draw there is the first thing on screen. (The window's size may not be final yet; see [The
window's size on the first frame](#the-windows-size-on-the-first-frame).) In `create`,
`context.frame_count()` is 1 (it is 2 in the first `update`), `context.time` is zero and no key or
button is down.

`create` has no `self` yet. To draw something that needs the program's fields, build the program
in a local variable first and draw through it:

```mojo
# In a program with a `draw(mut self, mut canvas: Canvas)` method of its own:
@staticmethod
def create(mut context: Context, mut canvas: Canvas) raises -> Self:
    var program = Self(...)
    program.draw(canvas)
    return program^
```

`run_headless(frames=N)`, which runs a program without a window (for tests), runs `create`'s
frame and then N `update`s, so `frames=0` gives `create`'s frame alone.

## Parameters and fields

What the loop hands `create` and every `update` is a parameter:

- **`Context`** is the run's state and outlives the frame. Its *readings*, the time and the input
  devices, are filled in by the loop before each `update`: it advances `context.time` and records
  what happened to `context.keyboard`, `context.mouse` and the gamepads
  (`context.gamepad(player)`). Read them, but don't change them: the loop works out the next
  frame's readings from them. Input only arrives this way; there are no event callbacks. See
  [Input](input.md).
- **`Canvas`** is where this frame is drawn. The loop builds a fresh one every frame, so don't
  keep it in a field; draw on the one each call receives.

Everything else the program keeps from frame to frame is a field, built in `create`: an `Image`,
`Font`, `Sound`, `Audio`, `Animator`, `Camera`, `Tween`, `Noise`, a `Table` or `JSON`, or an
offscreen `Canvas(width, height)`, which, unlike the frame's canvas, is the program's own to keep
(see [Drawing into an image](pixels.md#drawing-into-an-image)).

## Assets and playheads

An `Image`, `Font`, `Animation` or `Sound` is a shared, immutable **asset**. It shares its data
itself, so a plain field or a copy is cheap and nothing needs wrapping in an `ArcPointer`.

An `Animator`, or a `Voice` (what `audio.play` and `audio.loop` return), is a **playhead**: one
entity's position in an asset. Two enemies sharing one walk `Animation` each have their own
`Animator`. An animator, like a `Tween`, keeps time on its own: it reads its position off the
run's clock, so nothing ticks it. How to drive one is in
[Animation](animation.md#sprite-animation).

## What lasts how long

Some things reset every frame, some last until a `with` block ends, and some last until changed:

| What | Lasts | Where it is explained |
|---|---|---|
| Style (`fill`, `stroke`, `font`, …) and `camera`, set with a plain call | Until the end of the frame | [Style](style.md), [Coordinates](coordinates.md#the-camera) |
| Anything set by a `with` block: `canvas.style(...)`, `transform`, `overlay`, `clip` | Until the block ends | [Drawing](drawing.md#transforms-and-guards) |
| The canvas settings: `autoclear`, `letterbox_color`, `antialiasing` | Until changed; each applies to the whole frame it is set in | [Drawing](drawing.md#settings-that-outlive-the-frame) |
| The run's settings on `Context`: `title`, `design_size`, `cursor`, … | Until changed; when each takes effect is [below](#when-a-change-applies) | [The run's settings](#the-runs-settings) |
| A recording | Until it stops, or the run ends | [Recording](pixels.md#recording) |
| The program's own fields | The whole run | [Parameters and fields](#parameters-and-fields) |

So set the frame's style in `update`, every frame, and the lasting settings once, in `create`.

## The run's settings

`Context`'s settings belong to the run, not the drawing: `design_size`, `autoscale`, `title`,
`window_mode`, `resizable`, `cursor` (see [The cursor](input.md#the-cursor)), `lock_mouse`,
`text_input`, `quit_on_escape`, `max_frame_rate` (see [Frames](time.md#frames)), `time_scale`
and `time_paused` (see [Slowing and pausing time](time.md#slowing-and-pausing-time)). Like the
canvas setters, they are methods, each read back with no arguments:

```mojo
# In `create`:
context.autoscale(Autoscale.EXTEND)
context.title("Level 1")
var mode = context.autoscale()  # Autoscale.EXTEND
```

`Context`'s only fields are the readings: `time`, `keyboard` and `mouse`. The gamepads are
`context.gamepad(player)`, a copy, since there can be several.

Every `run` argument except `backend` can be changed later: `antialiasing` through
`canvas.antialiasing`, the rest through a setting here. Not every setting is a `run` argument:
`cursor`, `quit_on_escape`, `max_frame_rate`, `time_scale` and `time_paused` are set in `create`.

## When a change applies

Each setting takes effect at one of three points:

- **In the frame it is set in**, wherever in `update` it is set: the canvas settings (see
  [Drawing](drawing.md#settings-that-outlive-the-frame)), and `title`, `resizable`, `cursor`,
  `lock_mouse` and `text_input`.
- **From the next frame:** `design_size`, `autoscale` and `window_mode`, which change the frame's
  size or shape, and `time_scale` and `time_paused`, since the frame being drawn already has its
  `delta`. Some compositors report a new window mode's size a frame later still.
- **When `update` returns:** `max_frame_rate`, `quit()` and `rumble()`.

Reading a setting back gives the new value at once, even before it takes effect. Headless runs
ignore the window settings and `rumble`.

## File paths

A relative path given to Create is relative to **the source file that makes the call**, not the
working directory. So an asset beside the program is named as it sits on disk, and is found
wherever the program is run from:

```mojo
# In `create`, in game/main.mojo: opens game/assets/player.png.
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
  is meant relative to the working directory. Make it absolute first with
  `String(cwd() / path)`, using `cwd` from `std.pathlib`.

## Multiple scenes

A program with a menu, a game and a pause screen keeps each scene as a plain field of the root
`Program` (not a `Program` itself) and switches between them with an int field and `if`/`elif`:

```mojo
# From examples/scenes: `Menu` and `Paint` are plain structs.
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

A scene's `update` takes only what it uses (`context` to read input or time, `canvas` to draw),
and a one-shot reset is a plain `enter(...)` method the parent calls before switching, taking
whatever that transition carries. There is no scene trait on purpose: it would force one
`update`/`enter` signature on every scene, and those must vary. Mojo 1.2 has no dynamic trait
dispatch either; to store different types side by side, use `Variant` from `std.utils` and
dispatch with `isa[T]()`. See [examples/scenes](../examples/scenes/main.mojo).

## The window's size on the first frame

**Don't cache pixel dimensions from `create` or the first frame.** A window's first reported size
can be wrong (fullscreen, Wayland); the loop corrects it from the next frame on. Read
`canvas.width()`, `canvas.right()` and the like each frame instead.
