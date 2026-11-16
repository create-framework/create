# Context

```mojo
struct Context
```

The run's state: everything that outlives a frame.

Two directions share it. The loop writes the readings — `time`,
`keyboard`, `mouse` and the gamepads — before each `update`, for the
program to read; the program sets the dials, for the
loop to read. Every dial is a method, like the `Canvas` style setters:
`context.autoscale(Autoscale.EXTEND)`, `context.max_frame_rate(30)`.
Called with no arguments, each reads back the value as set, for a debug
overlay or a settings screen to show.

The dials are the run's, not the drawing's: the autoscale mode and design
size the next frame's mapping is derived from, the time scale and pause
the next frame's clock tick reads, and the ones the run loop
reads after a frame has been released, `max_frame_rate`, `quit` and
`rumble`. Drawing settings that outlive a frame, such as the font, the
letterbox colour and the autoclear, are on the `Canvas`.

Handed alongside the `Canvas` to `Program.create`, which draws frame 1,
and to every `Program.update` after it.

**Read at frame construction.** The loop re-derives the viewport from
`autoscale` and the design size at the top of each frame. So a dial turned
part-way through `update` applies to the *next* frame — one frame cannot
record under two mappings. Set them in `create` to have them hold from
frame two, or pass them to `run` to have them hold from frame one.
`max_frame_rate`, `quit` and `rumble` are the exception, and only because
the loop reads them after the frame body returns. A dial read back after such a change
reports the new value, not the one the frame in hand was built with.

Implements `Copyable`, `Deinitable`, `Movable`.

## Fields

- `time: Time`: The frame clock. The run loop ticks it before each `update`; read `delta` and `elapsed` here, and don't write it — the loop derives the next delta from it.
- `keyboard: Keyboard`: The keyboard: keys and typed text. The run loop folds each frame's events into it before `update`, so it is settled for the whole frame. Read it, don't write it: the loop carries it into the next frame.
- `mouse: Mouse`: The mouse: position, buttons and wheel, in screen space. Settled before `update` and carried between frames, like `keyboard`.

## Constructors

```mojo
@staticmethod
def __init__(out self)
```

## Methods

### `design_size`

```mojo
def design_size(self) -> Tuple[Int, Int]
```

The width and height the program is authored in: the size passed to `run` unless set.

```mojo
def design_size(mut self, width: Int, height: Int)
```

Author this program in a fixed world size, scaled to any window.

Overrides the size passed to `run`, so a program can pin its own
coordinate space no matter how it is launched — including fullscreen,
where the window size is the display's rather than the caller's.

Takes effect on the next frame, like every dial here: the frame being
rendered keeps the mapping it was built with, since one frame cannot
record under two of them. `run`'s `width`/`height` are the size
frame 1 is drawn at.

### `autoscale`

```mojo
def autoscale(self) -> Autoscale
```

How the design size maps onto the window. `FIT` unless set.

```mojo
def autoscale(mut self, mode: Autoscale)
```

Choose how the design size maps onto the window — see `Autoscale`.

### `quit_on_escape`

```mojo
def quit_on_escape(self) -> Bool
```

Whether Escape stops the run loop. `True` unless set.

```mojo
def quit_on_escape(mut self, enabled: Bool)
```

Whether Escape stops the run loop. On by default.

### `title`

```mojo
def title(self) -> String
```

The window's title: `run`'s `title` unless set.

```mojo
def title(mut self, title: String)
```

Retitle the window — a score, a level name, an unsaved mark.

Shows with the frame it is set in: the loop applies it before
presenting, and only when it changed, so setting it every frame
costs nothing. A headless run has no window and ignores it.

### `resizable`

```mojo
def resizable(self) -> Bool
```

Whether the user can resize the window: `run`'s `resizable` unless set.

```mojo
def resizable(mut self, enabled: Bool)
```

Let the user drag the window's edges to resize it, or stop them.

Applied with the frame it is set in, like `title`. A headless run
ignores it.

### `cursor`

```mojo
def cursor(self) -> Cursor
```

The mouse cursor over the window: `ARROW` unless set.

```mojo
def cursor(mut self, cursor: Cursor)
```

Change the mouse cursor over the window — `Cursor.CROSSHAIR` for aiming, `HAND` over something clickable — or hide it with `Cursor.HIDDEN`, like Processing's `cursor()` and `noCursor()`.

Shows with the frame it is set in, like `title`, and only when it
changed, so setting it every frame from a hover test costs nothing.
Set it in `create` to have it from the first frame. A headless run
ignores it, and so does a video driver without cursors.

### `lock_mouse`

```mojo
def lock_mouse(self) -> Bool
```

Whether the pointer is locked to the window: `False` unless set.

```mojo
def lock_mouse(mut self, enabled: Bool)
```

Lock the pointer to the window, for a first-person camera or an endless drag: it is hidden and held in place, and the mouse reports only `context.mouse.movement`, which keeps counting where a free pointer would stop at the screen's edge. `False` lets it go.

Applied with the frame it is set in, like `title`. Unlock it for a
pause menu, where the pointer is needed again. A headless run, and a
video driver without a pointer, ignore it.

### `text_input`

```mojo
def text_input(self) -> Bool
```

Whether typing reaches `context.keyboard.text`: `True` unless set.

```mojo
def text_input(mut self, enabled: Bool)
```

Take typed text, or stop.

On by default, so `context.keyboard.text` and an `EditableText` work
with no setup. Taking text is also what opens an input method's
composition window as the user types, and an on-screen keyboard on a
handheld or tablet — so a game played on letter keys switches it off,
and back on while a text field is in use. Keys are read the same
either way; only `text` goes quiet.

Applied with the frame it is set in, like `title`. A headless run
ignores it: there, text is whatever the program feeds in.

### `clipboard`

```mojo
def clipboard(self) -> String
```

The system clipboard's text, empty when it holds none.

Read as it changes, so this costs nothing and is the same all frame:
another program's copy shows from the next frame. A headless run has
a clipboard of its own, empty to start.

```mojo
def clipboard(mut self, text: String)
```

Put `text` on the system clipboard, for pasting anywhere.

Reads back at once; the windowed loops hand it to the system with
the frame it is set in, like `title`.

### `window_mode`

```mojo
def window_mode(self) -> WindowMode
```

How the window presents itself: `run`'s `mode` unless set.

```mojo
def window_mode(mut self, mode: WindowMode)
```

Switch between windowed, fullscreen, borderless and maximized.

Applies from the next frame, like `autoscale`: the frame being drawn
was laid out for the window as it is, so the loop switches after
presenting it, and the next frame is drawn at the new size. Some
compositors take a frame or two longer to report it (gotcha 1 in
docs/guide/programs.md). A window manager may refuse to maximize; a headless
run ignores it.

### `frame_count`

```mojo
def frame_count(self) -> Int
```

Frames rendered so far: 1 in `create`, which draws the first, and 2 during the first `update`.

### `frame_rate`

```mojo
def frame_rate(self) -> Float64
```

Current frames per second, derived from the last frame's real delta, so the time scale does not change it.

`0.0` on the first frame, where `real_delta` is still `0.0` and there
is no prior frame to measure against.

### `max_frame_rate`

```mojo
def max_frame_rate(self) -> Int
```

The frame-rate cap. `0` unless set, meaning uncapped.

```mojo
def max_frame_rate(mut self, fps: Int) raises
```

Limit the loop to at most `fps` frames per second, or lift the cap with `0`.

A cap tighter than the display's own pacing (vsync, or the CPU
backend's always-on vsync) slows the loop by sleeping at the end of
each frame; a cap looser than it does nothing, since presentation is
already waiting on the display. Not enforced by `run_headless`,
which has no wall clock to cap against.

### `time_scale`

```mojo
def time_scale(self) -> Float64
```

How fast the run's scaled time runs against real time. `1.0` unless set.

```mojo
def time_scale(mut self, scale: Float64) raises
```

Run the program's time at `scale` times real time: `0.5` is slow motion, `2.0` double speed.

Scales `context.time.delta` and `elapsed`, and so every `Animator`
and `Tween`, which keep time by them; `real_delta` and
`real_elapsed` are untouched, as are audio and recordings. Applies
from the next frame's tick: the frame being drawn keeps the delta it
was given. Raises on a negative scale, since time does not run
backwards; `0.0` stops time, though `time_paused` is the way to pause,
as it keeps the scale to resume at.

### `time_paused`

```mojo
def time_paused(self) -> Bool
```

Whether the run's scaled time is paused. `False` unless set.

```mojo
def time_paused(mut self, paused: Bool)
```

Pause the program's time, or let it run on.

While paused, `context.time.delta` is zero and `elapsed` holds, so
every `Animator` and `Tween` freezes, and so does anything the
program moves by `delta`. Real time runs on, for a pause menu to
animate by. Separate from `time_scale`, so unpausing returns to the
scale that was set, slow motion included. Applies from the next
frame's tick, like `time_scale`.

### `quit`

```mojo
def quit(mut self)
```

Ask the run loop to stop after the current frame.

Unwinds normally, so the window tears down cleanly and program
destructors run — unlike `std.sys.exit`, which aborts the process.

### `gamepad`

```mojo
def gamepad(self, player: Int = Int(0)) -> Gamepad
```

Player `player`'s gamepad, a copy of its state this frame — player one is 0, the default, so a one-player program needs no argument.

Each pad takes the lowest free slot as it connects and keeps it until
it disconnects. A slot no pad holds reads as a disconnected
`Gamepad()`, all zero and nothing down, so this never fails and needs
no check first.

### `rumble`

```mojo
def rumble(
    mut self,
    seconds: Float64,
    low_frequency: Float64 = 1,
    high_frequency: Float64 = 1,
    player: Int = Int(0),
)
```

Shake player `player`'s gamepad for `seconds`.

Most pads have two motors: `low_frequency` is the heavy one, a thud
or an engine, and `high_frequency` the light buzz; each is 0 (off) to
1 (full). Both at full by default, so `context.rumble(0.2)` is a
short jolt. A new rumble replaces the one running, so
`context.rumble(0, 0, 0)` stops it early. Sent after `update`
returns, like `quit`; a pad without motors, an empty slot and a
headless run ignore it.
