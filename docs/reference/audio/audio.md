# Audio

```mojo
struct Audio
```

Program-owned playback device. Construct once, hold as a Program field, call `play` from `update`. Where no audio device can be opened, it plays silently rather than raising.

It needs nothing each frame: a looping playback is fed on SDL's audio
thread, as the device asks, and a one-shot playback reads as stale once it
has played to its end, its slot freed by the next `play`.

Implements `Deinitable`, `Movable`.

## Constructors

```mojo
@staticmethod
def __init__(out self) raises
```

## Methods

### `volume`

```mojo
def volume(self) -> Float64
```

The volume every playback plays at, `1.0` unless set.

```mojo
def volume(mut self, volume: Float64) raises
```

Set the volume every playback plays at, `0.0` silent and `1.0` as recorded; above `1.0` amplifies, and below `0.0` is silent too. Applies at once, to the playbacks already playing as well as later ones; each playback's own `volume(playback, ...)` scales it.

```mojo
def volume(self, playback: Playback) -> Float64
```

`playback`'s own volume, `1.0` unless set; `0.0` once it is stale.

```mojo
def volume(mut self, playback: Playback, volume: Float64) raises
```

Set `playback`'s own volume, which `volume()` scales: a playback at `0.5` under a volume of `0.5` plays at a quarter. Below `0.0` is silent, as for `volume()`. No-op if stale.

### `play`

```mojo
def play(
    mut self,
    sound: Sound,
    volume: Float64 = 1,
    speed: Float64 = 1,
) raises -> Playback
```

Play `sound` once, as a new `Playback` at its own `volume` and `speed`; it is stale once the sound ends.

### `loop`

```mojo
def loop(
    mut self,
    sound: Sound,
    volume: Float64 = 1,
    speed: Float64 = 1,
) raises -> Playback
```

Play `sound` over and over until stopped, as a new `Playback` at its own `volume` and `speed`, as `Animator.loop` and `Tween.loop` repeat. The playback is fed as the device asks, from a copy of `sound` that shares its samples.

### `stop`

```mojo
def stop(mut self, playback: Playback) raises
```

Stop and release `playback`. No-op if it is already stale.

### `stop_all`

```mojo
def stop_all(mut self) raises
```

Stop and release every playback, playing or paused.

### `pause_all`

```mojo
def pause_all(mut self) raises
```

Pause every playing playback, as for a pause screen. Playbacks played afterwards play as usual, so the screen can have sounds of its own.

### `resume_all`

```mojo
def resume_all(mut self) raises
```

Resume every paused playback, whether `pause_all` or `pause` held it.

### `pause`

```mojo
def pause(mut self, playback: Playback) raises
```

Hold `playback` where it is; `resume` continues it.

### `speed`

```mojo
def speed(self, playback: Playback) -> Float64
```

`playback`'s speed, `1.0` unless set; `0.0` once it is stale.

```mojo
def speed(mut self, playback: Playback, speed: Float64) raises
```

Set `playback`'s speed: `2.0` plays it twice as fast and an octave higher, `0.5` half as fast and an octave lower, as a record sped up or slowed down. Clamped to `0.01` to `100.0`. No-op if stale.

### `resume`

```mojo
def resume(mut self, playback: Playback) raises
```

Continue a paused `playback` from where it was held.

### `is_playing`

```mojo
def is_playing(self, playback: Playback) -> Bool
```

Whether `playback` is sounding: false once paused or stale.

### `is_paused`

```mojo
def is_paused(self, playback: Playback) -> Bool
```

Whether `playback` is held by `pause`, waiting for `resume`. A playback neither playing nor paused is stale: it has ended or been stopped.
