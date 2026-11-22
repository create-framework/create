# ColorsGuard

```mojo
struct ColorsGuard[origin: MutOrigin]
```

Ends the `ui.colors` block it was made for, on scope exit. Only `ui.colors` builds one.

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
