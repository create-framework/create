# GradientStop

```mojo
struct GradientStop
```

A colour placed at a position along a `Gradient`, from 0 at its start to 1 at its end.

A program writes one as a `(position, colour)` pair, and never names the
type: `Gradient.linear([(0, Color.BLUE), (0.7, Color.PURPLE), (1,
Color.ORANGE)])`. The position can be any number, so `0` and `1` need no
`.0`.

Implements `Copyable`, `Deinitable`, `Equatable`, `ImplicitlyCopyable`, `Movable`, `Writable`.

## Fields

- `position: Float64`
- `color: Color`

## Constructors

```mojo
@staticmethod
def __init__(out self, position: Number, color: Color)
@staticmethod
def __init__(out self, stop: Tuple[Float64, Color])
@staticmethod
def __init__(out self, stop: Tuple[Int, Color])
```

## Special methods

### `__eq__`

```mojo
def __eq__(self, other: Self) -> Bool
```
