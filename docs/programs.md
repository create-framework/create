# Programs

Implement `Program` (`create(mut context, mut canvas)` + `update(mut self, mut context, mut canvas)`)
and pass it to `run[T]`. Minimum: [tests/core/test_smoke.mojo](../tests/core/test_smoke.mojo); full shape:
[examples/sidescroller/main.mojo](../examples/sidescroller/main.mojo).

**`create` draws frame 1**, like Processing's `setup`: its `canvas` is a real frame, presented like
every later one, so drawing there shows and geometry is as valid as on any first frame ([gotcha 2](#critical-gotchas)).
`context.frame_count()` is 1 there and 2 in the first `update`; `context.time` is zero and
no key or button is down. Drawing that needs the program's fields builds `Self` into a local first.
`run_headless(frames=N)` runs `create`'s frame and then N `update`s, so `frames=0` returns
`create`'s frame alone. Input arrives on the context's devices — `context.keyboard`,
`context.mouse`, `context.gamepad(player)` — and there are no event callbacks. The frame
`Canvas` the loop hands over is built fresh each frame; nothing may hold it across frames. An
offscreen `Canvas(w, h)` (see [Reading pixels](pixels.md#reading-pixels)) is the program's own and may be kept as a field.

**Multiple screens:** a root `Program` holds each screen as a plain field (not implementing
`Program`) and switches with an int field and `if`/`elif`. A scene's `update` takes only what it uses
(`context` to read input or time, `canvas` to draw); a one-shot reset is a plain `enter(...)` method the parent calls before
switching, taking whatever that transition carries. No trait: it would force one `update`/`enter`
signature on every scene, and those must vary. See [examples/scenes/main.mojo](../examples/scenes/main.mojo).
(Mojo 1.2 has no dynamic trait dispatch; heterogeneous storage is `Variant` from `std.utils`, with
`isa[T]()` to dispatch.)

**Parameter vs. field:** what the loop hands `create` and every `update` (`Context`, `Canvas`) is a
parameter: `Context` is the run's state and outlives the frame, `Canvas` is where this frame is
drawn. What the program drives on its own schedule (`Image`, `Font`, `Sound`, `Audio`,
`Animator`, `Camera`, `Tween`, `Noise`, a `Table` or `JSON`, an offscreen `Canvas`) is a field it constructs in `create` — so adding one touches
neither `Program` nor the run loop. The readings live on `Context`: the loop ticks
`context.time` and folds events into `context.keyboard`, `context.mouse` and the gamepads before
`update`. Read them, don't write them — the loop carries them into the next frame.

**Per-frame obligations**, not enforced by anything:
- `audio.update()` — otherwise looping streams stall and one-shot voice slots leak.
- `animator.update(context.time.delta)` / `tween.update(context.time.delta)` — otherwise the playhead
  never moves.

Shared assets (`Image`, `Font`, `Animation`, `Sound`) share their data themselves, so a plain
field or copy is cheap and nothing is wrapped in an `ArcPointer`. An animator's `use(anim)` is
the per-frame selector (the animation already held is left as it is, paused or finished included);
`play`/`loop`, with or without an animation, are commands and always start from frame 0. Read
[`Animator`](../src/create/image/animator.mojo) before driving one.

## Critical gotchas

1. **Resolve asset paths with `source_path(...)`**, not bare relative paths (those resolve against
   the CWD) — `Image.load`, `Font.load`, `Sound.load` alike. It resolves against the calling source
   file, baked in at compile time as an absolute path, so a `mojo build` binary finds its assets
   from any directory, as long as they stay where they were at build time. Tests assume the repo
   root as CWD, which `pixi run test` guarantees.

2. **Don't cache pixel dimensions from `create` or the first frame.** A window's first reported size
   can be wrong (fullscreen, Wayland); the loop corrects it from the next frame on.

## Do

- Use `@fieldwise_init` on program structs.
- Make `canvas.background(...)` the first render call in `update`. With the autoclear off, call
  `canvas.autoclear(False)` and `canvas.background(...)` once, in `create`.

## Terms

| Term | Meaning |
|---|---|
| Asset vs. playhead | `Image`/`Font`/`Animation`/`Sound` are shared immutable assets; `Animator`/a `Voice` (what `audio.play` and `audio.loop` return) are one entity's position in one. `fps` belongs to the asset |
