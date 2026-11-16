# create.core

The run: the `Program` trait, `run` and `run_headless`, the run's state (`Context`) and its settings (`WindowMode`, `Cursor`), text entry (`EditableText`) and `source_path`.

## Types

| Type | Description |
|---|---|
| [`Context`](context.md) | The run's state: everything that outlives a frame. |
| [`WindowMode`](windowmode.md) | How the window presents itself: `run`'s `mode`, and `context.window_mode`'s value. |
| [`Cursor`](cursor.md) | The mouse cursor over the window: `context.cursor`'s value. |
| [`EditableText`](editabletext.md) | A line of text being typed into, with a caret and a selection: the state of a text field, without its look. |

## Traits

| Trait | Description |
|---|---|
| [`Program`](program.md) | What `run` and `run_headless` drive: `create`, which draws the first frame, then `update` once per frame after it. |

## Functions

| Function | Description |
|---|---|
| [`source_path`](source_path.md) | `relative`, resolved against the directory of the calling source file; an absolute path is returned as it is. |
| [`run`](run.md) | Open a window and run `P` in it until it quits. |
| [`run_headless`](run_headless.md) | Run `P` without a window — `create`'s frame, then `frames` calls to `update` — and return the last frame as an `Image`, read back with `pixel(x, y)` in image coordinates (top-left origin, y down). |
