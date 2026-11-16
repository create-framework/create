# Playback

```mojo
struct Playback
```

One playback of a `Sound`, as `audio.play` and `audio.loop` return it: the handle `stop`, `pause`, `resume`, `volume`, `speed`, `is_playing` and `is_paused` take.

A `Sound` can have several playbacks at once. One that has ended or
been stopped is stale: every call on it does nothing, even after its slot
plays another sound. `Playback.NONE` is no playback, for a field before
anything plays. A handle, like `Sound`, so not printable.

Implements `Copyable`, `Deinitable`, `Equatable`, `ImplicitlyCopyable`, `Movable`.

## Constants

- `NONE = Playback(_id=Int(0))`

## Special methods

### `__eq__`

```mojo
def __eq__(self, other: Self) -> Bool
```

### `__ne__`

```mojo
def __ne__(self, other: Self) -> Bool
```
