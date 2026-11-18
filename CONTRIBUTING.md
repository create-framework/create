# Contributing to Create

**Create** is a creative coding library for Mojo, inspired by Processing. It combines the simplicity
and immediacy of creative coding with a structured, modular API, so it works not only for quick
sketches but also for small- to medium-sized projects such as 2D games, simulations and
visualisations.

This guide is for anyone working on Create itself: what the project values, how to make a first
change, and then the reference for building, testing, landing changes and the code's conventions.
Using Create is covered in the [user guide](docs/guide/README.md), and how its code is organised in
[ARCHITECTURE.md](ARCHITECTURE.md).

## What we value

### Early development

Create is in early development and makes no promise of API stability yet. At this stage breaking
changes are fine. Doc churn and rewriting examples or tests are not reasons to reject an idea; judge
a change on whether it makes the library better.

### Design ethos

The API should embody the following principles:

- **Intuitive:** The API should have a quality of obviousness. Names and behaviours should be easy
  to understand. Avoid abbreviations; prefer clarity over brevity.
- **Ergonomic:** Optimise for the experience of using the library, not for minimising its API
  surface. Common operations should be concise and require minimal ceremony.
- **Modular:** Keep the architecture modular, with clear separation of concerns and minimal
  coupling. Components should be independently understandable and should compose naturally.
- **Consistent:** Similar concepts should be named and behave alike. Establish conventions and apply
  them uniformly rather than introducing special cases without good reason.
- **Composable:** Design APIs and abstractions that work well together. Prefer building blocks that
  can be combined in different ways over rigid, narrowly scoped solutions.
- **Performant:** Performance should be an inherent property of the API, not something users must
  work around. Common operations should be efficient by default, without requiring knowledge of
  internals or specialised APIs to achieve good performance.

## Your first change

Everything Create needs, Mojo included, comes from [pixi](https://pixi.sh); `pixi run` sets up the
environment the first time it is used.

1. **Clone and set up**, once per clone. `pixi run setup` installs the git hooks (see
   [Checks](#checks)). It also tells `git blame` to skip the commits listed in
   `.git-blame-ignore-revs`, which are bulk reformats and renames:

   ```bash
   git clone https://github.com/create-framework/create.git
   cd create
   pixi run setup
   ```

2. **Run something.** `pixi run example` lists the examples; `pixi run example hello` runs one.

3. **Make the change on a branch**, from an up-to-date `main`: `git switch -c some-change`. Read
   [ARCHITECTURE.md](ARCHITECTURE.md) first for where it belongs and what the package may import,
   and the package's README if it has one.

4. **Test what the change can reach**: `pixi run test render` runs one subpackage's tests (see
   [Building and testing](#building-and-testing)), and `pixi run build-examples` type-checks every
   example, which catches a change of the public API. New behaviour gets a test; how tests are
   written is in [tests/README.md](tests/README.md).

5. **Commit** with a [Conventional Commits](#commit-messages) message. The pre-commit hook wraps
   staged Markdown, checks the formatting of staged Mojo (`pixi run format` fixes it) and builds a
   smoke test.

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
pixi run build-examples                   # type-check every example, benchmark and the template; a warning fails it
pixi run check-standalone                 # a `mojo build` program, run outside the environment
pixi run check-package                    # the conda package from recipe/, built and tested as installed
pixi run format                           # Mojo at 80 columns, Markdown prose wrapped at 100
pixi run embed-fonts                      # regenerate text/_noto.mojo after changing a face in text/fonts/
pixi run reference                        # regenerate docs/reference from the docstrings; commit the result
pixi run docs                             # the same, then build the documentation site into build/docs/site
pixi run docs-serve                       # preview it, rebuilt as you edit (rerun after a docstring change)
pixi run docs-site                        # the published site, main and the latest release, into build/docs/published
pixi run setup                            # once per clone: git hooks + blame ignore-revs
```

**`-I src` is required for every `mojo run`**, or `from create import *` fails. Pixi tasks add it.

`example` and `benchmark` run against the precompiled library, `build/create.mojoc` (`-I build`),
not against the source. They depend on the `precompile` task, and pixi's task cache skips that task
while no `src/create/**/*.mojo` file and nothing in the environment has changed. So while the
library is unchanged, a run starts in about 2 s rather than 8, and the first run after a library
edit pays for the ~10 s rebuild.

`test`, `build-examples` and `check-standalone` work differently. Each one precompiles `src` afresh
into a temporary package of its own, then builds every file against that package. So their results
are never stale, and the library is parsed once rather than once for every file.

**The project template.** [template/](template/) is where a new project starts:
[create-cli](https://github.com/create-framework/create-cli)'s `create new` copies it, a `main.mojo`
and the `assets/` it loads. The Create package installs the template to `share/create/template`, so
a new project always starts from the template that matches the installed Create. `create new`
replaces `{{name}}` in `main.mojo` with the project's name. The placeholder sits inside a string, so
the file builds as it is. `build-examples` builds the template along with the examples, so a change
to the API that breaks the template fails CI here, and is fixed in the same pull request.

`mojo format`'s grammar is narrower than the compiler's and will abort a commit: `where` is reserved
(not usable as a name), and `;` statement separators don't parse.

### Checks

Two tiers of automated checks, and a third run by hand:

| Where | Runs |
|---|---|
| `pre-commit` hook (after `pixi run setup`) | Wraps staged Markdown at 100 columns and restages it, then checks the formatting of staged `.mojo` files and builds `tests/core/test_smoke.mojo`. Constant cost |
| CI ([.github/workflows/ci.yml](.github/workflows/ci.yml)), every PR and push to `main` | Formatting, `mojo precompile`, every example and benchmark, a `mojo build` program run outside the environment (`pixi run check-standalone`), the conda package (`pixi run check-package`), the test suite (where a GL test that skips fails the job) and the documentation site (`pixi run docs`), which fails when the committed `docs/reference` is out of date or Markdown isn't wrapped. Linux only |
| macOS ([.github/workflows/macos.yml](.github/workflows/macos.yml)), by hand: Actions → macOS → Run workflow, on any branch | The examples, the standalone build and the test suite on Apple silicon (`macos-examples`, `macos-tests`). Not part of CI, because a macOS runner costs ten times a Linux one and nobody runs Create on a Mac yet. Run it before relying on a change that could behave differently there (windowing, GL, library search) |

The smoke build and `mojo precompile` catch different mistakes, so neither replaces the other.
Building a program type-checks only the `def` bodies the program reaches: it catches an API change
that breaks a caller, but not a broken function that nothing calls. `mojo precompile` type-checks
every function in the library, but not how a program uses them, such as `run[T]` with the program's
own type.

The hook and CI skip their checks when every changed path is inert: `*.md`, `LICENSE`, and agent and
editor config. The list of inert paths is in `.githooks/_inert.sh`, which the hook and the workflow
both read. Two checks run for every change anyway, because Markdown alone can break them: CI builds
the documentation site, and the hook wraps staged Markdown, which CI checks along with the site.

## Workflow

`main` is protected by a ruleset: no direct pushes, no force pushes, no deletion, and a linear
history. Every change lands as a pull request, merged once the required check `ci` passes. No
approval is required. `ci` passes when `linux-docs` has passed and each of the other checks has
either passed or been skipped because the change is inert. The other checks are `linux-format`,
`linux-precompile`, `linux-examples`, `linux-package` and the four test shards
`linux-tests-1`…`linux-tests-4`. **Rebase and merge** is the only merge method enabled: squash and
merge commits are off.

```bash
git switch -c some-change                 # from an up-to-date main
git push -u origin some-change            # pushes run no hook; CI runs on the PR
gh pr create --fill
gh pr merge --auto --rebase               # merges itself once CI is green
git switch main && git pull --ff-only
```

Each of the branch's commits lands on `main` as it is, rebased onto it with a new hash. Every commit
should therefore build and carry a finished message: tidy the branch before merging, since there is
no squash to tidy it for you. The branch doesn't need to be up to date with `main` to merge, and it
is deleted once merged. A repository admin may bypass the checks to merge a pull request when CI
itself is broken, but never to push to `main` directly.

Releases are cut by a maintainer, as [RELEASING.md](RELEASING.md) describes.

### Commit messages

Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/):
`<type>(<package>): <Summary>`, the summary in the imperative and capitalised.

- The scope is the subpackage the change is confined to (`render`, `geometry`, `core`, …, as in the
  [module table](ARCHITECTURE.md#module-layout)); leave it out when a change spans several packages
  or touches none, such as the root docs or CI.
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

The documentation site, [create-framework.org](https://create-framework.org/), is built from this
repo by `pixi run docs`, so a change and its documentation land together.
[scripts/docs.py](scripts/docs.py) stages its pages:

- **Home** is the [README](README.md), and the **user guide** is
  [docs/guide/](docs/guide/README.md). Write their links for GitHub, relative to the file: the site
  keeps links between its pages, copies images in, and points everything else (an example, a source
  file) at GitHub, at the commit built.
- The **API reference** is [docs/reference/](docs/reference/README.md), generated from the
  docstrings by `mojo doc`. It is committed, so it reads on GitHub as well as on the site. Never
  edit it by hand: after changing a docstring or the public surface, run `pixi run reference` and
  commit what changed. CI's `linux-docs` regenerates it and fails when the committed copy differs.

How the reference is laid out decides how a docstring should be written:

- **Each subpackage has a page**, headed by the package's own docstring. It lists what the package's
  `__init__.mojo` imports, grouped into types, traits, functions and constants, in import order
  within each group. So the public surface and the reference can't disagree.
- **Each type, trait and function has a page of its own.** The package's page lists it by the first
  line of its docstring, so write that line to make sense on its own. A constant has no page of its
  own; it is documented on the package's page.
- **A type's page groups its members** into constants, fields, constructors, methods and special
  methods (the dunders). A static method is listed as a constructor only when its signature ends in
  `-> Self`, so declare a factory's return type as `Self`, not by the type's name.
- **A function's overloads share one page.** Consecutive overloads with the same documentation are
  shown as one block of signatures.

Write Markdown without minding line length: the pre-commit hook wraps prose at 100 columns
([scripts/wrap_markdown.py](scripts/wrap_markdown.py)), never splitting a word, and leaves code,
tables, HTML and headings as written. `pixi run format` wraps every page by hand.

A new guide page needs an entry in `nav` in [zensical.toml](zensical.toml). The reference's nav is
generated: `docs.py` writes the config the site is built from to `build/docs/zensical.toml`, with a
page for every subpackage, type and function added.

The site is published in two versions, picked by a selector in its header: `/latest/`, the newest
release and what the root redirects to, and `/main/`, under a banner saying it is unreleased.
[scripts/docs_site.py](scripts/docs_site.py) (`pixi run docs-site`) builds both. It builds the
release from a worktree of the release's tag, with that tag's own environment and scripts, and then
adds the version selector. [.github/workflows/docs.yml](.github/workflows/docs.yml) publishes them
on every push to `main` and after every release. A docs fix after a release reaches `/latest/` with
the next release.

### Prose style

The user guide is written for someone new to creative coding as much as for someone who knows
Processing: [Colours](docs/guide/drawing/colours.md) starts from what red, green and blue are.
Docstrings and the contributor docs follow the same style.

- **Say what it does, plainly.** Present tense, active voice, and the reader as "you", never "we".
  Prefer the plain word, and leave out "simply", "easily" and "obviously": what is easy for the
  writer may not be for the reader.
- **Clear over short.** Give a sentence one idea, and spell out a step rather than leave the reader
  to infer it. A longer sentence that reads at once beats a shorter one that has to be read twice.
- **Claim only what is true now.** Describe how the library behaves, not how it used to ("no
  longer", "now"), and check a claim about speed or behaviour before making it.
- **Lead with the point.** A page opens with a paragraph saying what it covers. A paragraph or list
  item that makes one point can open with it in bold: "**Shapes are not filled by default.** A shape
  drawn with no style is…".
- **British spelling in prose, the API's in code:** "Every colour in Create is a `Color`." So
  colour, centre, behaviour, organise.
- **Punctuation:** no Oxford comma ("red, green and blue"); "such as" or "for example", not "e.g."
  or "i.e."; a colon, semicolon or parentheses rather than a dash.
- **Code font for every name from the code:** types, functions, arguments, constants, files and
  commands. Write a call as a program would, `canvas.fill(Color.RED)`, rather than describing it.
- **Headings in sentence case, without a full stop:** "Hue, saturation and value".
- **Examples build.** A complete program starts with `from create import *` and runs as it is. A
  fragment opens with a comment saying where it goes, ``# In `update`:``, and what it assumes, ``#
  In `create`, building the `random` field:``. A comment beside a line says what the line does, in
  lowercase and without a full stop: `# red, mostly transparent`.
- **Links** are relative and written for GitHub (see above). Link a page by its title, and a section
  by its heading.
- **A section's index page** lists each of its pages as `[Title](page.md): what it covers.`

## Code conventions

### Verbs on values

A value type's verb method returns a new value and leaves the receiver as it was: `rect =
rect.translate(delta)`, `v.normalize()`, `line.split(t)`, `color.with_alpha(a)`. A shape, vector,
point, colour or matrix is never changed in place by a method; assign a field to change one. The
types that change in place are those that hold state over time, and their methods act on that state
(`tween.play()`, `table.sort(...)`): `Tween`, `Animator`, `Audio`, `EditableText`, `Random`,
`Table`, `PixelBuffer`, `Canvas` and `Context`.

### Locations, displacements and extents

Use `Point2D` for new locations, `Vector2D` for displacements and scalars for extents;
`canvas.rectangle(position: Point2D, width: Float64, height: Float64)` is the shape to copy. The
reasons are in [Points and
vectors](docs/guide/math/points-and-vectors.md#locations-displacements-and-extents), and three rules
keep them working:

- Don't take a location as separate `x, y` scalars, not even as a convenience overload beside the
  `Point2D` one: a bare tuple already fills a `Point2D` parameter, and `(x, y)` keeps the pairs
  readable where a run of numbers doesn't.
- Don't give any type but `Point2D` an `@implicit` tuple constructor. If two types could both be
  built from a bare tuple, any function overloaded on those two types would be ambiguous when called
  with a tuple. Locations are the values most worth writing as a tuple, so only `Point2D` gets the
  shorthand.
- Don't add `Point2D.__add__(Point2D)`. Adding two locations has no meaning, and refusing it is why
  `Point2D` is a separate type from `Vector2D`.

### Printing

A public value type implements `Writable` and prints as it would be written in source:

- Positionally for the small math types and `Color`: `Point2D(1.0, 2.0)`.
- By name for an `Int`-wrapping enum: `Easing.OUT_BOUNCE` (an unnamed value falls back to
  `Easing(99)`).
- In keyword form otherwise, labelled by the constructor's keywords where it has them
  (`Circle(position=Point2D(0.0, 0.0), radius=5.0)`) and by public field names where it doesn't
  (`Time`, `Tween`). Private fields are left out.

Resource handles (`Image`, `PixelBuffer`, `Sound`, `Audio`, `Playback`) and shared assets
(`Animation`) are not printable. A `Font` prints as it is loaded, `Font.load("path")` (with `,
italic_path="..."` when it has one). `JSON` prints as compact JSON text, its own source form;
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
