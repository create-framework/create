# Animation

Values and sprites that move over time: easing and tweens, and sprite animation. A `Tween` and
an `Animator` are each a playhead that keeps time on its own, off the run's clock, so nothing
ticks them.

## Easing and tweens

An **`Easing`** is a curve that reshapes progress from 0 to 1, so motion can start slowly, end
with a bounce and so on: `ease(Easing.OUT_CUBIC, t)`. A **`Tween`** runs that progress over a
duration in seconds, from a start value to an end value:

```mojo
# In `create`, building the `slide` field:
var slide = Tween(-300, 0, 0.5, Easing.OUT_BACK)  # from -300 to 0 over half a second

# In `update`:
if context.keyboard.pressed(Key.SPACE):
    self.slide.play()
canvas.rectangle((self.slide.value(), 0), 100, 100)
```

Nothing ticks a tween: it remembers when it was started and works its value out from
`context.time` whenever it is asked, so it slows and pauses with the run's time unless built on
real time (see [Slowing and pausing time](time.md#slowing-and-pausing-time)). Each entity owns
its own `Tween`. Frame-by-frame animation, a sprite sheet, is an `Animation` and an `Animator`,
not a tween (see [Sprite animation](#sprite-animation)).

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
[Slowing and pausing time](time.md#slowing-and-pausing-time)), unless it is built with
`Animator(animation, clock=Clock.REAL)`.

See [examples/animation](../examples/animation/main.mojo).
