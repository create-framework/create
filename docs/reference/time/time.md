# Time

```mojo
struct Time
```

Per-frame timing, ticked once per frame by the run loop.

Two clocks run side by side. **Scaled time**, `delta` and `elapsed`, is
the program's: the time scale slows or speeds it and pausing the run's
time stops it (`context.time_scale`, `context.time_paused`), and every
`Animator` and `Tween` keeps time by it. Move things by `delta` and they
slow and pause along with the animations. **Real time**, `real_delta`
and `real_elapsed`, is the wall clock's and ignores both, for what must
keep going while the program's time is paused, like a pause menu.

Owns the previous tick stamp so the frame delta is derived in one place.
`_start` must seed that stamp before the first `_tick`: the window clock
counts from process start, not from zero, so an unseeded first frame would
report the whole uptime as its delta and spike anything integrating it.

Implements `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `Writable`.

## Fields

- `delta: Float64`: Seconds of scaled time since the previous frame -- multiply motion by this. Zero while the run's time is paused.
- `elapsed: Float64`: Seconds of scaled time accumulated since the first frame.
- `real_delta: Float64`: Seconds of real time since the previous frame, whatever the time scale.
- `real_elapsed: Float64`: Seconds of real time accumulated since the first frame.

## Constructors

```mojo
@staticmethod
def __init__(out self)
```
