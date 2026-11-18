# Programs

A Create program is a struct that implements the `Program` trait, handed to `run`. The
[README](../../../README.md#how-a-program-works)'s "Hello, world!" shows a simple one; this page
explains how a program runs, where its state lives, which settings belong to the run and how long
each one lasts, the window it runs in, and what to do when something goes wrong. If you know
Processing, [Coming from Processing](coming-from-processing.md) lists what works differently, and if
Mojo is new to you, [Mojo](mojo.md) explains the parts of it the examples use.

## `create` and `update`

`Program` asks for two methods:

- `create(mut context, mut canvas)`, a static method called once when the run starts. It returns the
  program's initial state, and draws the first frame.
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
Every frame starts cleared to light grey, so a program needs no background call to get a clean
frame. `canvas.background(...)` paints the frame another colour, and paints over everything drawn
before it, so call it before anything else you draw (see [The
canvas](../drawing/canvas.md#the-background)). See
[examples/sidescroller](../../../examples/sidescroller/main.mojo) for a complete bigger program.

## Running a program

`run[P](title)` opens a window and runs `P` in it until it quits. Its other arguments are keywords
with defaults:

| Argument | Default | What it sets |
|---|---|---|
| `mode` | `WindowMode.WINDOWED` | `WINDOWED`, `MAXIMIZED`, `FULLSCREEN` or `BORDERLESS` |
| `width`, `height` | `1280`, `720` | The design size, see [Coordinates](coordinates.md#design-size-and-autoscale) |
| `backend` | `RenderBackend.CPU` | Which renderer draws the frames, below |
| `resizable` | `True` | Whether the user can resize the window |
| `antialiasing` | `Antialiasing.MEDIUM` | See [The canvas](../drawing/canvas.md#antialiasing) |
| `autoscale` | `Autoscale.FIT` | How the design size maps onto the window |

Every argument but `backend` is only a starting value, changed later through a setter (see [The
run's settings](#the-runs-settings)).

**The backend** is the part of the computer that draws the frames, and it is fixed for the run. By
default the CPU draws them; `RenderBackend.GPU` draws the same program on the graphics card, through
OpenGL 3.3, instead. The two draw the same frame, apart from tiny differences along smoothed
(antialiased) edges:

```mojo
# In `main`:
run[Example]("Example", backend=RenderBackend.GPU)
```

`RenderBackend.from_arguments()` lets the command line choose: the GPU when the program is run with
a `gpu` argument (`./example gpu`), the CPU otherwise. Other arguments are left for the program.
[examples/backends](../../../examples/backends/main.mojo) reads it this way, so `pixi run example
backends` and `pixi run example backends gpu` compare the two.

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

`create` has no `self` yet. To draw something that needs the program's fields, build the program in
a local variable first and draw through it:

```mojo
# In a program with a `draw(mut self, mut canvas: Canvas)` method of its own:
@staticmethod
def create(mut context: Context, mut canvas: Canvas) raises -> Self:
    var program = Self(...)
    program.draw(canvas)
    return program^
```

`run_headless[P](width, height, frames=N)` runs a program without a window, as tests do. It runs
`create`'s frame and then N `update`s, and returns the last frame as an `Image`, so `frames=0` gives
`create`'s frame alone.

## Parameters and fields

What the loop hands `create` and every `update` is a parameter:

- **`Context`** is the run's state and outlives the frame. Its *readings*, the time and the input
  devices, are filled in by the loop before each `update`: it advances `context.time` and records
  what happened to `context.keyboard`, `context.mouse` and the gamepads (`context.gamepad(player)`).
  Read them, but don't change them: the loop works out the next frame's readings from them. Input
  only arrives this way; there are no event callbacks. See [Input](../interaction/input.md).
- **`Canvas`** is where this frame is drawn. The loop builds a fresh one every frame, so don't keep
  it in a field; draw on the one each call receives.

Everything else the program keeps from frame to frame is a field, built in `create`: an `Image`,
`Font`, `Sound`, `Audio`, `Animator`, `Camera`, `Tween`, `Noise`, a `Table` or `JSON`, or an
offscreen `Canvas(width, height)`, which, unlike the frame's canvas, is the program's own to keep
(see [Drawing into an image](../media/images.md#drawing-into-an-image)).

## Assets and playheads

An `Image`, `Font`, `Animation` or `Sound` is an **asset**: data loaded once and never changed.
Copies of an asset share its data rather than duplicating it, so keeping one in a plain field, or
copying it, is cheap, and nothing needs wrapping in an `ArcPointer` to share it.

An `Animator`, or a `Playback` (what `audio.play` and `audio.loop` return), is a **playhead**: one
thing's place in an asset, as a record player's needle is its place in a record. Two enemies sharing
one walk `Animation` each have their own `Animator`, so each can be at its own point in the walk. An
animator, like a `Tween`, keeps time on its own: it works out its place from the run's clock
whenever it is asked, so nothing needs to update it each frame. How to drive one is in
[Animations](../motion/animations.md).

## What lasts how long

Some things reset every frame, some last until a `with` block ends, and some last until changed:

| What | Lasts | Where it is explained |
|---|---|---|
| Style (`fill`, `stroke`, `font`, …) and `camera`, set with a plain call | Until the end of the frame | [Style](../drawing/style.md), [Coordinates](coordinates.md#the-camera) |
| Anything set by a `with` block: `canvas.style(...)`, `transform`, `overlay`, `clip` | Until the block ends | [The canvas](../drawing/canvas.md#transforms-and-guards) |
| The canvas settings: `autoclear`, `letterbox_color`, `antialiasing` | Until changed; each applies to the whole frame it is set in | [The canvas](../drawing/canvas.md#settings-that-outlive-the-frame) |
| The run's settings on `Context`: `title`, `design_size`, `cursor`, … | Until changed; when each takes effect is [below](#when-a-change-applies) | [The run's settings](#the-runs-settings) |
| A recording | Until it stops, or the run ends | [Recording](../media/capture.md#recording) |
| The program's own fields | The whole run | [Parameters and fields](#parameters-and-fields) |

So set the frame's style in `update`, every frame, and the lasting settings once, in `create`.

## The run's settings

`Context`'s settings belong to the run, not the drawing: `design_size`, `autoscale`, `title`,
`window_mode`, `resizable`, `cursor` (see [The cursor](../interaction/mouse.md#the-cursor)),
`lock_mouse`, `text_input`, `quit_on_escape`, `max_frame_rate` (see
[Frames](../motion/time.md#frames)), `time_scale` and `time_paused` (see [Slowing and pausing
time](../motion/time.md#slowing-and-pausing-time)). Like the canvas setters, they are methods, each
read back with no arguments:

```mojo
# In `create`:
context.autoscale(Autoscale.EXTEND)
context.title("Level 1")
var mode = context.autoscale()  # Autoscale.EXTEND
```

`Context`'s only fields are the readings: `time`, `keyboard` and `mouse`. The gamepads are read with
`context.gamepad(player)` instead, since there can be several; it returns a copy.

Every `run` argument except `backend` can be changed later: `antialiasing` through
`canvas.antialiasing`, the rest through a setting here. Not every setting is a `run` argument:
`cursor`, `quit_on_escape`, `max_frame_rate`, `time_scale` and `time_paused` have no argument, so
set them from the program, in `create` for a setting that should hold from the start.

## When a change applies

Each setting takes effect at one of three points:

- **In the frame it is set in**, wherever in `update` it is set: the canvas settings (see [The
  canvas](../drawing/canvas.md#settings-that-outlive-the-frame)), and `title`, `resizable`,
  `cursor`, `lock_mouse` and `text_input`.
- **From the next frame:** `design_size`, `autoscale` and `window_mode`, which change the frame's
  size or shape, and `time_scale` and `time_paused`, since the frame being drawn already has its
  `delta`. Some desktops report a window's new size a frame later still, after a change of window
  mode.
- **When `update` returns:** `max_frame_rate`, `quit()` and `rumble()`.

Reading a setting back gives the new value at once, even before it takes effect. Headless runs
ignore the window settings and `rumble`.

## The window

A program runs in a window, which `run` opens with the title and size it is given. How the window
presents itself is its **mode**, set with `run(..., mode=)` or later with
`context.window_mode(mode)`:

| Mode | The window |
|---|---|
| `WINDOWED` (default) | An ordinary window, with a title bar and a border, at the design size |
| `MAXIMIZED` | An ordinary window, with its title bar, filling the screen apart from the desktop's own bars and docks |
| `FULLSCREEN` | The whole screen, with no title bar, border or desktop around it |
| `BORDERLESS` | A window at the design size, with no title bar or border, for a splash screen or a program that draws its own frame |

In `MAXIMIZED` and `FULLSCREEN`, the window is bigger than the design, and the design is scaled up
to fill it as the [autoscale](coordinates.md#design-size-and-autoscale) mode says. A change of mode
applies from the next frame, since the frame being drawn was laid out for the window as it is. A key
that switches in and out of full screen is a few lines:

```mojo
# In `update`: F11 switches between a window and the full screen.
if context.keyboard.pressed(Key.F11):
    if context.window_mode() == WindowMode.FULLSCREEN:
        context.window_mode(WindowMode.WINDOWED)
    else:
        context.window_mode(WindowMode.FULLSCREEN)
```

`context.title(text)` changes the text in the window's title bar, such as to show the level being
played, and `context.resizable(False)` stops the player from dragging the window's edges to resize
it. Both show from the frame they are set in, and cost nothing to set every frame, since the window
is only told when they change.

**Ending the run.** The run ends in three ways: when the player closes the window; when the program
calls `context.quit()`, once the current `update` returns; and, unless told otherwise, **when the
player presses Escape**. Escape quitting is handy while trying out a sketch, but a game usually
wants Escape for its own pause menu. `context.quit_on_escape(False)` turns the quitting off, so
Escape becomes an ordinary key; then give the player another way out, such as a Quit button in the
menu:

```mojo
# In `create`:
context.quit_on_escape(False)

# In `update`:
if context.keyboard.pressed(Key.ESCAPE):
    self.paused = not self.paused
if self.paused and self.quit_button.contains(context.mouse.position) and context.mouse.pressed():
    context.quit()
```

When the run ends, `run` returns, a recording still running is finished and saved, and `main`
carries on from the line after `run`, if it has any.

## When something goes wrong

**An error ends the run.** `create` and `update` are marked `raises`, so anything inside them may
raise an error: loading a file that isn't there, reading a JSON field that is missing, or a call
given a value it can't use. An error that nothing catches leaves `update`, then `run`, then `main`,
and ends the program: the window closes, and Mojo prints the error's message in the terminal the
program was started from. Create's errors name what went wrong, and a file's path where there is
one, so the message is the first place to look. A recording that was running is left unfinished, as
its `.partial` file (see [Recording](../media/capture.md#recording)).

An error the program expects, such as a save file that doesn't exist yet the first time a game runs,
can be caught with `try` and `except`, so the run goes on (see [Errors](mojo.md#errors)).

**Printing values.** `print(...)` writes to the terminal, and is the simplest way to see what a
program is doing. Every value Create gives you prints the way it would be written in code, so what
you see can be pasted straight back into the program:

```mojo
# In `update`:
print(context.mouse.position)  # Point2D(-120.0, 45.5)
print(Rectangle((0, 0), 100, 50))  # Rectangle(position=Point2D(0.0, 0.0), width=100.0, height=50.0)
print(Color.RED)  # Color(255, 0, 0, 255)
```

Printing every frame floods the terminal quickly, so print when something happens, such as when a
key is pressed, or draw the value on the screen instead, where it updates in place:
`canvas.text(String(self.velocity), (0, canvas.top() - 20))`.

## File paths

A relative path given to Create is relative to **the source file that makes the call**, not the
working directory. So an asset beside the program is named as it sits on disk, and is found wherever
the program is run from:

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
  `makedirs`, resolves against the working directory. Pass it `source_path("...")` to resolve the
  path the way Create's loaders do.
- **A path that arrives while the program runs**, such as a command-line argument or typed text, is
  meant relative to the working directory. Make it absolute first with `String(cwd() / path)`, using
  `cwd` from `std.pathlib`.

## Multiple scenes

A program with a menu, a game and a pause screen keeps each scene as a plain field of the root
`Program` (not a `Program` itself) and switches between them with an `Int` field and `if`/`elif`:

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

A scene's `update` takes only what it uses: `context` to read input or time, `canvas` to draw. To
reset a scene when switching to it, give it a plain `enter(...)` method for the parent to call
first, taking whatever the switch passes on. There is no scene trait, on purpose: a trait would
force the same `update` and `enter` signatures on every scene, and they need to differ. Mojo 1.2 has
no dynamic trait dispatch either. To store values of different types side by side, use `Variant`
from `std.utils`, and check which type it holds with `isa[T]()`. See
[examples/scenes](../../../examples/scenes/main.mojo).

## The window's size on the first frame

**Don't keep the screen's size from `create` or the first frame.** The size a window reports at
first can be wrong: going full screen briefly reports a tiny window, and on Wayland desktops the
first frame reports the size asked for rather than the display's. The loop corrects the size from
the next frame on, so read `canvas.width()`, `canvas.right()` and the like every frame instead of
storing them.
