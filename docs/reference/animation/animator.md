# Animator

```mojo
struct Animator
```

The playhead over one `Animation`.

An animation is the artwork and never moves; an animator is the frame a
particular entity is on right now, so an entity owns one and several can
share the same animation.

Nothing ticks it: an animator remembers when it was started and works out
its frame from the run's clock whenever it is asked, so it keeps time
with no call each frame. The clock is the run's scaled time,
`context.time.elapsed`, so slowing or pausing the run's time slows or
stops every animator with it; an animator built with `clock=Clock.REAL`
runs on real time instead, as a pause menu's own animation must.

Constructed stopped on frame 0 -- nothing advances until `play`, `loop`
or `use`. Two kinds of call drive it:

- **Commands**, for something that just happened (a key, a hit): `play`
  runs the animation once and holds the last frame, `loop` wraps forever,
  and both always start from frame 0, with or without a new animation, as
  `Tween.play` and `Audio.play` always start. `pause` freezes where it is
  and `resume` continues from there; `stop` rewinds.
- **`use`**, for what should be showing now, called every frame from the
  branch that decides it. Naming the animation already held changes
  nothing, so it never rewinds a running loop or undoes a `pause`.

```mojo
if context.keyboard.pressed(Key.SPACE):
    self.animator.play(self.spin)    # a command: starts every time
elif not self.spinning:
    self.animator.use(self.run if moving else self.idle)   # a state
```

A copy keeps the original's timing: both show the same frame until a
command is given to one of them.

Implements `Copyable`, `Deinitable`, `Movable`, `Writable`.

## Constructors

```mojo
@staticmethod
def __init__(out self, var animation: Animation, clock: Clock = Clock.SCALED)
```

Hold `animation`, stopped on frame 0, to play it timed by `clock`.

An animator always has an animation, so there is no empty state to
guard against when rendering.

## Methods

### `animation`

```mojo
def animation(self) -> Animation
```

The animation being played, sharing its frames. Switch with `use`, `play` or `loop`.

### `frame_index`

```mojo
def frame_index(self) -> Int
```

The frame showing, counted from 0.

### `use`

```mojo
def use(mut self, var animation: Animation)
```

Show `animation`, looping: the call to make every frame from the branch that decides which animation applies.

```mojo
if self.velocity.x != 0.0:
    self.animator.use(self.run)
else:
    self.animator.use(self.idle)
```

Naming the animation already held, once it has been started, does
nothing at all: a loop keeps its place, a `pause` holds and a
finished `play` stays on its last frame. Otherwise -- another
animation, or this one stopped -- it starts `animation` looping from
frame 0. A one-shot is a command, not a state: `play` it when the
thing that triggers it happens.

### `play`

```mojo
def play(mut self)
```

Play once from frame 0, holding the last frame at the end.

```mojo
def play(mut self, var animation: Animation)
```

Switch to `animation` and play it once from frame 0 -- restarting it if it is the one already held.

### `loop`

```mojo
def loop(mut self)
```

Play from frame 0, wrapping to the start forever.

```mojo
def loop(mut self, var animation: Animation)
```

Switch to `animation` and loop it from frame 0 -- restarting it if it is the one already held. To keep a running loop's place, `use` it.

### `pause`

```mojo
def pause(mut self)
```

Freeze on the current frame. `resume` continues from here.

### `resume`

```mojo
def resume(mut self)
```

Continue a paused animation without rewinding. A stopped one starts from frame 0; a finished `play` stays finished.

### `stop`

```mojo
def stop(mut self)
```

Halt and rewind to frame 0.

### `is_playing`

```mojo
def is_playing(self) -> Bool
```

True while the playhead is advancing -- false when stopped, paused or finished.

### `is_finished`

```mojo
def is_finished(self) -> Bool
```

True once a `play` has shown its last frame for a frame's length. Never true for `loop`.
