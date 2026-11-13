# AGENTS.md — Create

Create's docs are written for every contributor, human or agent. Read them before working here;
this file adds only what is specific to agents.

## Always

These apply to every task and are imported below:

- [CONTRIBUTING.md](CONTRIBUTING.md): the design ethos, building and testing, the workflow and
  commit messages, and the code conventions.
- [ARCHITECTURE.md](ARCHITECTURE.md): the module layout, how a frame runs, the layering rules,
  and imports and public surface.
- From the user guide, [programs](docs/programs.md) and [coordinates](docs/coordinates.md): the
  shape of a program and the centred, y-up coordinates every other page assumes.

@CONTRIBUTING.md

@ARCHITECTURE.md

@docs/programs.md

@docs/coordinates.md

## When the task touches it

The rest of the [user guide](docs/README.md) describes how the library behaves, which every change
must keep. Before changing, using or answering questions about one of these areas, read its page:

| Read | When the task involves |
|---|---|
| [drawing](docs/drawing.md) | `canvas.draw` and the shape calls, `Drawable`, the background and autoclear, transforms and guards, antialiasing, clipping |
| [style](docs/style.md) | `Style`, fills and strokes, gradients, shadows, tint, opacity, blend modes, fonts and text |
| [pixels](docs/pixels.md) | `color_at`, `snapshot`, offscreen canvases, `Image` and `PixelBuffer`, saving images, recording GIFs |
| [input](docs/input.md) | the keyboard, mouse or gamepads, text entry, `EditableText` |
| [geometry](docs/geometry.md) | the shapes and curves themselves, `corner_radius`, `overlaps`/`contains`/`intersects` |
| [math](docs/math.md) | `Point2D`/`Vector2D`, `Random`, `Noise`, `Easing`/`Tween`, `Time`/`DateTime` |
| [data](docs/data.md) | `Table` (CSV/TSV) or `JSON` |

A task often spans several (a shadow on a clipped shape is style and drawing); read each it
touches, and when unsure whether one applies, read it.

Also:

- A package's README before changing that package: [render](src/create/render/README.md),
  [core](src/create/core/README.md), [tests](tests/README.md). The `AGENTS.md` beside each imports
  it, so it loads when you work there.
- [RELEASING.md](RELEASING.md), only when asked to cut a release.

## As an agent

- **Judge an idea on its merits.** When discussing a design or an idea, don't count breaking
  changes, doc churn, or rewriting examples and tests as costs; CONTRIBUTING.md's "Early
  development" says why. If an idea is worse for other reasons, say so.
- Leave merging to the user unless they ask for it.
- Run only the tests a change can reach (`pixi run test render`); CI runs the whole suite.
- Write Mojo with the `mojo-syntax` skill ([.agents/skills/mojo-syntax/](.agents/skills/mojo-syntax/SKILL.md)):
  Create is on Mojo 1.2, and much of what you know about Mojo is older.
