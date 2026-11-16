# FontWeight

```mojo
struct FontWeight
```

A stroke weight, for `canvas.font_weight`.

Design-space values on the packaged variable faces, so they interpolate
rather than selecting a file — any number in 100..900 is valid, the
constants are CSS's names for each hundred. `FontWeight(450)` names one in
between.

A wrapped number rather than a bare `Int`, like `WindowMode`, so a stray
number — a font size, say — cannot be passed where a weight is expected.

Implements `Copyable`, `Deinitable`, `Equatable`, `ImplicitlyCopyable`, `Movable`, `Writable`.

## Constants

- `THIN = FontWeight(Int(100))`
- `EXTRA_LIGHT = FontWeight(Int(200))`
- `LIGHT = FontWeight(Int(300))`
- `REGULAR = FontWeight(Int(400))`
- `MEDIUM = FontWeight(Int(500))`
- `SEMI_BOLD = FontWeight(Int(600))`
- `BOLD = FontWeight(Int(700))`
- `EXTRA_BOLD = FontWeight(Int(800))`
- `BLACK = FontWeight(Int(900))`

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
