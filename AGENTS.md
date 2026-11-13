# AGENTS.md — Create

Create's docs are written for every contributor, human or agent. Read them before working here;
this file adds only what is specific to agents.

## Read first

- [docs/](docs/README.md), the user guide: [programs](docs/programs.md),
  [coordinates](docs/coordinates.md), [drawing](docs/drawing.md), [style](docs/style.md),
  [pixels](docs/pixels.md), [input](docs/input.md), [geometry](docs/geometry.md),
  [math](docs/math.md) and [data](docs/data.md). How the library behaves, which every change must
  keep.
- [CONTRIBUTING.md](CONTRIBUTING.md): the design ethos, building and testing, the workflow and
  commit messages, and the code conventions.
- [ARCHITECTURE.md](ARCHITECTURE.md): the module layout, imports and public surface, and the
  layering rules.
- A package's README before changing it: [render](src/create/render/README.md),
  [core](src/create/core/README.md), [tests](tests/README.md). The `AGENTS.md` beside each
  imports it.
- [RELEASING.md](RELEASING.md), only when asked to cut a release.

@docs/programs.md

@docs/coordinates.md

@docs/drawing.md

@docs/style.md

@docs/pixels.md

@docs/input.md

@docs/geometry.md

@docs/math.md

@docs/data.md

@CONTRIBUTING.md

@ARCHITECTURE.md

## As an agent

- **Judge an idea on its merits.** When discussing a design or an idea, don't count breaking
  changes, doc churn, or rewriting examples and tests as costs; CONTRIBUTING.md's "Early
  development" says why. If an idea is worse for other reasons, say so.
- Leave merging to the user unless they ask for it.
- Run only the tests a change can reach (`pixi run test render`); CI runs the whole suite.
- Write Mojo with the `mojo-syntax` skill ([.agents/skills/mojo-syntax/](.agents/skills/mojo-syntax/SKILL.md)):
  Create is on Mojo 1.2, and much of what you know about Mojo is older.
