# User guide

How to use Create, topic by topic. New to it? Start with the [README](../../README.md)'s
"Hello, world!" and the programs under [examples/](../../examples/). Coming from Processing? Read
[Processing](basics/processing.md) first: it lists what works differently.

## [Basics](basics/README.md)

- [Setup](basics/setup.md): installing Create and starting a project, with `create-cli` or plain
  pixi.
- [Programs](basics/programs.md): how a program runs, `create` and `update`, `run`'s arguments and
  the CPU or GPU backend, what is a field and what a parameter, what lasts how long, the run's
  settings, file paths and scenes.
- [Coordinates](basics/coordinates.md): where things are on the screen, screen, world and local
  space, the camera, and the design size.
- [Processing](basics/processing.md): what works differently from Processing, and where the calls
  you know are.

## [Drawing](drawing/README.md)

- [Drawing](drawing/drawing.md): shapes and your own drawable types, the background, transforms,
  antialiasing and clipping.
- [Style](drawing/style.md): how the style works, its defaults, the three ways to change it, and
  tint, opacity and blend modes.
- [Colours](drawing/colours.md): red, green, blue and alpha, named colours, hex codes, hue,
  saturation and value, and mixing colours.
- [Strokes](drawing/strokes.md): thickness, where the stroke sits, how its ends look, and dashes.
- [Gradients](drawing/gradients.md): linear and radial gradients, and how they fit a shape.
- [Shadows](drawing/shadows.md): drop shadows and inset shadows.
- [Text](drawing/text.md): fonts, italic, alignment, several lines and wrapping.
- [Pixels](drawing/pixels.md): reading back the colours of what was drawn, and building an image
  pixel by pixel.

## [Interaction](interaction/README.md)

- [Input](interaction/input.md): what the keyboard, mouse and gamepads have in common: held,
  pressed and released.
- [Keyboard](interaction/keyboard.md): keys by position, modifier keys, and key bindings.
- [Typing](interaction/typing.md): typed text, and text fields with `EditableText`.
- [Mouse](interaction/mouse.md): buttons, position and movement, picking what is under the
  pointer, locking the mouse, and the cursor.
- [Gamepads](interaction/gamepads.md): players, sticks, triggers, buttons and rumble.

## [Motion](motion/README.md)

- [Time](motion/time.md): moving by time, frames and the frame rate, slowing and pausing time, and
  the date and time.
- [Tweens](motion/tweens.md): moving a value smoothly from one number to another over a set time.
- [Animations](motion/animations.md): sprite animation from sprite sheets and folders of images.

## [Geometry](geometry/README.md)

- [Shapes](geometry/shapes.md): the regions, from rectangles to polygons, and corner radius.
- [Curves](geometry/curves.md): lines, arcs, Bézier curves and splines, and finding points along
  them.
- [Collisions](geometry/collisions.md): testing whether shapes touch, fast-moving objects, and
  distances.

## [Media](media/README.md)

- [Images](media/images.md): loading and drawing images, and drawing into an image of your own.
- [Audio](media/audio.md): loading and synthesizing sounds, playing them, and controlling each
  playback.
- [Capture](media/capture.md): saving the frame as a PNG, and recording GIFs.

## [Data](data/README.md)

- [Tables](data/tables.md): reading, changing and saving CSV and TSV tables.
- [JSON](data/json.md): reading, changing and saving JSON files.

## [Math](math/README.md)

These pages assume no prior knowledge of the mathematics they describe.

- [Angles](math/angles.md): radians, which way angles go, and `sin`, `cos` and `atan2`.
- [Vectors](math/vectors.md): points and vectors, length and direction, and the dot product.
- [Matrices](math/matrices.md): moving, turning and scaling with matrices, and combining them.
- [Interpolation](math/interpolation.md): `lerp`, `map`, `clamp`, `smoothstep` and other helpers.
- [Easing](math/easing.md): easing curves, and how to read their names.
- [Random](math/random.md): random numbers and seeds.
- [Noise](math/noise.md): values that vary randomly but smoothly, and how to shape them.
