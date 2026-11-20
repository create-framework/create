# PanelGuard

```mojo
struct PanelGuard[origin: MutOrigin]
```

Ends the `ui.panel` block it was made for, on scope exit. Only `ui.panel` builds one.

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
