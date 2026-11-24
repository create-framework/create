# RenderBackend

```mojo
struct RenderBackend
```

Which renderer draws a run's frames: `run`'s and `run_headless`'s `backend`.

Fixed for the run. Both draw the same frame, apart from tiny differences
along antialiased edges. Compare backends with `==`.

Implements `Copyable`, `Deinitable`, `Equatable`, `ImplicitlyCopyable`, `Movable`, `Writable`.

## Constants

- `CPU = RenderBackend(Int(0))`: Create's own rasteriser, on the CPU. The default.
- `GPU = RenderBackend(Int(1))`: OpenGL 3.3.

## Fields

- `value: Int`

## Constructors

```mojo
@staticmethod
def __init__(out self, value: Int)
```

### `from_arguments`

```mojo
@staticmethod
def from_arguments() -> Self
```

The backend named on the command line, `gpu` or `cpu`, or asked for in the terminal when neither is named.

So one build runs on either, `./sketch gpu` or `pixi run example
shadows gpu`, passed as `run(..., backend=RenderBackend.from_arguments())`.
When both are named, the last one wins; other arguments are left for
the program. With neither, it asks in the terminal, and asks again
until the answer is `gpu` or `cpu`. A program not started from a
terminal can't be asked, so it prints what to add to the command and
exits. Calls after the first return the backend chosen first, without
asking again.

## Special methods

### `__eq__`

```mojo
def __eq__(self, other: Self) -> Bool
```

### `__ne__`

```mojo
def __ne__(self, other: Self) -> Bool
```
