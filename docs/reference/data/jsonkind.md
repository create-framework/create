# JSONKind

```mojo
struct JSONKind
```

Which of JSON's six kinds of value a `JSON` holds.

Implements `Copyable`, `Deinitable`, `Equatable`, `ImplicitlyCopyable`, `Movable`, `Writable`.

## Constants

- `NULL = JSONKind(Int(0))`
- `BOOL = JSONKind(Int(1))`
- `NUMBER = JSONKind(Int(2))`
- `STRING = JSONKind(Int(3))`
- `ARRAY = JSONKind(Int(4))`
- `OBJECT = JSONKind(Int(5))`

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
