# Easing

```mojo
struct Easing
```

Which curve `ease` applies. A `Tween` stores one as a field.

A wrapped `Int` rather than a bare one so a stray number cannot be passed
where a curve is expected.

Implements `Copyable`, `Deinitable`, `Equatable`, `ImplicitlyCopyable`, `Movable`, `Writable`.

## Constants

- `LINEAR = Easing(Int(0))`: No easing: the fraction passes through unchanged.
- `IN_QUAD = Easing(Int(1))`
- `OUT_QUAD = Easing(Int(2))`
- `IN_OUT_QUAD = Easing(Int(3))`
- `IN_CUBIC = Easing(Int(4))`
- `OUT_CUBIC = Easing(Int(5))`
- `IN_OUT_CUBIC = Easing(Int(6))`
- `IN_SINE = Easing(Int(7))`
- `OUT_SINE = Easing(Int(8))`
- `IN_OUT_SINE = Easing(Int(9))`
- `IN_EXPO = Easing(Int(10))`
- `OUT_EXPO = Easing(Int(11))`
- `IN_OUT_EXPO = Easing(Int(12))`
- `IN_BACK = Easing(Int(13))`
- `OUT_BACK = Easing(Int(14))`
- `IN_OUT_BACK = Easing(Int(15))`
- `IN_ELASTIC = Easing(Int(16))`
- `OUT_ELASTIC = Easing(Int(17))`
- `IN_OUT_ELASTIC = Easing(Int(18))`
- `IN_BOUNCE = Easing(Int(19))`
- `OUT_BOUNCE = Easing(Int(20))`
- `IN_OUT_BOUNCE = Easing(Int(21))`

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
