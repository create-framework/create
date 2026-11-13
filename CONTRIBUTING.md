# Contributing to Create

**Create** is a creative coding library for Mojo, inspired by Processing. It combines the simplicity and immediacy of creative coding with a structured, modular API, so it works not only for quick sketches but also for small- to medium-sized projects such as 2D games, simulations and visualisations.

This guide is for anyone working on Create itself: what it values, how to build and test it, how
changes land, and the conventions its code follows. Using Create is covered in the [README](README.md),
how its code is organised in [ARCHITECTURE.md](ARCHITECTURE.md).

## Early development

Create is in early development and makes no promise of API stability yet.
At this stage breaking changes are fine. Doc churn and rewriting examples or tests are not reasons to reject an idea; judge a change on whether it makes the library better.

## Design ethos

The API should embody the following principles:

- **Intuitive:** The API should have a quality of obviousness. Names and behaviours should be easy to understand. Avoid abbreviations; prefer clarity over brevity.

- **Ergonomic:** Optimise for the experience of using the library, not for minimising its API surface. Common operations should be concise and require minimal ceremony.

- **Modular:** Keep the architecture modular, with clear separation of concerns and minimal coupling. Components should be independently understandable and should compose naturally.

- **Consistent:** Similar concepts should be named and behave alike. Establish conventions and apply them uniformly rather than introducing special cases without good reason.

- **Composable:** Design APIs and abstractions that work well together. Prefer building blocks that can be combined in different ways over rigid, narrowly scoped solutions.

- **Performant:** Performance should be an inherent property of the API, not something users must work around. Common operations should be efficient by default, without requiring knowledge of internals or specialised APIs to achieve good performance.

## Build and test

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
pixi run setup                            # once per clone: git hooks + blame ignore-revs
```

**`-I src` is required for every `mojo run`**, or `from create import *` fails. Pixi tasks add it.

`example` and `benchmark` run against `build/create.mojoc` (`-I build`), not the source: they
depend on `precompile`, which pixi's task cache skips while no `src/create/**/*.mojo` file and
nothing in the environment has changed. So a run with the library unchanged starts in about 2 s
rather than 8; the first one after a library edit pays the ~10 s rebuild. `test`,
`build-examples` and `check-standalone` precompile `src` afresh into a temporary package of their
own and build every file against it, so none is ever stale or re-parses the library per file.

Two tiers of automated checks, and a third run by hand:

| Where | Runs |
|---|---|
| `pre-commit` hook (after `pixi run setup`) | Formatting check on staged `.mojo` files, then builds `tests/core/test_smoke.mojo`. Constant cost |
| CI ([.github/workflows/ci.yml](.github/workflows/ci.yml)), every PR and push to `main` | Formatting, `mojo precompile`, every example and benchmark, a `mojo build` program run outside the environment (`pixi run check-standalone`), the conda package (`pixi run check-package`), the test suite — a GL test that skips fails the job. Linux only |
| macOS ([.github/workflows/macos.yml](.github/workflows/macos.yml)), by hand: Actions → macOS → Run workflow, on any branch | The examples, the standalone build and the test suite on Apple silicon (`macos-examples`, `macos-tests`). Not part of CI — a macOS runner costs ten times a Linux one and nobody runs Create on a Mac yet — so run it before relying on a change that could differ there (windowing, GL, library search) |

The hook and CI skip their checks when every changed path is inert (`*.md`, `LICENSE`, agent/editor config) —
the allowlist is in `.githooks/_inert.sh`, read by the hook and the workflow alike.

Neither tier subsumes the other: building a consumer program type-checks only the `def` bodies it
reaches (catches API drift, not an uncalled broken function); `mojo precompile` is the reverse.

`mojo format`'s grammar is narrower than the compiler's and will abort a commit: `where` is
reserved (not usable as a name), and `;` statement separators don't parse.

How tests are written and what they cover: [tests/README.md](tests/README.md).

## Workflow

`main` is protected by a ruleset: no direct pushes, no force pushes, no deletion,
and a linear history. Every change lands as a pull request, merged once the required check `ci`
passes — it passes when `linux-format`, `linux-precompile`, `linux-examples`, `linux-package` and the four test
shards `linux-tests-1`…`linux-tests-4` all passed, or were skipped for an inert change; no approval
is required. **Rebase and merge** is the only merge method enabled: squash and merge commits are
off.

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
merge. A repository admin may bypass the checks when merging a pull request (CI itself broken), never
for a direct push.

**Commit messages** follow [Conventional Commits](https://www.conventionalcommits.org/):
`<type>(<package>): <Summary>`, the summary in the imperative and capitalised. The scope is the
subpackage the change is confined to (`render`, `geometry`, `core`, …, as in the module table);
leave it out when a change spans several packages or touches none, such as the root docs or CI.
The types: `feat`, `fix`, `perf`, `refactor`, `docs`, `test`, `build` (pixi, the recipe,
dependencies), `ci`, `chore`. A breaking change of the public API adds `!` before the colon.

```text
feat(geometry): Add Capsule
fix(render): Clip a rotated image's edge to the frame
refactor(core)!: Rename Context.window_size to Context.design_size
docs: Move the release process to RELEASING.md
```

## Code conventions

### Printing

A public value type implements `Writable` and prints as it would be written in source:
`Point2D(1.0, 2.0)` positionally for the small math types and `Color`; `Easing.OUT_BOUNCE` for an
`Int`-wrapping enum (an unnamed value falls back to `Easing(99)`); keyword form otherwise, labelled
by the constructor's keywords where it has them (`Circle(position=Point2D(0.0, 0.0), r=5.0)`) and by
public field names where it doesn't (`Time`, `Tween`). Private fields are left out. Resource handles
(`Image`, `PixelBuffer`, `Sound`, `Audio`, `Voice`) and shared assets (`Animation`) are not printable; a `Font`
prints as it is loaded, `Font.load("path")` (with `, italic_path="..."` when it has one). `JSON`
prints as compact JSON text, its own source form; `Table` and `TableRow` are containers and not
printable.

### Verbs on values

A value type's verb method returns a new value and leaves the receiver as it was:
`rect = rect.translate(delta)`, `v.normalize()`, `line.split(t)`, `color.with_alpha(a)`. A
shape, vector, point, colour or matrix is never changed in place by a method; assign a field to
change one. What mutates is what has state over time — `Tween`, `Animator`, `Audio`,
`EditableText`, `Random`, a `Table`, `PixelBuffer`, `Canvas`, `Context` — whose methods act
(`tween.play()`, `table.sort(...)`).

### Do

- Use `Point2D` for new locations, `Vector2D` for displacements and scalars for extents;
  `canvas.rectangle(position: Point2D, w: Float64, h: Float64)` is the shape to copy.

### Don't

- Don't use `alias` — deprecated for `comptime`.
- Don't use `UnsafePointer` — deprecated for `Pointer`.
- Don't use `fn` — removed; use `def`.
- Don't hold a raw `Pointer` to `Canvas` outside the guards; use origin-tracked references.
- Don't name a test file without the `test_` prefix; the runner won't find it.
- Don't take a location as separate `x, y` scalars, not even as a convenience overload beside the
  `Point2D` one: a bare tuple already fills a `Point2D` parameter, and `(x, y)` keeps the pairs
  readable where a run of numbers doesn't.
- Don't give any type but `Point2D` an `@implicit` tuple constructor: a second one makes every
  overload pair taking the two types ambiguous for a bare tuple, and locations are the literals worth
  the shorthand. Don't add `Point2D.__add__(Point2D)` either — the type exists to refuse it.
