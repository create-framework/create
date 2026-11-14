# Contributing to Create

**Create** is a creative coding library for Mojo, inspired by Processing. It combines the
simplicity and immediacy of creative coding with a structured, modular API, so it works not only
for quick sketches but also for small- to medium-sized projects such as 2D games, simulations and
visualisations.

This guide is for anyone working on Create itself: what the project values, how to make a first
change, and then the reference for building, testing, landing changes and the code's
conventions. Using Create is covered in [docs/](docs/README.md), and how its code is organised in
[ARCHITECTURE.md](ARCHITECTURE.md).

## What we value

### Early development

Create is in early development and makes no promise of API stability yet. At this stage breaking
changes are fine. Doc churn and rewriting examples or tests are not reasons to reject an idea;
judge a change on whether it makes the library better.

### Design ethos

The API should embody the following principles:

- **Intuitive:** The API should have a quality of obviousness. Names and behaviours should be easy
  to understand. Avoid abbreviations; prefer clarity over brevity.
- **Ergonomic:** Optimise for the experience of using the library, not for minimising its API
  surface. Common operations should be concise and require minimal ceremony.
- **Modular:** Keep the architecture modular, with clear separation of concerns and minimal
  coupling. Components should be independently understandable and should compose naturally.
- **Consistent:** Similar concepts should be named and behave alike. Establish conventions and
  apply them uniformly rather than introducing special cases without good reason.
- **Composable:** Design APIs and abstractions that work well together. Prefer building blocks
  that can be combined in different ways over rigid, narrowly scoped solutions.
- **Performant:** Performance should be an inherent property of the API, not something users must
  work around. Common operations should be efficient by default, without requiring knowledge of
  internals or specialised APIs to achieve good performance.

## Your first change

Everything Create needs, Mojo included, comes from [pixi](https://pixi.sh); `pixi run` sets up
the environment the first time it is used.

1. **Clone and set up**, once per clone. `pixi run setup` installs the git hooks (see
   [Checks](#checks)) and tells `git blame` to skip the commits listed in
   `.git-blame-ignore-revs`, bulk reformats and renames:

   ```bash
   git clone https://github.com/create-framework/create.git
   cd create
   pixi run setup
   ```

2. **Run something.** `pixi run example` lists the examples; `pixi run example hello` runs one.

3. **Make the change on a branch**, from an up-to-date `main`: `git switch -c some-change`. Read
   [ARCHITECTURE.md](ARCHITECTURE.md) first for where it belongs and what the package may
   import, and the package's README if it has one.

4. **Test what the change can reach**: `pixi run test render` runs one subpackage's tests (see
   [Building and testing](#building-and-testing)), and `pixi run build-examples` type-checks every
   example, which catches a change of the public API. New behaviour gets a test; how tests are
   written is in [tests/README.md](tests/README.md).

5. **Commit** with a [Conventional Commits](#commit-messages) message. The pre-commit hook checks
   the formatting (`pixi run format` fixes it) and builds a smoke test.

6. **Push and open a pull request.** CI runs the whole suite on it, and it merges once CI passes
   (see [Workflow](#workflow)).

## Building and testing

```bash
mojo run -I src examples/sketch/main.mojo      # -I src is required, see below
pixi run example sketch                   # by name; no argument lists them
pixi run benchmark frame                  # benchmarks/, same form; frame cpu for the CPU backend
pixi run test                             # whole suite, concurrent
pixi run test render                      # subpackage, file name sans test_, or path; several allowed
pixi run test -j 4 canvas tween           # pin worker count (default nproc, max 8)
pixi run test --shard 2/4                 # every 4th file from the 2nd; CI runs 4 shards
pixi run precompile                       # type-check the library into build/create.mojoc
pixi run build-examples                   # type-check every example and benchmark; a warning fails it
pixi run check-standalone                 # a `mojo build` program, run outside the environment
pixi run check-package                    # the conda package from recipe/, built and tested as installed
pixi run format                           # 80 columns, enforced by pre-commit
pixi run embed-fonts                      # regenerate text/_noto.mojo after changing a face in text/fonts/
pixi run docs                             # build the documentation site into build/docs/site
pixi run docs-serve                       # preview it, rebuilt as you edit (rerun after a docstring change)
pixi run setup                            # once per clone: git hooks + blame ignore-revs
```

**`-I src` is required for every `mojo run`**, or `from create import *` fails. Pixi tasks add it.

`example` and `benchmark` run against `build/create.mojoc` (`-I build`), not the source: they
depend on `precompile`, which pixi's task cache skips while no `src/create/**/*.mojo` file and
nothing in the environment has changed. So a run with the library unchanged starts in about 2 s
rather than 8; the first one after a library edit pays the ~10 s rebuild. `test`,
`build-examples` and `check-standalone` precompile `src` afresh into a temporary package of their
own and build every file against it, so none is ever stale or re-parses the library per file.

`mojo format`'s grammar is narrower than the compiler's and will abort a commit: `where` is
reserved (not usable as a name), and `;` statement separators don't parse.

### Checks

Two tiers of automated checks, and a third run by hand:

| Where | Runs |
|---|---|
| `pre-commit` hook (after `pixi run setup`) | Formatting check on staged `.mojo` files, then builds `tests/core/test_smoke.mojo`. Constant cost |
| CI ([.github/workflows/ci.yml](.github/workflows/ci.yml)), every PR and push to `main` | Formatting, `mojo precompile`, every example and benchmark, a `mojo build` program run outside the environment (`pixi run check-standalone`), the conda package (`pixi run check-package`), the test suite — a GL test that skips fails the job — and the documentation site (`pixi run docs`). Linux only |
| macOS ([.github/workflows/macos.yml](.github/workflows/macos.yml)), by hand: Actions → macOS → Run workflow, on any branch | The examples, the standalone build and the test suite on Apple silicon (`macos-examples`, `macos-tests`). Not part of CI — a macOS runner costs ten times a Linux one and nobody runs Create on a Mac yet — so run it before relying on a change that could differ there (windowing, GL, library search) |

Neither tier subsumes the other: building a consumer program type-checks only the `def` bodies it
reaches (catches API drift, not an uncalled broken function); `mojo precompile` is the reverse.

The hook and CI skip their checks when every changed path is inert (`*.md`, `LICENSE`,
agent/editor config); the allowlist is in `.githooks/_inert.sh`, read by the hook and the workflow
alike. The documentation site is the exception: Markdown alone can break it, so CI builds it for
every change.

## Workflow

`main` is protected by a ruleset: no direct pushes, no force pushes, no deletion, and a linear
history. Every change lands as a pull request, merged once the required check `ci` passes. It
passes when `linux-docs` passed and `linux-format`, `linux-precompile`, `linux-examples`,
`linux-package` and the four test shards `linux-tests-1`…`linux-tests-4` all passed, or were
skipped for an inert change; no approval is required. **Rebase and merge** is the only merge method enabled: squash and merge
commits are off.

```bash
git switch -c some-change                 # from an up-to-date main
git push -u origin some-change            # pushes run no hook; CI runs on the PR
gh pr create --fill
gh pr merge --auto --rebase               # merges itself once CI is green
git switch main && git pull --ff-only
```

Each of the branch's commits lands on `main` as it is, rebased (new hashes), so every one should
build and carry a finished message; tidy the branch before merging rather than relying on a
squash. The branch need not be up to date with `main` to merge, and the head branch is deleted on
merge. A repository admin may bypass the checks when merging a pull request (CI itself broken),
never for a direct push.

Releases are cut by a maintainer, as [RELEASING.md](RELEASING.md) describes.

### Commit messages

Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/):
`<type>(<package>): <Summary>`, the summary in the imperative and capitalised.

- The scope is the subpackage the change is confined to (`render`, `geometry`, `core`, …, as in
  the [module table](ARCHITECTURE.md#module-layout)); leave it out when a change spans several
  packages or touches none, such as the root docs or CI.
- The types: `feat`, `fix`, `perf`, `refactor`, `docs`, `test`, `build` (pixi, the recipe,
  dependencies), `ci`, `chore`.
- A breaking change of the public API adds `!` before the colon.

```text
feat(geometry): Add Capsule
fix(render): Clip a rotated image's edge to the frame
refactor(core)!: Rename Context.window_size to Context.design_size
docs: Move the release process to RELEASING.md
```

## Documentation

The documentation site, [create-framework.github.io/create](https://create-framework.github.io/create/),
is built from this repo by `pixi run docs` and published by CI on every push to `main`, so a change
and its documentation land together. [scripts/docs.py](scripts/docs.py) stages its pages:

- **Home** is the [README](README.md), and the **user guide** is [docs/](docs/README.md). Write their
  links for GitHub, relative to the file: the site keeps links between its pages, copies images
  in, and points everything else (an example, a source file) at GitHub, at the commit built.
- The **API reference** is rendered from the docstrings by `mojo doc`, one page per subpackage. It
  lists what the subpackage's `__init__.mojo` imports, in that order, so the public surface and
  the reference can't disagree; a package's own docstring heads its page.

A new guide page or subpackage also needs an entry in `nav` in [zensical.toml](zensical.toml).

## Code conventions

### Verbs on values

A value type's verb method returns a new value and leaves the receiver as it was:
`rect = rect.translate(delta)`, `v.normalize()`, `line.split(t)`, `color.with_alpha(a)`. A
shape, vector, point, colour or matrix is never changed in place by a method; assign a field to
change one. What mutates is what has state over time — `Tween`, `Animator`, `Audio`,
`EditableText`, `Random`, a `Table`, `PixelBuffer`, `Canvas`, `Context` — whose methods act
(`tween.play()`, `table.sort(...)`).

### Locations, displacements and extents

Use `Point2D` for new locations, `Vector2D` for displacements and scalars for extents;
`canvas.rectangle(position: Point2D, w: Float64, h: Float64)` is the shape to copy. The reasons
are in [Points and vectors](docs/math.md#points-and-vectors), and three rules keep them working:

- Don't take a location as separate `x, y` scalars, not even as a convenience overload beside the
  `Point2D` one: a bare tuple already fills a `Point2D` parameter, and `(x, y)` keeps the pairs
  readable where a run of numbers doesn't.
- Don't give any type but `Point2D` an `@implicit` tuple constructor: a second one makes every
  overload pair taking the two types ambiguous for a bare tuple, and locations are the literals
  worth the shorthand.
- Don't add `Point2D.__add__(Point2D)`: the type exists to refuse it.

### Printing

A public value type implements `Writable` and prints as it would be written in source:

- Positionally for the small math types and `Color`: `Point2D(1.0, 2.0)`.
- By name for an `Int`-wrapping enum: `Easing.OUT_BOUNCE` (an unnamed value falls back to
  `Easing(99)`).
- In keyword form otherwise, labelled by the constructor's keywords where it has them
  (`Circle(position=Point2D(0.0, 0.0), r=5.0)`) and by public field names where it doesn't
  (`Time`, `Tween`). Private fields are left out.

Resource handles (`Image`, `PixelBuffer`, `Sound`, `Audio`, `Voice`) and shared assets
(`Animation`) are not printable. A `Font` prints as it is loaded, `Font.load("path")` (with
`, italic_path="..."` when it has one). `JSON` prints as compact JSON text, its own source form;
`Table` and `TableRow` are containers and not printable.

### Mojo

Create is on Mojo 1.2, and some older forms are gone or deprecated:

- Don't use `alias`; it is deprecated for `comptime`.
- Don't use `UnsafePointer`; it is deprecated for `Pointer`.
- Don't use `fn`; it is removed. Use `def`.
- Don't hold a raw `Pointer` to `Canvas` outside the guards; use origin-tracked references.

### Tests

Name a test file with the `test_` prefix, or the runner won't find it. The rest is in
[tests/README.md](tests/README.md).
