# WidgetHandle

```mojo
struct WidgetHandle[W: Copyable]
```

Where a widget of type `W` is in a `UI`: what `ui.add` returns, and how the program reaches the widget again, as `ui[handle]`.

A handle belongs to the `UI` that made it. Using it on another `UI`, or
once `ui.remove` has removed its widget, stops the program with a
message saying so, even after a new widget has taken the old one's
place.

Implements `Copyable`, `Deinitable`, `Equatable`, `ImplicitlyCopyable`, `Movable`.

## Special methods

### `__eq__`

```mojo
def __eq__(self, other: Self) -> Bool
```
