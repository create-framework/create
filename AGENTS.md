# AGENTS.md — Create

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md): what Create is, its design ethos, how to build and test
it, the workflow and commit messages, and the code conventions.

@CONTRIBUTING.md

On top of it, as an agent:

- **Judge an idea on its merits.** When discussing a design or an idea, don't count breaking
  changes, doc churn, or rewriting examples and tests as costs; CONTRIBUTING.md's "Early
  development" says why. If an idea is worse for other reasons, say so.
- Leave merging to the user unless they ask for it.
- Run only the tests a change can reach (`pixi run test render`); CI runs the whole suite.

## Architecture

Read [ARCHITECTURE.md](ARCHITECTURE.md): the module layout, imports and public surface, and the
layering rules.

@ARCHITECTURE.md

## Releasing

When asked to cut a release, follow [RELEASING.md](RELEASING.md).

## User guide

Read the user guide in [docs/](docs/README.md): [programs](docs/programs.md),
[coordinates](docs/coordinates.md), [drawing](docs/drawing.md), [pixels](docs/pixels.md) and the
[glossary](docs/glossary.md).

@docs/programs.md

@docs/coordinates.md

@docs/drawing.md

@docs/pixels.md

@docs/glossary.md
