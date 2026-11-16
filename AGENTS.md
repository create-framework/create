# AGENTS.md — Create

## Read Always

These apply to every task and are imported below:

- [CONTRIBUTING.md](CONTRIBUTING.md): the design ethos, building and testing, the workflow and
  commit messages, and the code conventions.
- [ARCHITECTURE.md](ARCHITECTURE.md): the module layout, how a frame runs, the layering rules,
  and imports and public surface.
- From the user guide, [programs](docs/guide/programs.md) and [coordinates](docs/guide/coordinates.md): the
  shape of a program and the centred, y-up coordinates every other page assumes.

@CONTRIBUTING.md

@ARCHITECTURE.md

@docs/guide/programs.md

@docs/guide/coordinates.md

## Read when relevant

The rest of the [user guide](docs/guide/README.md) describes how the library behaves, which every change
must keep. Before changing, using or answering questions about one of these areas, read its page:

| Read | When the task involves |
|---|---|
| [processing](docs/guide/processing.md) | how Create differs from Processing, or a Processing call's equivalent |
| [drawing](docs/guide/drawing.md) | `canvas.draw` and the shape calls, `Drawable`, the background and autoclear, transforms and guards, antialiasing, clipping |
| [style](docs/guide/style.md) | `Color`, `Style`, fills and strokes, gradients, shadows, tint, opacity, blend modes, fonts and text |
| [input](docs/guide/input.md) | the keyboard, mouse or gamepads, the cursor, text entry, `EditableText` |
| [images](docs/guide/images.md) | `Image`, `canvas.image`, `PixelBuffer` |
| [animation](docs/guide/animation.md) | `Easing`/`ease`, `Tween`, `Animation` and `Animator` |
| [pixels](docs/guide/pixels.md) | `color_at`, `snapshot`, offscreen canvases, saving images, recording GIFs |
| [geometry](docs/guide/geometry.md) | the shapes and curves themselves, `corner_radius`, `overlaps`/`contains`/`intersects` |
| [math](docs/guide/math.md) | `Random`, `Noise` |
| [time](docs/guide/time.md) | `context.time` and moving by `delta`, frames and the frame rate, the time scale and pause, `Clock`, `DateTime` |
| [audio](docs/guide/audio.md) | `Sound`, `Audio` and `Playback`: loading, synthesizing and playing sounds |
| [data](docs/guide/data.md) | `Table` (CSV/TSV) or `JSON` |

A task often spans several (a shadow on a clipped shape is style and drawing); read each it
touches, and when unsure whether one applies, read it.

The release procedure is described in [RELEASING.md](RELEASING.md).

## As an agent

- **Judge an idea on its merits.** When discussing a design or an idea, don't count breaking
  changes, doc churn, or rewriting examples and tests as costs; CONTRIBUTING.md's "Early
  development" says why. If an idea is worse for other reasons, say so.
- Leave merging to the user unless they ask for it.
- Run only the tests a change can reach (`pixi run test render`); CI runs the whole suite.
- Write Mojo with the `mojo-syntax` skill ([.agents/skills/mojo-syntax/](.agents/skills/mojo-syntax/SKILL.md)):
  Create is on Mojo 1.2, and much of what you know about Mojo is older.
