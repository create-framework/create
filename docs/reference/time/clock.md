# Clock

```mojo
struct Clock
```

The run's scaled time or its real time, for a playhead to keep time by.

- `SCALED`, the default: `context.time.elapsed`, which
  `context.time_scale` slows and `context.time_paused` stops. What the
  program's own motion moves by, so animation and motion stay in step.
- `REAL`: `context.time.real_elapsed`, which ignores both. For what must
  keep moving while the program's time stands still, like a pause menu.

Implements `Copyable`, `Deinitable`, `Equatable`, `ImplicitlyCopyable`, `Movable`, `Writable`.

## Constants

- `SCALED = Clock(Int(0))`
- `REAL = Clock(Int(1))`

## Fields

- `value: Int`

## Constructors

```mojo
@staticmethod
def __init__(out self, value: Int)
```

## Special methods

### `__eq__`

```mojo
def __eq__(self, other: Self) -> Bool
```

### `__ne__`

```mojo
def __ne__(self, other: Self) -> Bool
```
