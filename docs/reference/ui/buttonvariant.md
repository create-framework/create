# ButtonVariant

```mojo
struct ButtonVariant
```

Which of the theme's colours a button is drawn in.

From the most prominent to the quietest:

- `FILLED`: filled with `primary`, for the main action on screen.
- `TONAL`: filled with `secondary_container`, for a secondary action.
- `OUTLINED`: an `outline` border and `primary` text, for an action that
  should be visible but not stand out.
- `TEXT`: `primary` text alone, for the least important actions.

Implements `Copyable`, `Deinitable`, `Equatable`, `ImplicitlyCopyable`, `Movable`, `Writable`.

## Constants

- `FILLED = ButtonVariant(Int(0))`
- `TONAL = ButtonVariant(Int(1))`
- `OUTLINED = ButtonVariant(Int(2))`
- `TEXT = ButtonVariant(Int(3))`

## Fields

- `value: Int`

## Special methods

### `__eq__`

```mojo
def __eq__(self, other: Self) -> Bool
```
