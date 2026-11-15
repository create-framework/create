# Coming from Processing

Create is inspired by Processing, and much of it will feel familiar. This page lists what works
differently, and where to find the Create version of the calls you know.

## What will surprise you

These look like Processing but behave differently, and each one catches people out:

- **The origin is the centre of the screen, and y points up.** `canvas.left()` and
  `canvas.bottom()` are negative, gravity is negative y, and `rotate` turns counter-clockwise.
  See [Coordinates](coordinates.md#the-screen).
- **Every shape is positioned by its centre**, rectangles and images included, as if
  `rectMode(CENTER)` and `imageMode(CENTER)` were always on.
- **Shapes are not filled by default.** A shape drawn with no style is just a black outline;
  call `canvas.fill(...)` to fill it. See [Style](style.md#defaults).
- **`fill` doesn't colour text.** Text has its own colour, `canvas.text_color(...)`.
- **A stroke sits inside the shape's edge** by default, not centred on it, so a stroked shape is
  exactly as big as its numbers say. `canvas.stroke_alignment(StrokeAlign.CENTER)` gives
  Processing's look. See [Strokes](style.md#strokes).
- **Style and transforms reset every frame.** There is nothing to push and pop between frames;
  within one, a `with` block scopes a change. See
  [What lasts how long](programs.md#what-lasts-how-long).
- **There are no event callbacks** such as `keyPressed()` or `mousePressed()`. `update` asks the
  devices instead, every frame. See [Input](input.md).
- **_Pressed_ means "went down this frame"**, never "is held". Processing's `mousePressed`
  variable is `context.mouse.down()`; `context.mouse.pressed()` is true only in the frame the
  button went down.
- **Fading trails need the autoclear off.** Every frame starts cleared, so a translucent
  `background()` blends over a clean frame, not over the last one. Call
  `canvas.autoclear(False)` in `create` to keep the previous frame's drawing (on the CPU
  backend, the default). See
  [The background](drawing.md#the-background).
- **Time is in seconds.** Move things by `context.time.delta`, the seconds since the last frame,
  rather than by a fixed step per frame, so they move at the same speed at any frame rate.
- **State lives in fields.** A program is a struct; what Processing keeps in global variables
  is a field of it, built in `create`. See [Programs](programs.md#parameters-and-fields).

## Where things are

### The program

| Processing | Create |
|---|---|
| `setup()` | `create(...)` |
| `draw()` | `update(...)` |
| `size(w, h)` | `run[P]("Title", width=w, height=h)`, the [design size](coordinates.md#design-size-and-autoscale) |
| `fullScreen()` | `run[P](..., mode=WindowMode.FULLSCREEN)` |
| `width`, `height` | `canvas.width()`, `canvas.height()`, or the edges `canvas.left()` … `canvas.top()` |
| `frameCount` | `context.frame_count()` |
| `frameRate(30)`, `frameRate` | `context.max_frame_rate(30)`, `context.frame_rate()` |
| `millis()` | `context.time.elapsed`, in seconds |
| `exit()` | `context.quit()` |
| `cursor(CROSS)`, `noCursor()` | `context.cursor(Cursor.CROSSHAIR)`, `context.cursor(Cursor.HIDDEN)` |

### Drawing and style

| Processing | Create |
|---|---|
| `rect(x, y, w, h)`, `ellipse(...)`, `line(...)` | `canvas.rectangle((x, y), w, h)`, `canvas.ellipse(...)`, `canvas.line(...)`, all [centred](drawing.md#shapes) |
| `background(c)` | `canvas.background(c)` |
| `fill(c)`, `noFill()` | `canvas.fill(c)`, `canvas.fill_enabled(False)` |
| `stroke(c)`, `strokeWeight(w)`, `noStroke()` | `canvas.stroke(c, w)`, `canvas.stroke_enabled(False)` |
| `color(r, g, b)`, `colorMode(HSB)` | `Color(r, g, b)`, `Color.hsv(h, s, v)` (see [Colours](style.md#colours)) |
| `lerpColor(a, b, t)` | `a.lerp(b, t)` |
| `pushMatrix()`, `translate`, `rotate`, `popMatrix()` | `with canvas.transform(translate(x, y) @ rotate(a)):` (see [Transforms](drawing.md#transforms-and-guards)) |
| `push()` / `pop()` for style | `with canvas.style(...):` |
| `textSize`, `textFont`, `textAlign` | `canvas.font_size`, `canvas.font`, `canvas.text_alignment` (see [Text and fonts](style.md#text-and-fonts)) |
| `createFont`, `loadFont` | `Font.load(path)` |
| `tint(c)` | `canvas.tint(c)`, which multiplies every colour of a call, not only images |
| `saveFrame()` | `canvas.save_image(path)` or `canvas.save_screenshot(path)` (see [Saving images](pixels.md#saving-images)) |
| `get(x, y)` | `canvas.color_at(position)` (see [Reading the screen](pixels.md#reading-the-screen)) |
| `createGraphics(w, h)` | `Canvas(w, h)` (see [Drawing into an image](pixels.md#drawing-into-an-image)) |

### Input

| Processing | Create |
|---|---|
| `mouseX`, `mouseY` | `context.mouse.position`, centred and y up |
| `pmouseX`, `pmouseY` | `context.mouse.movement`, how far it moved this frame |
| `mousePressed` (variable) | `context.mouse.down()` |
| `mousePressed()` (callback) | `if context.mouse.pressed():` in `update` |
| `keyPressed()`, `keyCode` | `if context.keyboard.pressed(Key.UP):` in `update` |
| `key` (the character typed) | `context.keyboard.text`, this frame's typed characters |

### Maths, images and data

| Processing | Create |
|---|---|
| `PVector` | `Point2D` for a position, `Vector2D` for a movement (see [Points and vectors](coordinates.md#points-and-vectors)) |
| `random(a, b)` | `random.float(a, b)`, on a `Random` field |
| `noise(x, y)` | `noise.at((x, y))`, on a `Noise` field (see [Random numbers and noise](math.md#random-numbers-and-noise)) |
| `map`, `lerp`, `constrain` | `map`, `lerp`, `clamp` |
| `loadImage(path)` | `Image.load(path)` (see [Images and animation](images.md)) |
| `image(img, x, y)` | `canvas.image(img, (x, y))`, centred |
| `loadTable`, `loadJSONObject` | `Table.load`, `JSON.load` (see [Data](data.md)) |
| `SoundFile` (Sound library) | `Sound.load` and `Audio` (see [Audio](audio.md)) |
