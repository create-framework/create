# Contributing to Create

**Create** is a creative coding library for Mojo, inspired by Processing. It combines the simplicity
and immediacy of creative coding with a structured, modular API, so it works not only for quick
sketches but also for small- to medium-sized projects such as 2D games, simulations and
visualisations.

This guide is for anyone working on Create itself: what the project values, how to make a first
change, building and testing, how changes land, and how to write. What is specific to the library's
code, the documentation or the examples has a guide of its own, listed under [Read
next](#read-next). Using Create is covered in the [user guide](docs/guide/README.md), and how its
code is organised in [ARCHITECTURE.md](ARCHITECTURE.md).

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
   the package's README if it has one, and the guide for the part you are changing (see [Read
   next](#read-next)).

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
mojo run -I src examples/hello/main.mojo       # -I src is required, see below
pixi run example hello                    # by name; no argument lists them
pixi run benchmark frame                  # benchmarks/, same form; frame cpu for the CPU backend
pixi run test                             # whole suite, concurrent
pixi run test render                      # subpackage, file name sans test_, or path; several allowed
pixi run test -j 4 canvas tween           # pin worker count (default nproc, max 8)
pixi run test --shard 2/4                 # every 4th file from the 2nd; CI runs 4 shards
pixi run precompile                       # type-check the library into build/create.mojoc
pixi run native                           # build the compiled library, build/libcreate.so
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

**So is a current `build/libcreate.so`**, which a program calls into for the loops, the window and
both replays (see [The compiled library](ARCHITECTURE.md#the-compiled-library)). After changing
anything under `src/`, run `pixi run native` before a plain `mojo run`. A program refuses a library
older than the source it was compiled from, since that library would run the code from before the
change. `example`, `benchmark` and `test` rebuild it themselves.

`example` and `benchmark` run against the precompiled library, `build/create.mojoc` (`-I build`),
not against the source, and call into the compiled library, `build/libcreate.so`, for the loops, the
window and both replays (see [The compiled library](ARCHITECTURE.md#the-compiled-library)). They
depend on the `precompile` and `native` tasks. Pixi's task cache skips `precompile` while no
`src/create/**/*.mojo` file and nothing in the environment has changed, and `native` skips the build
itself while the source and the compiler are those it was last built from (a hash of both is in
`build/libcreate.so.stamp`). So while the library is unchanged, a run starts in about 2 s rather
than 8, and the first run after a library edit pays for the rebuild, about 10 s for the package and
25 s for the compiled library.

`test`, `build-examples` and `check-standalone` work differently. Each one precompiles `src` afresh
into a temporary package of its own (and `test` and `check-standalone` build the compiled library
beside it), then builds every file against that package. So their results are never stale, and the
library is parsed once rather than once for every file.

`mojo format`'s grammar is narrower than the compiler's and will abort a commit: `where` is reserved
(not usable as a name), and `;` statement separators don't parse.

### Checks

Two tiers of automated checks, and a third run by hand:

| Where | Runs |
|---|---|
| `pre-commit` hook (after `pixi run setup`) | Wraps staged Markdown at 100 columns and restages it, then checks the formatting of staged `.mojo` files and builds `tests/app/test_smoke.mojo`. Constant cost |
| CI ([.github/workflows/ci.yml](.github/workflows/ci.yml)), every PR and push to `main` | Formatting, `mojo precompile`, every example and benchmark, a `mojo build` program run outside the environment (`pixi run check-standalone`), the conda package (`pixi run check-package`), the test suite (where a GL test that skips fails the job) and the documentation site (`pixi run docs`), which fails when the committed `docs/reference` is out of date or Markdown isn't wrapped. Linux only |
| macOS ([.github/workflows/macos.yml](.github/workflows/macos.yml)), by hand: Actions → macOS → Run workflow, on any branch | The examples, the standalone build, the test suite and the conda package on Apple silicon (`macos-examples`, `macos-tests`, `macos-package`). Not part of CI, because a macOS runner costs ten times a Linux one and nobody runs Create on a Mac yet. Run it before relying on a change that could behave differently there (windowing, GL, library search, the package), and before a release |

The smoke build and `mojo precompile` catch different mistakes, so neither replaces the other.
Building a program type-checks only the `def` bodies the program reaches: it catches an API change
that breaks a caller, but not a broken function that nothing calls. `mojo precompile` type-checks
every function in the library, but not how a program uses them, such as `run[T]` with the program's
own type.

The hook and CI skip their checks when every changed path is inert: `*.md`, `LICENSE`, the issue
forms and the agent and editor config. The list of inert paths is in `.githooks/_inert.sh`, which
the hook and the workflow both read. Two checks run for every change anyway, because Markdown alone
can break them: CI builds the documentation site, and the hook wraps staged Markdown, which CI
checks along with the site.

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

- The scope is the subpackage the change is confined to (`render`, `geometry`, `app`, …, as in the
  [module table](ARCHITECTURE.md#module-layout)); leave it out when a change spans several packages
  or touches none, such as the root docs or CI.
- The types: `feat`, `fix`, `perf`, `refactor`, `docs`, `test`, `build` (pixi, the recipe,
  dependencies), `ci`, `chore`.
- A breaking change of the public API adds `!` before the colon.

```text
feat(geometry): Add Capsule
fix(render): Clip a rotated image's edge to the frame
refactor(app)!: Rename Context.window_size to Context.design_size
docs: Move the release process to RELEASING.md
```

## Prose style

The user guide is written for someone new to creative coding as much as for someone who knows
Processing: [Colours](docs/guide/drawing/colours.md) starts from what red, green and blue are.
Everything else written for Create follows the same style: docstrings, comments, READMEs, the
contributor docs, commit messages and pull requests.

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
  colour, centre, grey, maths, behaviour, organise.
- **Punctuation:** no Oxford comma ("red, green and blue"); "such as" or "for example", not "e.g."
  or "i.e."; a colon, semicolon or parentheses rather than a dash.
- **Code font for every name from the code:** types, functions, arguments, constants, files and
  commands. Write a call as a program would, `canvas.fill(Color.RED)`, rather than describing it.
- **Headings in sentence case, without a full stop:** "Hue, saturation and value".
- **Examples build.** A complete program starts with `from create import *` and runs as it is. A
  fragment opens with a comment saying where it goes, ``# In `update`:``, and what it assumes, ``#
  In `create`, building the `random` field:``. A comment beside a line says what the line does, in
  lowercase and without a full stop: `# red, mostly transparent`. A comment on a line of its own is
  written in sentences, capitalised and ending in a full stop: `# Follow the player sideways.`
- **Links** are relative and written for GitHub (see [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md)).
  Link a page by its title, and a section by its heading.
- **A section's index page** lists each of its pages as `[Title](page.md): what it covers.`

## Read next

The rest is specific to one part of the repository. Read the guide for the part a change touches:

- [src/CONTRIBUTING.md](src/CONTRIBUTING.md): the library's code conventions: values and their
  verbs, points and vectors, printing, and the Mojo version. With it,
  [ARCHITECTURE.md](ARCHITECTURE.md) for where code belongs, and the package's own README where it
  has one.
- [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md): the documentation site, the user guide, and how the
  API reference is generated from the docstrings.
- [examples/CONTRIBUTING.md](examples/CONTRIBUTING.md): the examples and the project template.
- [tests/README.md](tests/README.md): how tests are written and run, and how the GPU is covered.
