# Images and animation

Loading and drawing images, animating sprites, and building an image pixel by pixel. Drawing
shapes and text into an image of your own is in [Pixels](pixels.md#drawing-into-an-image).

## Drawing an image

An `Image` is loaded once, in `create`, kept as a field and drawn with `canvas.image`:

```mojo
from create import *


@fieldwise_init
struct Sprites(Program):
    var player: Image

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> Sprites:
        return Sprites(Image.load("assets/player.png"))

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        canvas.background(Color.WHITE)
        canvas.image(self.player, (-200, 0))  # at its own size
        canvas.image(self.player, (0, 0), 128, 128)  # stretched to 128 by 128
        with canvas.style(tint=Color.RED, opacity=0.5):
            canvas.image(self.player, (200, 0))  # reddened, half transparent


def main() raises:
    run[Sprites]("Sprites")
```

- **`Image.load(path)`** reads a PNG, JPEG or BMP file. A relative path is relative to the source
  file that makes the call (see [File paths](programs.md#file-paths)).
- **`canvas.image(image, position)`** draws the image centred on `position`, like every shape,
  one unit per image pixel. `canvas.image(image, position, width, height)` stretches it to that
  size. Either way it is the right way up, although y points up.
- **It is a render call like any other:** the transform turns, scales and mirrors it, the camera
  places it, and the style's `tint`, `opacity`, `blend_mode` and shadow apply (an image casts the
  shadow of its opaque pixels). Fill and stroke don't apply. See [Style](style.md).
- `image.width()` and `image.height()` are its size in pixels, `Image.solid(width, height, color)`
  is an image of one colour, and `image.resize(width, height)` returns a resized copy, nearest
  pixel.
- An `Image` is an asset: copying one is cheap, since copies share their pixels, and drawing one
  costs no copy either (see [Assets and playheads](programs.md#assets-and-playheads)). An image
  not drawn for 120 frames is dropped from the renderer's cache, so drawing a fresh image every
  frame, such as a snapshot, uses bounded memory.

See [examples/image](../examples/image/main.mojo).

## Sprite animation

An **`Animation`** is a sequence of frames and the rate they play at. An **`Animator`** is one
entity's place in an animation, and `canvas.image` draws its current frame:

```mojo
# In `create`, building the `idle`, `run` and `animator` fields:
var sheet = Image.load("assets/character.png")
var idle = Animation.from_sheet(sheet, 32, 32, start=0, count=4, fps=6.0)
var run = Animation.from_sheet(sheet, 32, 32, start=4, count=4, fps=12.0)
var animator = Animator(idle)

# In `update`, with `velocity` and `position` fields:
if self.velocity.x != 0:
    self.animator.use(self.run)
else:
    self.animator.use(self.idle)
canvas.image(self.animator, self.position, 128, 128)
```

**Making an animation.** Each takes an `fps=`, 12 frames a second by default; the rate belongs to
the artwork, so it lives on the animation.

- `Animation.from_sheet(sheet, frame_width, frame_height, start=, count=)` cuts frames out of a
  sprite sheet. Its cells are numbered from 0, left to right and then top to bottom, so one sheet
  can hold several animations, as above.
- `Animation.from_folder(path)` loads every image in a folder, in the order of the number each
  name ends in, so `walk_2.png` comes before `walk_10.png`.
- `Animation(frames)` takes a `List[Image]` already in memory.

**Playing it.** An animator starts stopped on frame 0. It is driven in two ways:

- **`use(animation)`, every frame, for what should be showing now.** If that animation is already
  the one playing, paused or finished, `use` changes nothing, so a loop keeps its place instead of
  restarting. Otherwise it switches to the animation and loops it from frame 0. Decide which
  animation applies every frame and `use` it, as above.
- **Commands, for something that just happened**, such as a key press or a hit:
  `play(animation)` plays once and holds the last frame, `loop(animation)` loops forever. Both
  always start from frame 0, so calling them every frame keeps the animation stuck on its first
  frame. Without an argument they restart the animation already held. `pause()` freezes it,
  `resume()` continues from there, and `stop()` rewinds to frame 0.

`is_playing()`, `is_finished()` (a `play` that has shown its last frame) and `frame_index()` read
it back. Each entity has an animator of its own, and several can share one animation, as two
enemies share a walk cycle.

**Timing.** Nothing ticks an animator: it works out its frame from the run's clock whenever it is
asked. So it follows `context.time_scale` and `time_paused` (see
[Slowing and pausing time](math.md#slowing-and-pausing-time)), unless it is built with
`Animator(animation, clock=Clock.REAL)`.

See [examples/animation](../examples/animation/main.mojo).

## Building an image pixel by pixel

**An `Image` is immutable**, an asset like `Sound`: `image.pixel(x, y)` reads it, nothing writes
it. To build one pixel by pixel, fill a `PixelBuffer` with `set(x, y, color)` (read back with
`pixel(x, y)`; it starts transparent), then `Image(buffer^)` takes the pixels over without copying:

```mojo
# An 8 by 8 checkerboard:
var buffer = PixelBuffer(8, 8)
for y in range(8):
    for x in range(8):
        if (x + y) % 2 == 0:
            buffer.set(x, y, Color.BLACK)
var board = Image(buffer^)
```

Both use **image coordinates**: top-left origin, y down, whole `Int` cells. This is the one place
a position is two numbers rather than a `Point2D`, since a cell is not a point in the program's
space. Off the image, reads are transparent and writes do nothing. "Pixel" always names such a
cell; a colour at a screen point is `canvas.color_at`.

Shapes, text and gradients go into an image through an offscreen `Canvas` instead (see
[Drawing into an image](pixels.md#drawing-into-an-image)).
