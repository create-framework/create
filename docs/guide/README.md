# User guide

How to use Create, topic by topic. New to it? Start with the [README](../../README.md)'s "Hello,
world!" and the programs under [examples/](../../examples/), and if Mojo is new to you too, read
[Mojo](basics/mojo.md). Already know Processing? Read [Coming from
Processing](basics/coming-from-processing.md) first: it lists what works differently.

## [Basics](basics/README.md)

- [Setup](basics/setup.md): installing Create and starting a project, with `create-cli` or plain
  pixi.
- [Mojo](basics/mojo.md): the parts of the Mojo language the examples use: variables and numbers,
  `mut`, structs and traits, lists, optional values, errors, moving with `^` and `ref`.
- [Programs](basics/programs.md): how a program runs, `create` and `update`, `run`'s arguments and
  the CPU or GPU backend, which values are fields and which are parameters, how long each lasts, the
  run's settings, the window and its modes, errors and printing, file paths and scenes.
- [Coordinates](basics/coordinates.md): where things are on the screen, the three spaces (screen,
  world and local), the camera and following the player with it, and the design size.
- [Coming from Processing](basics/coming-from-processing.md): what works differently from
  Processing, and where the calls you know are.

## [Drawing](drawing/README.md)

- [The canvas](drawing/canvas.md): shapes and your own drawable types, the background, transforms,
  antialiasing and clipping.
- [Style](drawing/style.md): how the style works, its defaults, the four ways to change it, and
  tint, opacity and blend modes.
- [Colours](drawing/colours.md): red, green, blue and alpha, named colours, hex codes, hue,
  saturation and value, lightness that looks even (OKLCH), and mixing colours.
- [Strokes](drawing/strokes.md): thickness, where the stroke sits, how its ends look and dashes.
- [Gradients](drawing/gradients.md): linear and radial gradients, and how they fit a shape.
- [Shadows](drawing/shadows.md): drop shadows and inset shadows.
- [Text](drawing/text.md): fonts, italic, alignment, several lines and wrapping.
- [Pixels](drawing/pixels.md): reading back the colours of what was drawn, and building an image
  pixel by pixel.

## [Interaction](interaction/README.md)

- [Input](interaction/input.md): what the keyboard, mouse and gamepads have in common: held, pressed
  and released.
- [Keyboard](interaction/keyboard.md): keys by position, modifier keys and key bindings.
- [Typing](interaction/typing.md): typed text, and text fields with `TextField`.
- [Mouse](interaction/mouse.md): buttons, position and movement, picking what is under the pointer,
  locking the mouse and the cursor.
- [Gamepads](interaction/gamepads.md): players, sticks, triggers, buttons and rumble.

## [User interface](ui/README.md)

- [Widgets](ui/widgets.md): widgets as values, buttons, sliders, checkboxes, labels and panels,
  keeping them together in a `UI` and laying them out, drawing your own things among them, and
  disabled widgets.
- [Focus and navigation](ui/focus.md): focus, Tab and the keys, gamepads, focus rings, keeping the
  game's input apart from the UI's, and several `UI`s.
- [Themes and styling](ui/themes.md): the colours widgets are drawn in, colours from one colour, the
  sizes the `UI` keeps, styling one widget or every widget of a kind, panels, and how widgets show
  their state.

## [Motion](motion/README.md)

- [Time](motion/time.md): moving by time, frames and the frame rate, slowing and pausing time, and
  the date and time.
- [Tweens](motion/tweens.md): moving a value smoothly from one number to another over a set time.
- [Animations](motion/animations.md): sprite animation from sprite sheets and folders of images.

## [Geometry](geometry/README.md)

- [Shapes](geometry/shapes.md): the shapes, from rectangles to polygons, and corner radius.
- [Curves](geometry/curves.md): lines, arcs, Bézier curves and splines, and finding points along
  them.
- [Collisions](geometry/collisions.md): testing whether shapes touch, fast-moving objects and
  distances.

## [Media](media/README.md)

- [Images](media/images.md): loading and drawing images, and drawing into an image of your own.
- [Audio](media/audio.md): loading and synthesising sounds, playing them and controlling each
  playback.
- [Capture](media/capture.md): saving the frame as a PNG, and recording GIFs.

## [Data](data/README.md)

- [Tables](data/tables.md): reading, changing and saving CSV and TSV tables, and finding, counting
  and removing rows.
- [JSON](data/json.md): reading, changing and saving JSON files, building a document from nothing
  and missing fields.

## [Maths](math/README.md)

Each page explains its topic from the beginning, assuming only basic school maths.

- [Angles](math/angles.md): radians, which way angles go, and `sin`, `cos` and `atan2`.
- [Points and vectors](math/points-and-vectors.md): positions and movements, length and direction,
  and the dot product.
- [Transforms](math/transforms.md): moving, turning and scaling what you draw, combining transforms,
  and matrices.
- [Interpolation](math/interpolation.md): `lerp`, `map`, `clamp`, `smoothstep` and other helpers.
- [Easing](math/easing.md): easing curves, and how to read their names.
- [Random numbers](math/random-numbers.md): getting them, and seeds that repeat them.
- [Noise](math/noise.md): values that vary randomly but smoothly, and how to shape them.
