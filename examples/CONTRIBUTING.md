# Contributing to the examples

The examples are small, complete programs, each showing one part of Create. They are also learning
material: the user guide links to them, so a reader meets them while learning the library.

## Layout

Every example is a folder, `examples/<name>/`, run from its `main.mojo`, beside any modules and
assets of its own. `pixi run example <name>` runs it, and `pixi run example` with no name lists them
all. `pixi run build-examples` type-checks every example, and a warning fails it, as it fails CI.

## Style

- **Open `main.mojo` with a docstring** saying what the example shows, and how to interact with it
  where it reacts to input: "Hover a row to play its curve."
- **Show one thing.** An example is named after the feature or area it shows, and leaves out what
  doesn't help show it.
- **Name it in the plural** when it is named after a feature you can count, as the user guide's
  pages are: `images`, `tweens`, `polygons`. A name that has no plural keeps its form: a mass noun
  or an activity (`audio`, `noise`, `typing`, `clipping`), something a program has only one of
  (`camera`, `window`), or the program itself (`clock`, `logo`, `platformer`).
- **Write it as a program would.** Import with `from create import *`, and use only the public API:
  an example is copied by readers, so it must not lean on anything a program can't reach.
- **Write it the way the guide teaches.** An example is copied more often than the guide is read, so
  the code around the feature is kept small but is as idiomatic as the feature itself: move by
  `context.time.delta`, place things against the edges with `canvas.left()`, `canvas.top()` and the
  like, use `Point` for locations and `Vector` for movements, and reach for the library's helpers
  (`lerp`, `clamp`, `ease`, `contains`) rather than writing the maths out.
- **Name the numbers.** The colours, and the speeds and sizes a reader might tune, are `comptime`
  constants at the top of the file, named by what they are for: `comptime _BACKGROUND = Color(40,
  40, 44)`, `comptime _PAN_SPEED = 300.0`. Colours taken in turn, such as a pie chart's slices, are
  a list returned by a function named for them (`_slice_color(i)`). A value used for both drawing
  and logic is kept once, such as a `Rectangle` field that is drawn and tested with `contains`.
- **Load assets by relative path**, from the example's own folder: Create resolves a path against
  the source file that names it.
- Comments and the docstring follow the [prose style](../CONTRIBUTING.md#prose-style).

## The project template

[template/](../template/) is where a new project starts:
[create-cli](https://github.com/create-framework/create-cli)'s `create new` copies it, a `main.mojo`
and the `assets/` it loads. The Create package installs the template to `share/create/template`, so
a new project always starts from the template that matches the installed Create. `create new`
replaces `{{name}}` in `main.mojo` with the project's name. The placeholder sits inside a string, so
the file builds as it is. `build-examples` builds the template along with the examples, so a change
to the API that breaks the template fails CI here, and is fixed in the same pull request.
