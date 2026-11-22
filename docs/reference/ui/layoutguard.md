# LayoutGuard

```mojo
struct LayoutGuard[origin: MutOrigin]
```

Ends the `ui.column` or `ui.row` block it was made for, on scope exit. Only `ui.column` and `ui.row` build one.

Implements `Deinitable`, `Movable`.

## Special methods

### `__enter__`

```mojo
def __enter__(mut self)
```

### `__exit__`

```mojo
def __exit__(mut self)
```
