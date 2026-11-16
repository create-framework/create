# OverlayGuard

```mojo
struct OverlayGuard[origin: MutOrigin]
```

Restores the camera and transform `canvas.overlay` suspended, on scope exit. Only `canvas.overlay` builds one.

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
