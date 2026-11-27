# Space

```mojo
struct Space
```

Room left empty in a column, or a row, such as to set one group of widgets apart from the next: twice the `UI`'s `spacing` unless given an `amount`.

Implements `Copyable`, `Deinitable`, `Movable`.

## Fields

- `amount: OptionalNumber`

## Constructors

```mojo
@staticmethod
def __init__(out self, amount: OptionalNumber = None)
```
