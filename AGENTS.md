# AGENTS.md — Create

## Read Always

These apply to every task and are imported below:

- [CONTRIBUTING.md](CONTRIBUTING.md): the design ethos, building and testing, the workflow and
  commit messages, and the prose style.
- [ARCHITECTURE.md](ARCHITECTURE.md): the module layout, how a frame runs, the layering rules, and
  imports and public surface.
- From the user guide, [programs](docs/guide/basics/programs.md),
  [coordinates](docs/guide/basics/coordinates.md) and [points and
  vectors](docs/guide/math/points-and-vectors.md): the shape of a program, the centred, y-up
  coordinates every other page assumes, and points and vectors, which the code conventions build on.

@CONTRIBUTING.md

@ARCHITECTURE.md

@docs/guide/basics/programs.md

@docs/guide/basics/coordinates.md

@docs/guide/math/points-and-vectors.md

## Read when relevant

Each part of the repository has a contributing guide of its own. Read the one for the part a task
touches; the `AGENTS.md` in its folder imports it, so it also loads when you work there:

| Read | When the task involves |
|---|---|
| [src/CONTRIBUTING.md](src/CONTRIBUTING.md) | the library's code: its conventions for values, points and vectors, printing and Mojo |
| [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) | the documentation site, the user guide, docstrings and the generated API reference |
| [examples/CONTRIBUTING.md](examples/CONTRIBUTING.md) | the examples or the project template |
| [tests/README.md](tests/README.md) | writing or running tests, and how the GPU is covered |

The rest of the [user guide](docs/guide/README.md) describes how the library behaves, which every
change must keep. Before changing, using or answering questions about one of these areas, read its
page:

| Read | When the task involves |
|---|---|
| [mojo](docs/guide/basics/mojo.md) | the Mojo a program needs, explained for newcomers: numbers, `mut`, structs, `Optional`, `raises`/`try`, `^`, `ref` |
| [coming from processing](docs/guide/basics/coming-from-processing.md) | how Create differs from Processing, or a Processing call's equivalent |
| [the canvas](docs/guide/drawing/canvas.md) | `canvas.draw` and the shape calls, `Drawable`, the background and autoclear, `clear`, transforms and guards, antialiasing, clipping |
| [style](docs/guide/drawing/style.md) | `Style`, the defaults, fill and stroke switches, `canvas.style(...)`, corner radius as style, tint, opacity, blend modes |
| [colours](docs/guide/drawing/colours.md) | `Color`: channels and alpha, named colours, hex, HSV, OKLCH, `lerp`, `luminance` |
| [strokes](docs/guide/drawing/strokes.md) | stroke thickness, `StrokeAlign`, `StrokeCap`, `StrokeDash` |
| [gradients](docs/guide/drawing/gradients.md) | `Gradient`, linear and radial, stops, how a gradient fits a shape |
| [shadows](docs/guide/drawing/shadows.md) | drop and inset shadows, blur, spread, offset |
| [text](docs/guide/drawing/text.md) | `canvas.text`, `Font`, `FontWeight`, italic, `Align`, lines, wrapping, measuring text |
| [pixels](docs/guide/drawing/pixels.md) | `color_at`, `snapshot`, `PixelBuffer`, `image.pixel` |
| [input](docs/guide/interaction/input.md) | what all devices share: `down`/`pressed`/`released`, focus loss, `from_name` |
| [keyboard](docs/guide/interaction/keyboard.md) | `Key`, keys by position, modifiers, key bindings |
| [typing](docs/guide/interaction/typing.md) | `keyboard.text`, `typed`, `text_input`, `text_field`, the clipboard |
| [mouse](docs/guide/interaction/mouse.md) | `Mouse`, `MouseButton`, picking under the pointer, `lock_mouse`, `Cursor` |
| [gamepads](docs/guide/interaction/gamepads.md) | `Gamepad`, `GamepadButton`, sticks, triggers, rumble |
| [widgets](docs/guide/ui/widgets.md) | the `ui` package: `UI`, `ui.screen`/`ui.world` layers, `button`, `slider`, `checkbox`, `label`, `image`, widget IDs and `ui.id`, `ui.draw`, disabled widgets |
| [focus and navigation](docs/guide/ui/focus.md) | focus, `take_focus`, Tab and keys on widgets, gamepad navigation, focus rings, `wants_keyboard`/`wants_mouse`, several `UI`s |
| [themes and styling](docs/guide/ui/themes.md) | `Theme`, `ColorScheme` roles, `Theme.from_seed`, widget styles, `ui.style`/`ui.theme` blocks, panels, `StateLayers` |
| [time](docs/guide/motion/time.md) | `context.time` and moving by `delta`, frames and the frame rate, the time scale and pause, `Clock`, `DateTime` |
| [tweens](docs/guide/motion/tweens.md) | `Tween` |
| [animations](docs/guide/motion/animations.md) | `Animation` and `Animator` |
| [shapes](docs/guide/geometry/shapes.md) | the regions (`Rectangle` … `Polygon`), `corner_radius`, the `Shape` and `Region` traits |
| [curves](docs/guide/geometry/curves.md) | `Line`, `Arc`, `Bezier`, `Spline`, the `Curve` trait, sampling along a curve |
| [collisions](docs/guide/geometry/collisions.md) | `overlaps`/`contains`/`intersects`, their accuracy, `closest_point` |
| [images](docs/guide/media/images.md) | `Image`, `canvas.image`, offscreen canvases |
| [audio](docs/guide/media/audio.md) | `Sound`, `Audio` and `Playback`: loading, synthesizing and playing sounds |
| [capture](docs/guide/media/capture.md) | `save_image`, `save_screenshot`, recording GIFs |
| [tables](docs/guide/data/tables.md) | `Table` and `TableRow` (CSV/TSV): reading, saving, finding, counting and removing rows and columns |
| [json](docs/guide/data/json.md) | `JSON`, `JSONKind`: reading, editing, building a document, missing fields |
| [angles](docs/guide/math/angles.md) | radians, `PI`/`TAU`, `sin`/`cos`/`atan2`, `degrees`/`radians` |
| [transforms](docs/guide/math/transforms.md) | `Transform`, `canvas.translate`/`rotate`/`scale`, `with canvas.transform()`, `@`, `apply`, `inverse`, and `Matrix` |
| [interpolation](docs/guide/math/interpolation.md) | `lerp`, `inverse_lerp`, `map`, `clamp`, `smoothstep`, `wrap` and the other scalar helpers |
| [easing](docs/guide/math/easing.md) | `Easing`/`ease` |
| [random numbers](docs/guide/math/random-numbers.md) | `Random` |
| [noise](docs/guide/math/noise.md) | `Noise` |

The maths pages explain each topic from the beginning, for readers who haven't met it before,
assuming only basic school maths; keep them so.

A task often spans several (a shadow on a clipped shape is style and drawing); read each it touches,
and when unsure whether one applies, read it.

The release procedure is described in [RELEASING.md](RELEASING.md).

## As an agent

- **Judge an idea on its merits.** When discussing a design or an idea, don't count breaking
  changes, doc churn, or rewriting examples and tests as costs; CONTRIBUTING.md's "Early
  development" says why. If an idea is worse for other reasons, say so.
- Leave merging to the user unless they ask for it.
- **Follow the templates when opening an issue or a pull request.** GitHub's web page offers them,
  but `gh` doesn't. Write an issue from the matching form in
  [.github/ISSUE_TEMPLATE/](.github/ISSUE_TEMPLATE/) (a bug, a feature, a performance problem or the
  documentation): each of the form's fields as a heading, and the form's label. Write a pull
  request's description from [.github/pull_request_template.md](.github/pull_request_template.md),
  with the checklist items that don't apply deleted. `gh pr create --fill` skips the template, so
  pass the body with `--body`.
- Run only the tests a change can reach (`pixi run test render`); CI runs the whole suite.
- Write Mojo with the `mojo-syntax` skill
  ([.agents/skills/mojo-syntax/](.agents/skills/mojo-syntax/SKILL.md)): Create is on Mojo 1.2, and
  much of what you know about Mojo is older.
