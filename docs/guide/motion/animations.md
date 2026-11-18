# Animations

A sprite comes alive by showing a sequence of pictures one after another, quickly enough that the
eye sees movement, as in a flip book: a character's legs moving as it walks, a coin turning, a flag
waving. This page explains how to make an animation from a sprite sheet or a folder of images and
how to play it. Moving a value smoothly from one number to another, such as sliding a menu in, is a
different job, done by a [Tween](tweens.md).

## Animations and animators

Two types share the work. An **`Animation`** is the artwork: a sequence of frames, and the rate they
play at. An **`Animator`** is one character's place in an animation: which animation it is showing,
and how far through it is. Two enemies can share one walk animation and still each be at their own
point in the walk, because each has an animator of its own. `canvas.image` draws an animator's
current frame:

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

## Making an animation

There are three ways to make an animation. Each takes an `fps=`, the frames per second it plays at,
which is 12 by default. The rate belongs to the artwork, so it is set on the animation rather than
the animator.

- A **sprite sheet** is one image holding all the frames side by side in a grid, as many artists
  deliver them. `Animation.from_sheet(sheet, frame_width, frame_height, start=, count=)` cuts the
  frames out of one. Its cells are numbered from 0, left to right and then top to bottom, so one
  sheet can hold several animations, as above.
- A **folder** of images, one per frame: `Animation.from_folder(path)` loads every image in the
  folder, in the order of the number each file's name ends in, so `walk_2.png` comes before
  `walk_10.png`.
- A **list** of images already loaded: `Animation(frames)` takes a `List[Image]`.

## Playing an animation

An animator starts stopped, on frame 0. There are two ways to drive it, for two kinds of situation:

- **`use(animation)`, every frame, for what should be showing now.** If that animation is already
  the one playing, paused or finished, `use` changes nothing, so a loop keeps its place instead of
  restarting. Otherwise it switches to the animation and loops it from frame 0. Decide which
  animation applies every frame and `use` it, as above.
- **Commands, for something that just happened**, such as a key press or a hit: `play(animation)`
  plays once and holds the last frame; `loop(animation)` loops forever. Both always start from frame
  0, so calling them every frame keeps the animation stuck on its first frame. Without an argument
  they restart the animation already held. `pause()` freezes it, `resume()` continues from there,
  and `stop()` rewinds to frame 0.

`is_playing()`, `is_finished()` (whether a `play` has shown its last frame) and `frame_index()` read
an animator back: use them, for example, to start the next move once an attack animation has
finished.

## Animations and time

Nothing needs to update an animator each frame: it works out its frame from the run's clock whenever
it is asked. So it slows down and stops with the rest of the game under `context.time_scale` and
`time_paused` (see [Slowing and pausing time](time.md#slowing-and-pausing-time)), unless it is built
on real time with `Animator(animation, clock=Clock.REAL)`, as a pause menu's own animations must be.

See [examples/animations](../../../examples/animations/main.mojo).
