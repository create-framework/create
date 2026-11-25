# WidgetHandle

```mojo
struct WidgetHandle[W: Copyable]
```

Where a widget of type `W` is in a `UI`: what `ui.add` returns, and how the program reaches the widget again, as `ui[handle]`.

Once `ui.remove` has removed the widget, its handle names nothing: using
it stops the program with a message saying so, even after a new widget
has taken the old one's place.

Implements `Copyable`, `Deinitable`, `Equatable`, `ImplicitlyCopyable`, `Movable`.

## Special methods

### `__eq__`

```mojo
def __eq__(self, other: Self) -> Bool
```
