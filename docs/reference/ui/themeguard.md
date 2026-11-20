# ThemeGuard

```mojo
struct ThemeGuard[origin: MutOrigin]
```

Ends the `ui.theme` block it was made for, on scope exit. Only `ui.theme` builds one.

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
