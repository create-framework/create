# Space

```mojo
struct Space
```

Room left empty in a column, or a row, such as to set one group of widgets apart from the next: twice the `UI`'s `spacing` unless given an `amount`.

Implements `Copyable`, `Deinitable`, `Movable`.

## Fields

- `amount: Optional[Float64]`

## Constructors

```mojo
@staticmethod
def __init__(out self, amount: _OptionalFloat64 = None)
```
