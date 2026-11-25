# `create.app` internals

`create.app` runs a program: the windowed, GPU and headless loops, the `Context` they own and the
program reads, and how window events become input readings. This page is for working on the package:
the [user guide](../../../docs/guide/README.md) covers using it,
[ARCHITECTURE.md](../../../ARCHITECTURE.md) where it sits and the layering rules, and
[../render/README.md](../render/README.md) the render side.

## Files

| File | Role |
|---|---|
| `run.mojo`, `_run_gl.mojo` | `run`, which hands the program to the compiled library, and the windowed loops it runs there (`_run`): CPU, and GPU (`backend == RenderBackend.GPU`) |
| `headless.mojo`, `_headless_gl.mojo` | `run_headless`, the same way, and its loops over an owned buffer, CPU and GPU |
| `_driver.mojo` | `_Driver`, the program's `create` and `update` as C callbacks for the library's loops; `_Host[P]`, which keeps the program; `_RunSettings`, the arguments passed across |
| `_step.mojo` | `first_step` (frame 1, drawn by `create` through the driver) and `step`, every later frame's body |
| `_window_loop.mojo` | Shared by both windowed loops over `NativeWindow`: `_apply_window_dials` (title, resizable, cursor; sent before presenting), `_apply_window_mode` (after presenting), `_finish_frame` (rumble, frame-rate cap) |
| `_events.mojo` | `apply_events`: the one `Event` fold, into `context.keyboard`, `context.mouse` and the gamepads, through each device's per-event methods |
| `context.mojo` | The run state the loop owns and the program reads: `Context`. Its `time` reading is `create.time`'s `Time`, and its devices (`keyboard`, `mouse`, `_gamepads`) are `create.input`'s |

## Rules

**The loops run in the compiled library,** not in the program (see [The compiled
library](../../../ARCHITECTURE.md#the-compiled-library)). `run[P]` and `run_headless[P]` are the
only generic parts: each builds a `_Host[P]` and a `_Driver` over it and calls the library's
`create_run` or `create_run_headless`. Everything below that is non-generic and reached only from
those entry points, so a program compiles none of it. The loops call `driver.create` and
`driver.update` where they called `P.create` and `program.update`; an error either raises comes back
as its message and is raised again on the library's side, and then again on the program's.

Every loop runs frame 1 through `first_step` and every later frame through `step`, and both windowed
loops fold events through `apply_events`, so they cannot drift in what a frame is or how input is
read. Loops differ only in how a frame starts (events and a clock, or a counter) and where the
pixels go.

**Order at startup:**

1. Seed `Context` from `run`'s arguments.
2. Derive the viewport (`_wait_for_dimensions`, or `_set_viewport` headless).
3. Run `first_step`: `create` draws frame 1 under that mapping, with `context._count_frame()` and no
   clock tick.
4. Present frame 1, start the clock, and enter the loop.

Headless loops re-derive the viewport at the top of every frame, as the windowed ones do.

**Window dials** (`title`, `resizable`, `cursor`, `lock_mouse`, `text_input`, `window_mode`) are
sent only when they changed: `_AppliedWindow` remembers what the window was last told. It is seeded
before `create` runs, from `run`'s arguments and from the state `_SDLWindow` opens a window in: the
default arrow cursor, the pointer free and text input on. So a dial that `create` sets is sent with
frame 1. Title, resizability, cursor, pointer lock and text input go before presenting, so they show
with their frame; the mode goes after, since the frame just presented was laid out for the old size.
`set_mode` in `_window` leaves the current mode before entering the next; restore and maximize are
requests a window manager may refuse, so they never raise.

**Cursors** map from `Cursor` to `_window`'s `SYSTEM_CURSOR_*` ids in `_system_cursor`, so no SDL
name reaches `app`. `HIDDEN` is `show_cursor(False)` and sets no shape; leaving it shows the cursor
before setting the new one. `_SDLWindow` creates each system cursor on first use and keeps it (SDL
shows a cursor without holding it), freeing them before the window in `__deinit__`. A driver without
cursors (dummy, offscreen) refuses them, which never raises. SDL's cursor belongs to the process,
not to a window, but a run has one window, so the two are the same.

The loop owns one `Context` for the whole run and writes the frame's readings into it: before each
`step`, `context._advance_frame` ticks the clock (under the time scale and pause) and counts the
frame, and `apply_events` writes into the devices. There is no separate input state or clock in a
loop, and `step` takes only `(program, context, state)`. Each tick, and a new `Context`, publishes
`time.elapsed` and `real_elapsed` to `time`'s process-wide run clock (`_run_clock`), which
`Animator` and `Tween` read instead of being ticked. Every frame's `Canvas` comes from
`context._new_canvas(state^)` and every remap from `context._set_viewport`, so the settings that map
the design onto the window reach `render` in one place.

`apply_events` keeps only what needs the loop: mapping pointer positions into screen space. Every
write to a device goes through one of its `_`-prefixed methods (`keyboard._key_down`,
`mouse._button_down`, `_gamepads._axis_moved`, …), which own the bookkeeping: auto-repeat, edges and
slots. `context._new_input_frame()` clears every device's edges at the top of a frame, windowed and
headless alike. `FocusLost` releases everything held (`context._release_held()`): SDL sends a window
nothing for keys and buttons let go while it is unfocused. Pointer positions and the wheel stay
`Float64` from SDL to the `Mouse`: a HiDPI display reports fractional logical positions, a trackpad
fractional notches, and a frame's wheel events add up. `mouse.movement` is SDL's relative motion,
mapped like a position (scaled, y flipped) by mapping both of its ends, and it adds up the same way.
It keeps counting under `SDL_SetWindowRelativeMouseMode`, which `lock_mouse` turns on.

SDL's dummy driver (the window tests') hides, shows and refocuses every window a process opens on
its own, so window tests read events through `events_without_focus` in
`tests/window/_raw_event.mojo`.

**Gamepads are opened in `_window`, read in `input`.** SDL sends no axis or button events for a pad
until it is opened, so `_SDLWindow.events()`, the one event pump both windows own, tries
`translate_gamepad_device` before `translate_event`. That opens a pad when it is added (reading its
name, which needs the open pad) and closes it when it is removed; a pad that fails to open is never
announced. `apply_events` only assigns slots by SDL's id. The gamepad subsystem is best-effort:
`SDL.init_subsystems` raises only if video fails, and a refused gamepad subsystem just means no
gamepad events.

**The clipboard is mirrored, not queried.** `Context` keeps the clipboard's text so a program reads
it with no window in reach: the windowed loops seed it from `win.clipboard()` before `create`, and
`_SDLWindow.events()` reads the new text on `SDL_EVENT_CLIPBOARD_UPDATE` into a `ClipboardChanged`
event. `context.clipboard(text)` counts its writes, and `_apply_window_dials` sends each one once,
by comparing the count against `_AppliedWindow`'s, as it compares a dial's value. A headless run's
clipboard is the mirror alone.

**Typing is also kept in order.** Beside its sets, `Keyboard` records each key-down (with the
layout's keycode as its label, and the modifiers then held) and each text event as a `_Stroke`,
cleared with the edges, which is what a `text_field`'s editing (`ui`'s `_TextBuffer`) replays.

**Rumble flows the other way.** `context.rumble` queues a request addressed by SDL's id; both
windowed loops send the queue after presenting (`_finish_frame`), and `_advance_frame` empties it,
which is also how the headless loop drops it.

**Take the CPU `Surface` after event processing**, sized from the window, never the viewport:
`Window._resize` reallocates the buffer during events, and a stale extent defeats every raster
loop's clipping. The result is memory corruption, not a crooked frame.

**Size `glViewport` from `drawable_size()`, never `width()`/`height()`.** Those are logical sizes,
and differ under HiDPI. Re-read after event processing, for the same reason.

**A window's first reported size can be wrong.** Fullscreen fires a bogus `(1, 1)` resize first,
which `_wait_for_dimensions` pumps past; on Wayland frame 1 reports the requested size and frame 2
the display's. The loop re-reads dimensions every frame.

`run_gl` and `_run_headless_gl` create their `GLWindow` before their `GLRenderer`, which needs a
current context, and keep the window alive until the renderer is dropped. The renderer is the loop's
own, passed to `Backend.present_gpu`; the persistent canvas state holds no GPU resources.

**Antialiasing is a `Backend` field** (`state._backend[].antialiasing`). The loops seed it from
`run`'s argument, and `canvas.antialiasing` changes it. The CPU replay, every pixel read and the GL
renderer read it at present. GL windows open single-sampled: the renderer multisamples offscreen
(see [../render/README.md](../render/README.md)), headless included.
