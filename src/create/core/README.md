# `create.core` internals

Internals of the run loops. The [user guide](../../../docs/README.md) covers the consumer API,
[ARCHITECTURE.md](../../../ARCHITECTURE.md) the layering rules; the render side is in
[../render/README.md](../render/README.md).

## Files

| File | Role |
|---|---|
| `run.mojo`, `_run_gl.mojo` | Windowed loops: CPU, and GPU (`backend == RenderBackend.GPU`) |
| `headless.mojo`, `_headless_gl.mojo` | `run_headless` over an owned buffer, CPU and GPU |
| `_step.mojo` | `first_step` — frame 1, drawn by `create` — and `step`, every later frame's body |
| `_window_loop.mojo` | Shared by both windowed loops over `NativeWindow`: `_apply_window_dials` (title, resizable, cursor — before presenting), `_apply_window_mode` (after presenting), `_finish_frame` (rumble, frame-rate cap) |
| `_events.mojo` | `apply_events` — the one `Event` fold, into `context.keyboard`, `context.mouse` and the gamepads, through each device's per-event methods |
| `context.mojo`, `time.mojo` | The run state the loop owns and the program reads: `Context` and its `time` reading. Its devices (`keyboard`, `mouse`, `_gamepads`) are `create.input`'s |
| `editable_text.mojo` | `EditableText`, a consumer of `Context` rather than run state: it replays `keyboard._strokes` and reaches the clipboard, which is why it sits in `core` and not `input` |
| `date_time.mojo` | `DateTime`, the wall clock via libc `clock_gettime` + `localtime_r`. Not run state: nothing in the loop touches it |

## Rules

Every loop runs frame 1 through `first_step` and every later frame through `step`, and both
windowed loops fold events through `apply_events`, so they cannot drift in what a frame is or how
input is read. Loops differ only in how a frame starts (events and a clock, or a counter) and where
the pixels go.

**Order at startup:** seed `Context` from `run`'s arguments, derive the viewport
(`_wait_for_dimensions`, or `_set_viewport` headless), then `first_step` — `create` draws frame 1
under that mapping, with `context._count_frame()` and no clock tick — present it, start the clock,
enter the loop. Headless loops re-derive the viewport at the top of every frame, as the windowed
ones do.

**Window dials** (`title`, `resizable`, `cursor`, `lock_mouse`, `text_input`, `window_mode`) are sent only when they changed:
`_AppliedWindow` remembers what the window was last told, seeded from `run`'s arguments (the cursor
from its default, the arrow a new window shows, the pointer free and text input on, as `_SDLWindow` opens it)
before `create` runs, so a dial `create` sets is
sent with frame 1. Title, resizability, cursor, pointer lock and text input go before presenting, so they show with their
frame; the mode goes after, since the frame just presented was laid out for the old size. `set_mode`
in `_window` leaves the current mode before entering the next; restore and maximize are requests a
window manager may refuse, so they never raise.

**Cursors** map from `Cursor` to `_window`'s `SYSTEM_CURSOR_*` ids in `_system_cursor`, so no SDL
name reaches `core`. `HIDDEN` is `show_cursor(False)` and sets no shape; leaving it shows the cursor
before setting the new one. `_SDLWindow` creates each system cursor on first use and keeps it (SDL
shows a cursor without holding it), freeing them before the window in `__deinit__`. A driver
without cursors (dummy, offscreen) refuses them, which never raises. SDL's cursor is the process's,
not a window's: one window a run, so the same thing.

The loop owns one `Context` for the whole run and writes the frame's readings into it:
`context._advance_frame` (clock tick and frame count) before each `step`, `apply_events` into the devices. There is no separate
input state or clock in a loop, and `step` takes only `(program, context, state)`. Every frame's
`Canvas` comes from `context._new_canvas(state^)` and every remap from `context._set_viewport`, so
the mapping dials reach `render` in one place.

`apply_events` keeps only what needs the loop: mapping pointer positions into screen space and the
Escape quit. Every write to a device goes through one of its `_`-prefixed methods
(`keyboard._key_down`, `mouse._button_down`, `_gamepads._axis_moved`, …), which own the bookkeeping
— auto-repeat, edges, slots — and `context._new_input_frame()` clears every device's edges at the top
of a frame, windowed and headless alike. `FocusLost` releases everything held (`context._release_held()`):
SDL sends a window nothing for keys and buttons let go while it is unfocused. Pointer positions and
the wheel stay `Float64` from SDL to the `Mouse`: a HiDPI display reports fractional logical
positions, a trackpad fractional notches, and a frame's wheel events add up. `mouse.movement` is
SDL's relative motion mapped like a position (scaled, y flipped) by mapping both ends of it, and
adds up the same way; it keeps counting under `SDL_SetWindowRelativeMouseMode`, which `lock_mouse`
turns on.

SDL's dummy driver (the window tests') hides, shows and refocuses every window a process opens on
its own, so window tests read events through `events_without_focus` in `tests/window/_raw_event.mojo`.

**Gamepads are opened in `_window`, read in `input`.** SDL sends no axis or button events for a pad
until it is opened, so `_SDLWindow.events()` — the one event pump both windows own — tries
`translate_gamepad_device` before `translate_event`: it opens a pad on added (reading its name, which needs the open pad) and closes
it on removed, and a pad that fails to open is never announced. `apply_events` only assigns slots by
SDL's id. The gamepad subsystem is best-effort: `SDL.init_subsystems` raises only if video fails, and
a refused gamepad subsystem just means no gamepad events.

**The clipboard is mirrored, not queried.** `Context` keeps the clipboard's text so a program reads
it with no window in reach: the windowed loops seed it from `win.clipboard()` before `create`, and
`_SDLWindow.events()` reads the new text on `SDL_EVENT_CLIPBOARD_UPDATE` into a `ClipboardChanged`
event. `context.clipboard(text)` counts its writes, and `_apply_window_dials` sends each one once —
the count compared against `_AppliedWindow`'s, as a dial's value is. A headless run's clipboard is
the mirror alone.

**Typing is also kept in order.** Beside its sets, `Keyboard` records each key-down (with the
layout's keycode as its label, and the modifiers then held) and each text event as a `_Stroke`,
cleared with the edges, which is what `EditableText` replays.

**Rumble flows the other way.** `context.rumble` queues a request addressed by SDL's id; both
windowed loops send the queue after presenting (`_finish_frame`), and `_advance_frame` empties it, which is also how
the headless loop drops it.

**Take the CPU `Surface` after event processing**, sized from the window, never the viewport:
`Window._resize` reallocates the buffer during events, and a stale extent defeats every raster loop's
clipping — memory corruption, not a crooked frame.

**Size `glViewport` from `drawable_size()`, never `width()`/`height()`** — those are logical sizes
and differ under HiDPI. Re-read after event processing, for the same reason.

**A window's first reported size can be wrong.** Fullscreen fires a bogus `(1, 1)` resize first,
which `_wait_for_dimensions` pumps past; on Wayland frame 1 reports the requested size and frame 2
the display's. The loop re-reads dimensions every frame.

`run_gl` and `_run_headless_gl` create their `GLWindow` before their `GLRenderer`, which needs a
current context, and keep the window alive until the renderer is dropped. The renderer is the
loop's own, passed to `Backend.present_gpu`; the persistent canvas state holds no GPU resources.

**Antialiasing is a `Backend` field the loops seed** from `run`'s argument
(`state._backend.antialiasing`) and `canvas.antialiasing` changes; the CPU replay, every pixel read
and the GL renderer read it at present. GL windows open single-sampled: the renderer multisamples
offscreen (see [../render/README.md](../render/README.md)), headless included.
