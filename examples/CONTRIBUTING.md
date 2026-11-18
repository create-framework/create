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
